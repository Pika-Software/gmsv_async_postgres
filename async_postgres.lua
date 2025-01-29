--- !!! Do not put this file to `lua/includes/modules/` directory
--- !!! it will break the module loading
---
--- I would advice putting this file into your project locally
--- and just include it

---@class async_postgres
---@field VERSION string e.g. "1.0.0"
---@field BRANCH string e.g. "main"
---@field URL string
---@field PQ_VERSION number e.g. 160004
---@field LUA_API_VERSION number e.g. 1
---@field CONNECTION_OK number
---@field CONNECTION_BAD number
---@field PQTRANS_IDLE number
---@field PQTRANS_ACTIVE number
---@field PQTRANS_INTRANS number
---@field PQTRANS_INERROR number
---@field PQTRANS_UNKNOWN number
---@field PQERRORS_TERSE number
---@field PQERRORS_DEFAULT number
---@field PQERRORS_VERBOSE number
---@field PQERRORS_SQLSTATE number
---@field PQSHOW_CONTEXT_NEVER number
---@field PQSHOW_CONTEXT_ERRORS number
---@field PQSHOW_CONTEXT_ALWAYS number
---@field connect fun(url: string, callback: fun(ok: boolean, conn: PGconn|string))

---@alias PGAllowedParam string | number | boolean | nil
---@alias PGQueryCallback fun(ok: boolean, result: PGResult|string, errdata: table?)
---@alias PGConnStatus `async_postgres.CONNECTION_OK` | `async_postgres.CONNECTION_BAD`
---@alias PGTransStatus `async_postgres.PQTRANS_IDLE` | `async_postgres.PQTRANS_ACTIVE` | `async_postgres.PQTRANS_INTRANS` | `async_postgres.PQTRANS_INERROR` | `async_postgres.PQTRANS_UNKNOWN`
---@alias PGErrorVerbosity `async_postgres.PQERRORS_TERSE` | `async_postgres.PQERRORS_DEFAULT` | `async_postgres.PQERRORS_VERBOSE` | `async_postgres.PQERRORS_SQLSTATE`
---@alias PGShowContext `async_postgres.PQSHOW_CONTEXT_NEVER` | `async_postgres.PQSHOW_CONTEXT_ERRORS` | `async_postgres.PQSHOW_CONTEXT_ALWAYS`

---@class PGconn
---@field query fun(query: string, callback: PGQueryCallback)
---@field queryParams fun(query: string, params: PGAllowedParam[], callback: PGQueryCallback)
---@field prepare fun(name: string, query: string, callback: PGQueryCallback)
---@field queryPrepared fun(name: string, params: PGAllowedParam[], callback: PGQueryCallback)
---@field describePrepared fun(name: string, callback: PGQueryCallback)
---@field describePortal fun(name: string, callback: PGQueryCallback)
---@field reset fun(callback: fun(ok: boolean, err: string?))
---@field wait fun()
---@field isBusy fun(): boolean
---@field querying fun(): boolean
---@field resetting fun(): boolean
---@field db fun(): string
---@field host fun(): string
---@field hostaddr fun(): string
---@field port fun(): number
---@field status fun(): PGConnStatus
---@field transactionStatus fun(): PGTransStatus
---@field parameterStatus fun(param: string): string
---@field protocolVersion fun(): number
---@field serverVersion fun(): number
---@field errorMessage fun(): string
---@field backendPID fun(): number
---@field sslInUse fun(): boolean
---@field sslAttribute fun(name: string): string
---@field clientEncoding fun(): string
---@field setClientEncoding fun(encoding: string)
---@field encryptPassword fun(user: string, password: string, algorithm: string): string
---@field escape fun(str: string): string
---@field escapeIdentifier fun(str: string): string
---@field escapeBytea fun(str: string): string
---@field unescapeBytea fun(str: string): string

---@class PGResult
---@field fields { name: string, type: number }[] list of fields in the result
---@field rows table<string, string?>[]
---@field oid number oid of the inserted row, otherwise 0
---@field command string command of the query in format of COMMAND [NUM], e.g. SELECT 1

if not util.IsBinaryModuleInstalled("async_postgres") then
    error("async_postgres module is not installed, " ..
        "download it from https://github.com/Pika-Software/gmsv_async_postgres/releases")
end

require("async_postgres")

if not async_postgres then
    error("async_postgres does not exist, there is a problem with the module")
end

---@class async_postgres
async_postgres = async_postgres

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
