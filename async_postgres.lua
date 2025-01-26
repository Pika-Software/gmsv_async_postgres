--- !!! Do not put this file to `lua/includes/modules/` directory
--- !!! it will break the module loading
---
--- I would advice putting this file into your project locally
--- and just include it

if not util.IsBinaryModuleInstalled("async_postgres") then
    error("async_postgres module is not installed, " ..
        "download it from https://github.com/Pika-Software/gmsv_async_postgres/releases")
end

require("async_postgres")

if not async_postgres then
    error("async_postgres does not exist, there is a problem with the module")
end

if async_postgres.LUA_API_VERSION ~= 1 then
    error("async_postgres module has different Lua API version, " ..
        "expected 1, got " .. async_postgres.LUA_API_VERSION)
end
