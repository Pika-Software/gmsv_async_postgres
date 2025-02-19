#pragma once
#include <GarrysMod/Lua/AutoReference.h>
#include <GarrysMod/Lua/Interface.h>
#include <GarrysMod/Lua/LuaInterface.h>

#include <algorithm>
#include <chrono>
#include <exception>
#include <memory>
#include <queue>
#include <string_view>
#include <variant>
#include <vector>

#include "safe_pg.hpp"

#define LUA_API_VERSION 1

namespace GLua = GarrysMod::Lua;

#define lua_interface()                                 \
    reinterpret_cast<GLua::ILuaInterface*>(L->luabase); \
    L->luabase->SetState(L)

#define lua_protected_fn(name)                 \
    int name##__Imp(GLua::ILuaInterface* lua); \
    int name(lua_State* L) {                   \
        auto lua = lua_interface();            \
        try {                                  \
            int ret = name##__Imp(lua);        \
            return ret;                        \
        } catch (const std::exception& e) {    \
            lua->ThrowError(e.what());         \
            return 0;                          \
        }                                      \
    }                                          \
    int name##__Imp([[maybe_unused]] GarrysMod::Lua::ILuaInterface* lua)

namespace async_postgres {
    typedef std::variant<std::nullptr_t, std::string, double, bool> ParamValue;

    struct ParamValues {
        ParamValues(int n_params)
            : strings(n_params),
              values(n_params),
              lengths(n_params, 0),
              formats(n_params, 0) {}

        inline int length() const { return strings.size(); }

        std::vector<std::string> strings;
        // vectors below are used in PQexecParams-like functions
        std::vector<const char*> values;
        std::vector<int> lengths;
        std::vector<int> formats;
    };

    struct SocketStatus {
        bool read_ready = false;
        bool write_ready = false;
        bool failed = false;
    };

    struct SimpleCommand {
        std::string command;
    };

    struct ParameterizedCommand {
        std::string command;
        ParamValues param;
    };

    struct CreatePreparedCommand {
        std::string name;
        std::string command;
    };

    struct PreparedCommand {
        std::string name;
        ParamValues param;
    };

    struct DescribePreparedCommand {
        std::string name;
    };

    struct DescribePortalCommand {
        std::string name;
    };

    struct Query {
        using CommandVariant =
            std::variant<SimpleCommand, ParameterizedCommand,
                         CreatePreparedCommand, PreparedCommand,
                         DescribePreparedCommand, DescribePortalCommand>;

        Query(CommandVariant&& command) : command(std::move(command)) {}

        CommandVariant command;
        GLua::AutoReference callback;
        bool sent = false;
        bool flushed = false;
    };

    struct ResetEvent {
        std::vector<GLua::AutoReference> callbacks;
        PostgresPollingStatusType status = PGRES_POLLING_WRITING;
    };

    struct Connection {
        GLua::ILuaInterface* lua;
        pg::conn conn;
        std::shared_ptr<Query> query;
        std::shared_ptr<ResetEvent> reset_event;
        GLua::AutoReference on_notify;
        GLua::AutoReference on_notice;
        bool array_result = false;

        Connection(GLua::ILuaInterface* lua, pg::conn&& conn);
        ~Connection();
    };

    extern int connection_meta;
    extern std::vector<Connection*> connections;

    // connection.cpp
    void connect(GLua::ILuaInterface* lua, std::string_view url,
                 GLua::AutoReference&& callback);
    void process_pending_connections(GLua::ILuaInterface* lua);

    void reset(GLua::ILuaInterface* lua, Connection* state,
               GLua::AutoReference&& callback);
    void process_reset(GLua::ILuaInterface* lua, Connection* state);

    // notifications.cpp
    void process_notifications(GLua::ILuaInterface* lua, Connection* state);

    // query.cpp
    void process_result(GLua::ILuaInterface* lua, Connection* state,
                        pg::result&& result);
    void process_query(GLua::ILuaInterface* lua, Connection* state);

    // result.cpp
    void create_result_table(GLua::ILuaInterface* lua, PGresult* result,
                             bool array_result);
    void create_result_error_table(GLua::ILuaInterface* lua,
                                   const PGresult* result);

    // misc.cpp
    void register_misc_connection_functions(GLua::ILuaInterface* lua);
    void register_enums(GLua::ILuaInterface* lua);

    // util.cpp
    std::string_view get_string(GLua::ILuaInterface* lua, int index = -1);
    void pcall(GLua::ILuaInterface* lua, int nargs, int nresults);
    // Converts a lua array at given index to a ParamValues
    ParamValues array_to_params(GLua::ILuaInterface* lua, int index);
    SocketStatus check_socket_status(PGconn* conn);
    bool wait_for_socket(PGconn* conn, bool write = false, bool read = false,
                         int timeout = -1);
};  // namespace async_postgres
