#include "async_postgres.hpp"

using namespace async_postgres;

// returns true if query was sent
// returns false on error
inline bool send_query(PGconn* conn, Query& query) {
    if (const auto* command = std::get_if<SimpleCommand>(&query.command)) {
        return PQsendQuery(conn, command->command.c_str()) == 1;
    } else if (const auto* command =
                   std::get_if<ParameterizedCommand>(&query.command)) {
        return PQsendQueryParams(conn, command->command.c_str(),
                                 command->param.length(), nullptr,
                                 command->param.values.data(),
                                 command->param.lengths.data(),
                                 command->param.formats.data(), 0) == 1;
    }
    return false;
}

// This function will remove the query from the connection state
// and call the callback with the error message
void query_failed(GLua::ILuaInterface* lua, Connection* state) {
    if (!state->query) {
        return;
    }

    auto query = std::move(*state->query);
    lua->Msg("[async_postgres] query failed: current query %d\n",
             state->query.has_value());

    state->query.reset();

    if (query.callback) {
        query.callback.Push();
        lua->PushBool(false);
        lua->PushString(PQerrorMessage(state->conn.get()));
        pcall(lua, 2, 0);
    }
}

inline bool bad_result(PGresult* result) {
    if (!result) {
        return true;
    }

    auto status = PQresultStatus(result);

    return status == PGRES_BAD_RESPONSE || status == PGRES_NONFATAL_ERROR ||
           status == PGRES_FATAL_ERROR;
}

void query_result(GLua::ILuaInterface* lua, pg::result&& result,
                  GLua::AutoReference& callback) {
    if (callback.Push()) {
        if (!bad_result(result.get())) {
            lua->PushBool(true);
            create_result_table(lua, result.get());
        } else {
            lua->PushBool(false);
            lua->PushString(PQresultErrorMessage(result.get()));
        }

        pcall(lua, 2, 0);
    }
}

// returns true if poll was successful
// returns false if there was an error
inline bool poll_query(PGconn* conn, Query& query) {
    auto socket = check_socket_status(conn);
    if (socket.read_ready || socket.write_ready) {
        if (socket.read_ready && PQconsumeInput(conn) == 0) {
            return false;
        }

        if (!query.flushed) {
            query.flushed = PQflush(conn) == 0;
        }
    }
    return true;
}

void process_result(GLua::ILuaInterface* lua, Connection* state,
                    pg::result&& result) {
    // query is done
    if (!result) {
        state->query.reset();
        return process_query(lua, state);
    }

    // next result might be empty,
    // that means that query is done
    // and we need to remove query from the state
    // so callback can add another query
    if (!pg::isBusy(state->conn)) {
        auto next_result = pg::getResult(state->conn);
        if (!next_result) {
            // query is done, we need to remove query from the state
            Query query = std::move(*state->query);
            state->query.reset();

            query_result(lua, std::move(result), query.callback);

            // callback might added another query, process it rightaway
            process_query(lua, state);
        } else {
            // query is not done, but also since we own next result
            // we need to call query callback and process next result
            query_result(lua, std::move(result), state->query->callback);
            process_result(lua, state, std::move(next_result));
        }
    } else {
        // query is not done, but we don't need to process next result
        query_result(lua, std::move(result), state->query->callback);
    }
}

void async_postgres::process_query(GLua::ILuaInterface* lua,
                                   Connection* state) {
    if (!state->query || state->reset_event) {
        // no queries to process
        // don't process queries while reconnecting
        return;
    }

    auto& query = state->query.value();
    if (!query.sent) {
        if (!send_query(state->conn.get(), query)) {
            query_failed(lua, state);
            return process_query(lua, state);
        }

        query.sent = true;
        query.flushed = PQflush(state->conn.get()) == 0;
    }

    if (!poll_query(state->conn.get(), query)) {
        query_failed(lua, state);
        return process_query(lua, state);
    }

    // ensure that getting result won't block
    if (!pg::isBusy(state->conn)) {
        return process_result(lua, state, pg::getResult(state->conn));
    }
}
