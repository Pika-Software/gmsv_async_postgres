

#include "async_postgres.hpp"

using namespace async_postgres;

#define lua_connection_state()                    \
    lua->GetUserType<async_postgres::Connection>( \
        1, async_postgres::connection_meta)

#define lua_connection() lua_connection_state()->conn.get()

#define lua_string_getter(name, getter)            \
    lua_protected_fn(name) {                       \
        lua->CheckType(1, connection_meta);        \
        lua->PushString(getter(lua_connection())); \
        return 1;                                  \
    }

#define lua_number_getter(name, getter)            \
    lua_protected_fn(name) {                       \
        lua->CheckType(1, connection_meta);        \
        lua->PushNumber(getter(lua_connection())); \
        return 1;                                  \
    }

#define lua_bool_getter(name, getter)            \
    lua_protected_fn(name) {                     \
        lua->CheckType(1, connection_meta);      \
        lua->PushBool(getter(lua_connection())); \
        return 1;                                \
    }

namespace async_postgres::lua {
    // 34.2. Connection Status Functions
    lua_string_getter(db, PQdb);
    lua_string_getter(user, PQuser);
    lua_string_getter(host, PQhost);
    lua_string_getter(hostaddr, PQhostaddr);
    lua_string_getter(port, PQport);
    lua_number_getter(status, PQstatus);
    lua_number_getter(transactionStatus, PQtransactionStatus);

    lua_protected_fn(parameterStatus) {
        lua->CheckType(1, connection_meta);
        lua->CheckType(2, GLua::Type::String);

        lua->PushString(PQparameterStatus(lua_connection(), lua->GetString(2)));
        return 1;
    }

    lua_number_getter(protocolVersion, PQprotocolVersion);
    lua_number_getter(serverVersion, PQserverVersion);
    lua_string_getter(errorMessage, PQerrorMessage);
    lua_number_getter(backendPID, PQbackendPID);
    lua_bool_getter(sslInUse, PQsslInUse);

    lua_protected_fn(sslAttribute) {
        lua->CheckType(1, connection_meta);
        lua->CheckType(2, GLua::Type::String);

        lua->PushString(PQsslAttribute(lua_connection(), lua->GetString(2)));
        return 1;
    }

    lua_protected_fn(clientEncoding) {
        lua->CheckType(1, connection_meta);
        lua->PushString(
            pg_encoding_to_char(PQclientEncoding(lua_connection())));
        return 1;
    }

    lua_protected_fn(setClientEncoding) {
        lua->CheckType(1, connection_meta);
        lua->CheckType(2, GLua::Type::String);

        lua->PushBool(
            PQsetClientEncoding(lua_connection(), lua->GetString(2)) == 0);
        return 1;
    }

    lua_protected_fn(encryptPassword) {
        lua->CheckType(1, connection_meta);
        lua->CheckType(2, GLua::Type::String);
        lua->CheckType(3, GLua::Type::String);
        lua->CheckType(4, GLua::Type::String);

        auto result =
            PQencryptPasswordConn(lua_connection(), lua->GetString(2),
                                  lua->GetString(3), lua->GetString(4));

        lua->PushString(result);
        PQfreemem(result);
        return 1;
    }

    lua_protected_fn(escape) {
        lua->CheckType(1, connection_meta);
        lua->CheckType(2, GLua::Type::String);

        auto str = get_string(lua, 2);
        auto escaped =
            PQescapeLiteral(lua_connection(), str.data(), str.size());

        if (!escaped) {
            throw std::runtime_error(PQerrorMessage(lua_connection()));
        }

        lua->PushString(escaped);
        PQfreemem(escaped);
        return 1;
    }

    lua_protected_fn(escapeIdentifier) {
        lua->CheckType(1, connection_meta);
        lua->CheckType(2, GLua::Type::String);

        auto str = get_string(lua, 2);
        auto escaped =
            PQescapeIdentifier(lua_connection(), str.data(), str.size());

        if (!escaped) {
            throw std::runtime_error(PQerrorMessage(lua_connection()));
        }

        lua->PushString(escaped);
        PQfreemem(escaped);
        return 1;
    }

    lua_protected_fn(escapeBytea) {
        lua->CheckType(1, connection_meta);
        lua->CheckType(2, GLua::Type::String);

        unsigned int strLen = 0;
        size_t outLen = 0;
        const unsigned char* str =
            reinterpret_cast<const unsigned char*>(lua->GetString(2, &strLen));
        char* escaped =
            reinterpret_cast<char*>(PQescapeBytea(str, strLen, &outLen));

        if (!escaped) {
            throw std::runtime_error(PQerrorMessage(lua_connection()));
        }

        lua->PushString(escaped, outLen - 1);
        PQfreemem(escaped);
        return 1;
    }

    lua_protected_fn(unescapeBytea) {
        lua->CheckType(1, connection_meta);
        lua->CheckType(2, GLua::Type::String);

        unsigned int strLen = 0;
        size_t outLen = 0;
        const unsigned char* str =
            reinterpret_cast<const unsigned char*>(lua->GetString(2, &strLen));
        char* unescaped =
            reinterpret_cast<char*>(PQunescapeBytea(str, &outLen));

        if (!unescaped) {
            throw std::runtime_error(PQerrorMessage(lua_connection()));
        }

        lua->PushString(unescaped, outLen);
        PQfreemem(unescaped);
        return 1;
    }
}  // namespace async_postgres::lua

#define register_lua_fn(name)                      \
    lua->PushCFunction(async_postgres::lua::name); \
    lua->SetField(-2, #name)

void async_postgres::register_misc_connection_functions(
    GLua::ILuaInterface* lua) {
    register_lua_fn(db);
    register_lua_fn(user);
    register_lua_fn(host);
    register_lua_fn(hostaddr);
    register_lua_fn(port);
    register_lua_fn(status);
    register_lua_fn(transactionStatus);
    register_lua_fn(parameterStatus);
    register_lua_fn(protocolVersion);
    register_lua_fn(serverVersion);
    register_lua_fn(errorMessage);
    register_lua_fn(backendPID);
    register_lua_fn(sslInUse);
    register_lua_fn(sslAttribute);
    register_lua_fn(clientEncoding);
    register_lua_fn(setClientEncoding);
    register_lua_fn(encryptPassword);
    register_lua_fn(escape);
    register_lua_fn(escapeIdentifier);
    register_lua_fn(escapeBytea);
    register_lua_fn(unescapeBytea);
}

#define enum_value(name) {#name, name}

void async_postgres::register_enums(GLua::ILuaInterface* lua) {
    using enum_array = std::vector<std::pair<const char*, int>>;

    std::vector<enum_array> enums = {
        {
            enum_value(CONNECTION_OK),
            enum_value(CONNECTION_BAD),
        },
        {
            enum_value(PQTRANS_IDLE),
            enum_value(PQTRANS_ACTIVE),
            enum_value(PQTRANS_INTRANS),
            enum_value(PQTRANS_INERROR),
            enum_value(PQTRANS_UNKNOWN),
        },
        {
            enum_value(PQERRORS_TERSE),
            enum_value(PQERRORS_DEFAULT),
            enum_value(PQERRORS_VERBOSE),
            enum_value(PQERRORS_SQLSTATE),
        },
        {
            enum_value(PQSHOW_CONTEXT_NEVER),
            enum_value(PQSHOW_CONTEXT_ERRORS),
            enum_value(PQSHOW_CONTEXT_ALWAYS),
        },
    };

    for (const auto& e : enums) {
        for (const auto& [name, value] : e) {
            lua->PushNumber(value);
            lua->SetField(-2, name);
        }
    }
}
