#include <Platform.hpp>

#include "async_postgres.hpp"

using namespace async_postgres;

std::string_view async_postgres::get_string(GLua::ILuaInterface* lua,
                                            int index) {
    unsigned int len = 0;
    const char* str = lua->GetString(index, &len);
    return {str, len};
}

void print_stack(GLua::ILuaInterface* lua) {
    lua->Msg("stack: %d\n", lua->Top());
    for (int i = 1; i <= lua->Top(); i++) {
        lua->GetField(GLua::INDEX_GLOBAL, "tostring");
        lua->Push(i);
        lua->Call(1, 1);
        lua->Msg("\t%d: [%s] %s\n", i, lua->GetTypeName(lua->GetType(i)),
                 lua->GetString(-1));
        lua->Pop();
    }
}

void async_postgres::pcall(GLua::ILuaInterface* lua, int nargs, int nresults) {
    lua->GetField(GLua::INDEX_GLOBAL, "ErrorNoHaltWithStack");
    lua->Insert(-nargs - 2);
    if (lua->PCall(nargs, nresults, -nargs - 2) != 0) {
        lua->Pop();
    }

    lua->Pop();  // ErrorNoHaltWithStack
}

ParamValues async_postgres::array_to_params(GLua::ILuaInterface* lua,
                                            int index) {
    lua->Push(index);
    int len = lua->ObjLen(-1);

    ParamValues param(len);
    for (int i = 0; i < len; i++) {
        lua->PushNumber(i + 1);
        lua->GetTable(-2);

        auto type = lua->GetType(-1);
        if (type == GLua::Type::String) {
            auto value = get_string(lua, -1);
            param.strings[i] = std::string(value.data(), value.size());
            param.values[i] = param.strings[i].c_str();
            param.lengths[i] = value.length();
            param.formats[i] = 1;
        } else if (type == GLua::Type::Number) {
            param.strings[i] = std::to_string(lua->GetNumber(-1));
            param.values[i] = param.strings[i].c_str();
        } else if (type == GLua::Type::Bool) {
            param.values[i] = lua->GetBool(-1) ? "true" : "false";
        } else if (type == GLua::Type::Nil) {
            param.values[i] = nullptr;
        } else {
            throw std::runtime_error(
                "unsupported type given into params array");
        }

        lua->Pop(1);
    }

    lua->Pop(1);
    return param;
}

#if SYSTEM_IS_WINDOWS
#include <WinSock2.h>
#define poll WSAPoll
#else
#include <poll.h>
#endif

SocketStatus async_postgres::check_socket_status(PGconn* conn) {
    SocketStatus status = {};
    int fd = PQsocket(conn);
    if (fd < 0) {
        status.failed = true;
        return status;
    }

    pollfd fds[1] = {{fd, POLLIN | POLLOUT, 0}};
    if (poll(fds, 1, 0) < 0) {
        status.failed = true;
    } else {
        status.read_ready = fds[0].revents & POLLIN;
        status.write_ready = fds[0].revents & POLLOUT;
        status.failed = fds[0].revents & POLLERR || fds[0].revents & POLLHUP ||
                        fds[0].revents & POLLNVAL;
    }

    return status;
}
