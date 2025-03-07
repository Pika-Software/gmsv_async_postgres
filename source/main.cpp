#include "async_postgres.hpp"

int async_postgres::connection_meta = 0;

#define lua_connection_state()                    \
    lua->GetUserType<async_postgres::Connection>( \
        1, async_postgres::connection_meta)

namespace async_postgres::lua {
    lua_protected_fn(__gc) {
        delete lua_connection_state();
        return 0;
    }

    lua_protected_fn(loop) {
        async_postgres::process_pending_connections(lua);

        for (auto* state : async_postgres::connections) {
            if (!state->conn) {
                lua->Msg("[async_postgres] connection is null for %p\n", state);
                continue;
            }

            async_postgres::process_notifications(lua, state);
            async_postgres::process_query(lua, state);
            async_postgres::process_reset(lua, state);
        }

        return 0;
    }

    lua_protected_fn(connect) {
        lua->CheckType(1, GLua::Type::String);
        lua->CheckType(2, GLua::Type::Function);

        auto url = lua->GetString(1);
        GLua::AutoReference callback(lua, 2);

        async_postgres::connect(lua, url, std::move(callback));

        return 0;
    }

    lua_protected_fn(query) {
        lua->CheckType(1, async_postgres::connection_meta);
        lua->CheckType(2, GLua::Type::String);

        auto state = lua_connection_state();
        if (state->query) {
            throw std::runtime_error("query already in progress");
        }

        state->query = std::make_shared<async_postgres::Query>(
            async_postgres::SimpleCommand{
                lua->GetString(2),
            });

        if (lua->IsType(3, GLua::Type::Function)) {
            state->query->callback = GLua::AutoReference(lua, 3);
        }

        return 0;
    }

    lua_protected_fn(queryParams) {
        lua->CheckType(1, async_postgres::connection_meta);
        lua->CheckType(2, GLua::Type::String);
        lua->CheckType(3, GLua::Type::Table);

        auto state = lua_connection_state();
        if (state->query) {
            throw std::runtime_error("query already in progress");
        }

        state->query = std::make_shared<async_postgres::Query>(
            async_postgres::ParameterizedCommand{
                lua->GetString(2),
                async_postgres::array_to_params(lua, 3),
            });

        if (lua->IsType(4, GLua::Type::Function)) {
            state->query->callback = GLua::AutoReference(lua, 4);
        }

        return 0;
    }

    lua_protected_fn(prepare) {
        lua->CheckType(1, async_postgres::connection_meta);
        lua->CheckType(2, GLua::Type::String);
        lua->CheckType(3, GLua::Type::String);

        auto state = lua_connection_state();
        if (state->query) {
            throw std::runtime_error("query already in progress");
        }

        state->query = std::make_shared<async_postgres::Query>(
            async_postgres::CreatePreparedCommand{
                lua->GetString(2),
                lua->GetString(3),
            });

        if (lua->IsType(4, GLua::Type::Function)) {
            state->query->callback = GLua::AutoReference(lua, 4);
        }

        return 0;
    }

    lua_protected_fn(queryPrepared) {
        lua->CheckType(1, async_postgres::connection_meta);
        lua->CheckType(2, GLua::Type::String);
        lua->CheckType(3, GLua::Type::Table);

        auto state = lua_connection_state();
        if (state->query) {
            throw std::runtime_error("query already in progress");
        }

        state->query = std::make_shared<async_postgres::Query>(
            async_postgres::PreparedCommand{
                lua->GetString(2),
                async_postgres::array_to_params(lua, 3),
            });

        if (lua->IsType(4, GLua::Type::Function)) {
            state->query->callback = GLua::AutoReference(lua, 4);
        }

        return 0;
    }

    lua_protected_fn(describePrepared) {
        lua->CheckType(1, async_postgres::connection_meta);
        lua->CheckType(2, GLua::Type::String);

        auto state = lua_connection_state();
        if (state->query) {
            throw std::runtime_error("query already in progress");
        }

        state->query = std::make_shared<async_postgres::Query>(
            async_postgres::DescribePreparedCommand{
                lua->GetString(2),
            });

        if (lua->IsType(3, GLua::Type::Function)) {
            state->query->callback = GLua::AutoReference(lua, 3);
        }

        return 0;
    }

    lua_protected_fn(describePortal) {
        lua->CheckType(1, async_postgres::connection_meta);
        lua->CheckType(2, GLua::Type::String);

        auto state = lua_connection_state();
        if (state->query) {
            throw std::runtime_error("query already in progress");
        }

        state->query = std::make_shared<async_postgres::Query>(
            async_postgres::DescribePortalCommand{
                lua->GetString(2),
            });

        if (lua->IsType(3, GLua::Type::Function)) {
            state->query->callback = GLua::AutoReference(lua, 3);
        }

        return 0;
    }

    lua_protected_fn(reset) {
        lua->CheckType(1, async_postgres::connection_meta);

        GLua::AutoReference callback;
        if (lua->IsType(2, GLua::Type::Function)) {
            callback = GLua::AutoReference(lua, 2);
        }

        auto state = lua_connection_state();
        async_postgres::reset(lua, state, std::move(callback));

        return 0;
    }

    lua_protected_fn(setNotifyCallback) {
        lua->CheckType(1, async_postgres::connection_meta);

        auto state = lua_connection_state();
        if (lua->IsType(2, GLua::Type::Function)) {
            state->on_notify = GLua::AutoReference(lua, 2);
        }

        return 0;
    }

