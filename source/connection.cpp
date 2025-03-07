#include "async_postgres.hpp"

using namespace async_postgres;

std::vector<Connection*> async_postgres::connections = {};

Connection::Connection(GLua::ILuaInterface* lua, pg::conn&& conn)
    : conn(std::move(conn)), lua(lua) {
    // add connection to global list
    connections.push_back(this);
}

Connection::~Connection() {
    // remove connection from global list
    // so event loop doesn't try to process it
    connections.erase(std::find(connections.begin(), connections.end(), this));
}

struct ConnectionEvent {
    pg::conn conn;
    GLua::AutoReference callback;
    PostgresPollingStatusType status = PGRES_POLLING_WRITING;
    bool is_reset = false;
};

std::vector<ConnectionEvent> pending_connections = {};

inline bool socket_is_ready(PGconn* conn, PostgresPollingStatusType status) {
    if (status == PGRES_POLLING_READING || status == PGRES_POLLING_WRITING) {
        auto socket = check_socket_status(conn);
        return socket.failed ||
               ((status == PGRES_POLLING_READING && socket.read_ready) ||
                (status == PGRES_POLLING_WRITING && socket.write_ready));
    }
    return true;
}

static void noticeReceiver(void* arg, const PGresult* res) {
    auto state = static_cast<Connection*>(arg);
    if (state->on_notice.IsValid()) {
        auto lua = state->lua;
        state->on_notice.Push();
        lua->PushString(PQresultErrorMessage(res));
        create_result_error_table(lua, res);
        pcall(lua, 2, 0);
    }
}

void async_postgres::connect(GLua::ILuaInterface* lua, std::string_view url,
                             GLua::AutoReference&& callback) {
    auto conn = pg::connectStart(url);

    if (!conn) {
        // funnily enough, this probably will instead throw a std::bad_alloc
        throw std::runtime_error("failed to allocate connection");
    }

    if (PQstatus(conn.get()) == CONNECTION_BAD ||
        PQsetnonblocking(conn.get(), 1) != 0) {
        throw std::runtime_error(PQerrorMessage(conn.get()));
    }

    auto event = ConnectionEvent{std::move(conn), std::move(callback)};
    pending_connections.push_back(std::move(event));
}

// returns true if we finished polling
// returns false if we need to poll again
inline bool poll_pending_connection(GLua::ILuaInterface* lua,
                                    ConnectionEvent& event) {
    if (!socket_is_ready(event.conn.get(), event.status)) {
        return false;
    }

    event.status = PQconnectPoll(event.conn.get());
    if (event.status == PGRES_POLLING_OK) {
        auto state = new Connection(lua, std::move(event.conn));

        PQsetNoticeReceiver(state->conn.get(), noticeReceiver, state);

        event.callback.Push();
        lua->PushBool(true);
        lua->PushUserType(state, connection_meta);
        lua->PushMetaTable(connection_meta);
        lua->SetMetaTable(-2);
        pcall(lua, 2, 0);

        return true;
    } else if (event.status == PGRES_POLLING_FAILED) {
        event.callback.Push();
        lua->PushBool(false);
        lua->PushString(PQerrorMessage(event.conn.get()));
        pcall(lua, 2, 0);

        return true;
    }

    return false;
}

void async_postgres::process_pending_connections(GLua::ILuaInterface* lua) {
    for (auto it = pending_connections.begin();
         it != pending_connections.end();) {
        auto& event = *it;

        if (poll_pending_connection(lua, event)) {
            it = pending_connections.erase(it);
        } else {
            ++it;
        }
    }
}

void async_postgres::reset(GLua::ILuaInterface* lua, Connection* state,
                           GLua::AutoReference&& callback) {
    if (!state->reset_event) {
        if (PQresetStart(state->conn.get()) == 0) {
            throw std::runtime_error(PQerrorMessage(state->conn.get()));
        }

        state->reset_event = std::make_shared<ResetEvent>();
    }

    if (callback) {
        state->reset_event->callbacks.push_back(std::move(callback));
    }
}

void async_postgres::process_reset(GLua::ILuaInterface* lua,
                                   Connection* state) {
    if (!state->reset_event) {
        return;
    }

    auto event = state->reset_event;
    if (!socket_is_ready(state->conn.get(), state->reset_event->status)) {
        return;
    }

    event->status = PQresetPoll(state->conn.get());
    if (event->status == PGRES_POLLING_OK) {
        state->reset_event.reset();

        for (auto& callback : event->callbacks) {
            callback.Push();
            lua->PushBool(true);
            pcall(lua, 1, 0);
        }
    } else if (event->status == PGRES_POLLING_FAILED) {
        state->reset_event.reset();

        for (auto& callback : event->callbacks) {
            callback.Push();
            lua->PushBool(false);
            lua->PushString(PQerrorMessage(state->conn.get()));
            pcall(lua, 2, 0);
        }
    }
}
