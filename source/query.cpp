#include "async_postgres.hpp"

using namespace async_postgres;

#define get_if_command(type) \
    const auto* command = std::get_if<type>(&query.command)

// returns true if query was sent
// returns false on error
inline bool send_query(PGconn* conn, Query& query) {
    if (get_if_command(SimpleCommand)) {
        return PQsendQuery(conn, command->command.c_str()) == 1;
    } else if (get_if_command(ParameterizedCommand)) {
        return PQsendQueryParams(conn, command->command.c_str(),
                                 command->param.length(), nullptr,
                                 command->param.values.data(),
                                 command->param.lengths.data(),
                                 command->param.formats.data(), 0) == 1;
    } else if (get_if_command(CreatePreparedCommand)) {
        return PQsendPrepare(conn, command->name.c_str(),
                             command->command.c_str(), 0, nullptr) == 1;
    } else if (get_if_command(PreparedCommand)) {
        return PQsendQueryPrepared(
                   conn, command->name.c_str(), command->param.length(),
                   command->param.values.data(), command->param.lengths.data(),
                   command->param.formats.data(), 0) == 1;
    } else if (get_if_command(DescribePreparedCommand)) {
        return PQsendDescribePrepared(conn, command->name.c_str()) == 1;
    } else if (get_if_command(DescribePortalCommand)) {
        return PQsendDescribePortal(conn, command->name.c_str()) == 1;
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

#define set_error_field(name, field)                                 \
    {                                                                \
        const char* field_value = PQresultErrorField(result, field); \
        if (field_value) {                                           \
            lua->PushString(field_value);                            \
            lua->SetField(-2, name);                                 \
        }                                                            \
    }

inline void create_result_error_table(GLua::ILuaInterface* lua,
                                      PGresult* result) {
    lua->CreateTable();

    lua->PushString(PQresStatus(PQresultStatus(result)));
    lua->SetField(-2, "status");

    set_error_field("severity", PG_DIAG_SEVERITY_NONLOCALIZED);
    set_error_field("sqlState", PG_DIAG_SQLSTATE);
    set_error_field("messagePrimary", PG_DIAG_MESSAGE_PRIMARY);
    set_error_field("messageDetail", PG_DIAG_MESSAGE_DETAIL);
    set_error_field("messageHint", PG_DIAG_MESSAGE_HINT);
    set_error_field("statementPosition", PG_DIAG_STATEMENT_POSITION);
    set_error_field("context", PG_DIAG_CONTEXT);
    set_error_field("schemaName", PG_DIAG_SCHEMA_NAME);
    set_error_field("tableName", PG_DIAG_TABLE_NAME);
    set_error_field("columnName", PG_DIAG_COLUMN_NAME);
    set_error_field("dataType", PG_DIAG_DATATYPE_NAME);
    set_error_field("constraintName", PG_DIAG_CONSTRAINT_NAME);
    set_error_field("sourceFile", PG_DIAG_SOURCE_FILE);
    set_error_field("sourceLine", PG_DIAG_SOURCE_LINE);
    set_error_field("sourceFunction", PG_DIAG_SOURCE_FUNCTION);
}

void query_result(GLua::ILuaInterface* lua, pg::result&& result,
                  GLua::AutoReference& callback) {
    if (callback.Push()) {
        if (!bad_result(result.get())) {
            lua->PushBool(true);
            create_result_table(lua, result.get());
            pcall(lua, 2, 0);
        } else {
            lua->PushBool(false);
            lua->PushString(PQresultErrorMessage(result.get()));
            create_result_error_table(lua, result.get());
            pcall(lua, 3, 0);
        }
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

void async_postgres::process_result(GLua::ILuaInterface* lua, Connection* state,
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
    if (!state->query) {
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

    // if (!poll_query(state->conn.get(), query)) {
    //     query_failed(lua, state);
    //     return process_query(lua, state);
    // }

    // probably failed poll should not result
    // in query failure
    poll_query(state->conn.get(), query);

    // ensure that getting result won't block
    if (!pg::isBusy(state->conn)) {
        return process_result(lua, state, pg::getResult(state->conn));
    }
}
