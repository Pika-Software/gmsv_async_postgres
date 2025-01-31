#include "async_postgres.hpp"

using namespace async_postgres;

void async_postgres::process_notifications(GLua::ILuaInterface* lua,
                                           Connection* state) {
    if (!state->on_notify) {
        return;
    }

    if (!state->query && check_socket_status(state->conn.get()).read_ready &&
        PQconsumeInput(state->conn.get()) == 0) {
        // we consumed input
        // but there was some error
        return;
    }

    while (auto notify = pg::getNotify(state->conn)) {
        if (state->on_notify.Push()) {
            lua->PushString(notify->relname);  // arg 1 channel name
            lua->PushString(notify->extra);    // arg 2 payload
            lua->PushNumber(notify->be_pid);   // arg 3 backend pid

            pcall(lua, 3, 0);
        }
    }
}
