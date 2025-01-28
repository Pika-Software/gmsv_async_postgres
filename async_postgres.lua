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

---@class PGClient
---@field url string **readonly** connection url
---@field connecting boolean **readonly** is client connecting to the database
---@field private conn PGconn native connection object
local Client = {}

---@private
Client.__index = Client


--- Checks if client is connected to the database
---@return boolean
function Client:connected()
    return self.conn ~= nil and self.conn:status() == async_postgres.CONNECTION_OK
end

--- Reconnects to the database
---@param callback fun(ok: boolean, err: string?) callback function
function Client:reset(callback)
    if self.connecting then
        error("already connecting to the database")
    end

    if not self.conn then
        error("client was not connected to the database")
    end

    self.conn:reset(function(ok, err)
        self.connecting = false
        callback(ok, err)
    end)

    self.connecting = true
end

--- Makes connection to the database.
--- If connection was already made, will reconnect to the databse.
---@param callback fun(ok: boolean, err: string?) callback function
function Client:connect(callback)
    if self.connecting then
        error("already connecting to the database")
    end

    -- if client already has PGconn object
    -- only reset needed
    if self.conn then
        return self:reset(callback)
    end

    local finished = false
    async_postgres.connect(self.url, function(ok, conn)
        finished = true
        self.connecting = false

        if ok then
            ---@cast conn PGconn
            self.conn = conn
            callback(ok)
        else
            ---@cast conn string
            callback(ok, conn)
        end
    end)

    -- if somehow connect(...) already called callback, do not set connecting state
    if not finished then
        self.connecting = true
    end
end

--- Creates a new client with given connection url
--- ```lua
--- local client = async_postgres.Client("postgresql://user:password@localhost:5432/database")
---
--- client:Connect(function(success, err)
---     if not success then
---         print("Failed to connect to the database: " .. err)
---     else
---         print("Connected to the database", client)
---     end
--- end)
--- ```
---
--- connectiong url format can be found at https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
---@param url string connection url, see libpq documentation for more information
---@return PGClient
function async_postgres.Client(url)
    local client = setmetatable({}, Client)

    client.url = url
    client.connecting = false

    return client
end