    lua_protected_fn(getNotifyCallback) {
        lua->CheckType(1, async_postgres::connection_meta);
        auto state = lua_connection_state();
        if (!state->on_notify.Push()) {
            lua->PushNil();
        }
        return 1;
    }

    lua_protected_fn(setNoticeCallback) {
        lua->CheckType(1, async_postgres::connection_meta);

        auto state = lua_connection_state();
        if (lua->IsType(2, GLua::Type::Function)) {
            state->on_notice = GLua::AutoReference(lua, 2);
        }

        return 0;
    }

    lua_protected_fn(getNoticeCallback) {
        lua->CheckType(1, async_postgres::connection_meta);
        auto state = lua_connection_state();
        if (!state->on_notice.Push()) {
            lua->PushNil();
        }
        return 1;
    }

    lua_protected_fn(wait) {
        lua->CheckType(1, async_postgres::connection_meta);

        auto state = lua_connection_state();
        if (state->reset_event) {
            auto event = state->reset_event;
            while (event == state->reset_event) {
                bool write =
                    state->reset_event->status == PGRES_POLLING_WRITING;
                bool read = state->reset_event->status == PGRES_POLLING_READING;
                if (!write && !read) {
                    break;
                }

                wait_for_socket(state->conn.get(), write, read);
                process_reset(lua, state);
            }

            lua->PushBool(1);
            return 1;
        }

        if (state->query) {
            auto query = state->query;

            // if query wasn't sent, send in through process_query
            if (!query->sent) {
                async_postgres::process_query(lua, state);
            }

            // while query is the same and it's not done
            while (query == state->query) {
                async_postgres::process_result(lua, state,
                                               pg::getResult(state->conn));
            }

            lua->PushBool(true);
            return 1;
        }

        lua->PushBool(false);
        return 1;
    }

    lua_protected_fn(isBusy) {
        lua->CheckType(1, async_postgres::connection_meta);
        auto state = lua_connection_state();
        lua->PushBool(state->reset_event ||
                      state->query);  // busy if reset or query are in progress
        return 1;
    }

    lua_protected_fn(querying) {
        lua->CheckType(1, async_postgres::connection_meta);
        auto state = lua_connection_state();
        lua->PushBool(!!state->query);
        return 1;
    }

    lua_protected_fn(resetting) {
        lua->CheckType(1, async_postgres::connection_meta);
        auto state = lua_connection_state();
        lua->PushBool(!!state->reset_event);
        return 1;
    }

    lua_protected_fn(setArrayResult) {
        lua->CheckType(1, async_postgres::connection_meta);
        lua->CheckType(2, GLua::Type::Bool);
        auto state = lua_connection_state();
        state->array_result = lua->GetBool(2);
        return 0;
    }

    lua_protected_fn(getArrayResult) {
        lua->CheckType(1, async_postgres::connection_meta);
        auto state = lua_connection_state();
        lua->PushBool(state->array_result);
        return 1;
    }
}  // namespace async_postgres::lua

#define register_lua_fn(name)                      \
    lua->PushCFunction(async_postgres::lua::name); \
    lua->SetField(-2, #name)

void register_connection_mt(GLua::ILuaInterface* lua) {
    async_postgres::connection_meta = lua->CreateMetaTable("PGconn");

    lua->Push(-1);
    lua->SetField(-2, "__index");

    register_lua_fn(__gc);
    register_lua_fn(query);
    register_lua_fn(queryParams);
    register_lua_fn(prepare);
    register_lua_fn(queryPrepared);
    register_lua_fn(describePrepared);
    register_lua_fn(describePortal);
    register_lua_fn(reset);
    register_lua_fn(setNotifyCallback);
    register_lua_fn(getNotifyCallback);
    register_lua_fn(setNoticeCallback);
    register_lua_fn(getNoticeCallback);
    register_lua_fn(wait);
    register_lua_fn(isBusy);
    register_lua_fn(querying);
    register_lua_fn(resetting);
    register_lua_fn(setArrayResult);
    register_lua_fn(getArrayResult);

    async_postgres::register_misc_connection_functions(lua);

    lua->Pop();
}

void make_global_table(GLua::ILuaInterface* lua) {
    lua->CreateTable();

    register_lua_fn(connect);

    async_postgres::register_enums(lua);

    lua->PushNumber(LUA_API_VERSION);
    lua->SetField(-2, "LUA_API_VERSION");

    lua->PushNumber(PQlibVersion());
    lua->SetField(-2, "PQ_VERSION");

    lua->PushString(ASYNC_POSTGRES_VERSION);
    lua->SetField(-2, "VERSION");

    lua->PushString(ASYNC_POSTGRES_BRANCH);
    lua->SetField(-2, "BRANCH");

    lua->PushString("https://github.com/Pika-Software/gmsv_async_postgres");
    lua->SetField(-2, "URL");

    lua->SetField(GLua::INDEX_GLOBAL, "async_postgres");
}

void register_loop_hook(GLua::ILuaInterface* lua) {
    lua->GetField(GLua::INDEX_GLOBAL, "hook");
    lua->GetField(-1, "Add");
    lua->PushString("Think");
    lua->PushString("async_postgres_loop");
    lua->PushCFunction(async_postgres::lua::loop);
    lua->Call(3, 0);
    lua->Pop();
}

GMOD_MODULE_OPEN() {
    auto lua = reinterpret_cast<GLua::ILuaInterface*>(LUA);

    register_connection_mt(lua);
    make_global_table(lua);
    register_loop_hook(lua);

    return 0;
}

GMOD_MODULE_CLOSE() { return 0; }
