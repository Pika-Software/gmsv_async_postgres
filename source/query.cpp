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

bool bad_result(PGresult* result) {
    if (!result) {
        return true;
    }

    auto status = PQresultStatus(result);

    return status == PGRES_BAD_RESPONSE || status == PGRES_NONFATAL_ERROR ||
           status == PGRES_FATAL_ERROR;
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

    while (PQisBusy(state->conn.get()) == 0) {
        auto result = pg::getResult(state->conn);
        if (!result) {
            // query is done
            // TODO: remove query if we have a final result
            state->query.reset();
            return process_query(lua, state);
        }

        if (query.callback) {
            query.callback.Push();
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
}
