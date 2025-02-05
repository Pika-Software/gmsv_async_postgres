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
---@field query             fun(self: PGconn, query: string, callback: PGQueryCallback)
---@field queryParams       fun(self: PGconn, query: string, params: PGAllowedParam[], callback: PGQueryCallback)
---@field prepare           fun(self: PGconn, name: string, query: string, callback: PGQueryCallback)
---@field queryPrepared     fun(self: PGconn, name: string, params: PGAllowedParam[], callback: PGQueryCallback)
---@field describePrepared  fun(self: PGconn, name: string, callback: PGQueryCallback)
---@field describePortal    fun(self: PGconn, name: string, callback: PGQueryCallback)
---@field reset             fun(self: PGconn, callback: fun(ok: boolean, err: string))
---@field wait              fun(self: PGconn): boolean
---@field isBusy            fun(self: PGconn): boolean
---@field querying          fun(self: PGconn): boolean
---@field resetting         fun(self: PGconn): boolean
---@field db                fun(self: PGconn): string
---@field host              fun(self: PGconn): string
---@field hostaddr          fun(self: PGconn): string
---@field port              fun(self: PGconn): number
---@field status            fun(self: PGconn): PGConnStatus
---@field transactionStatus fun(self: PGconn): PGTransStatus
---@field parameterStatus   fun(self: PGconn, param: string): string
---@field protocolVersion   fun(self: PGconn): number
---@field serverVersion     fun(self: PGconn): number
---@field errorMessage      fun(self: PGconn): string
---@field backendPID        fun(self: PGconn): number
---@field sslInUse          fun(self: PGconn): boolean
---@field sslAttribute      fun(self: PGconn, name: string): string
---@field clientEncoding    fun(self: PGconn): string
---@field setClientEncoding fun(self: PGconn, encoding: string)
---@field encryptPassword   fun(self: PGconn, user: string, password: string, algorithm: string): string
---@field escape            fun(self: PGconn, str: string): string
---@field escapeIdentifier  fun(self: PGconn, str: string): string
---@field escapeBytea       fun(self: PGconn, str: string): string
---@field unescapeBytea     fun(self: PGconn, str: string): string

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

local Queue = {}
Queue.__index = Queue

function Queue:prepend(obj)
    self[self.head] = obj
    self.head = self.head - 1
end

function Queue:push(obj)
    self.tail = self.tail + 1
    self[self.tail] = obj
end

function Queue:pop()
    if self.head ~= self.tail then
        self.head = self.head + 1
        local obj = self[self.head]
        self[self.head] = nil
        if self.head == self.tail then
            self.head = 0
            self.tail = 0
        end
        return obj
    end
end

function Queue:size()
    return self.tail - self.head
end

function Queue.new()
    return setmetatable({ head = 0, tail = 0 }, Queue)
end

---@class PGQuery
---@field command 'query' | 'queryParams' | 'prepare' | 'queryPrepared' | 'describePrepared' | 'describePortal'
---@field name string?
---@field query string?
---@field params table?
---@field callback PGQueryCallback

---@class PGClient
---@field url string **readonly** connection url
---@field connecting boolean **readonly** is client connecting to the database
---@field closed boolean **readonly** is client closed (to change it to true use `:close()`)
---@field maxRetries number maximum number of retries to reconnect to the database if connection was lost (set to 0 to disable)
---@field private retryAttempted number number of attempts to reconnect to the database
---@field private conn PGconn native connection object (do not use it directly, otherwise be careful not to store it anywhere else, otherwise closing connection will be impossible)
---@field private queries { push: fun(self, q: PGQuery), prepend: fun(self, q: PGQuery), pop: (fun(self): PGQuery), size: fun(self): number } list of queries
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
    if self.closed then
        error("client was closed")
    end

    if self.connecting then
        error("already connecting to the database")
    end

    if not self.conn then
        error("client was not connected to the database")
    end

    self.conn:reset(function(ok, err)
        self.connecting = false
        if ok then
            self.retryAttempted = 0
        end

        xpcall(callback, ErrorNoHaltWithStack, ok, err)
        self:processQueue()
    end)

    self.connecting = true
end

--- Makes connection to the database.
--- If connection was already made, will reconnect to the databse.
---@param callback fun(ok: boolean, err: string?) callback function
function Client:connect(callback)
    if self.closed then
        error("client was closed")
    end

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
            xpcall(callback, ErrorNoHaltWithStack, ok)
            self:processQueue()
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

--- Returns if client is processing a query or is resetting the connection
function Client:isBusy()
    return self.conn:isBusy()
end

--- Waits for current query (or reset) to finish
--- and returns true if waited, false if nothing to wait
---@return boolean
function Client:wait()
    if not self.conn then
        return false
    end

    return self.conn:wait()
end

--- Tries to reconnect to the database,
--- if maximum number will be reached, we will stop trying to reconnect
---
--- WARNING! If number of attempts is exceeded, first query will be failed
---@private
function Client:tryReconnect()
    if self.retryAttempted < self.maxRetries and not self.closed then
        self.retryAttempted = self.retryAttempted + 1
        self:reset(function(ok)
            if not ok then
                timer.Simple(5, function()
                    self:tryReconnect()
                end)
            end
        end)
    else
        local query = self.queries:pop()
        query.callback(false, "connection to the databse was lost, maximum number of retries exceeded")
    end
end

---@private
---@param query PGQuery
function Client:runQuery(query)
    local function callback(ok, result, errdata)
        -- if connection was lost, put query back into the queue (it was popped before)
        -- and try to reconnect
        if not ok and not self:connected() and self.retryAttempted < self.maxRetries then
            self.queries:prepend(query)
            self:tryReconnect()
            return
        end

        xpcall(query.callback, ErrorNoHaltWithStack, ok, result, errdata)
        self:processQueue()
    end

    if query.command == "query" then
        self.conn:query(query.query, callback)
    elseif query.command == "queryParams" then
        self.conn:queryParams(query.query, query.params, callback)
    elseif query.command == "prepare" then
        self.conn:prepare(query.name, query.query, callback)
    elseif query.command == "queryPrepared" then
        self.conn:queryPrepared(query.name, query.params, callback)
    elseif query.command == "describePrepared" then
        self.conn:describePrepared(query.name, callback)
    elseif query.command == "describePortal" then
        self.conn:describePortal(query.name, callback)
    end
end

--- Processes queries in the queue
---@private
function Client:processQueue()
    if not self:connected() or self:isBusy() or self.queries:size() == 0 then
        return
    end

    local query = self.queries:pop()
    local ok, err = pcall(self.runQuery, self, query)
    if not ok then
        xpcall(query.callback, ErrorNoHaltWithStack, false, err)
    end
end

--- Sends a query to the server
---
--- It's recommended to use queryParams to prevent sql injections if you are going to pass parameters to a query.
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQEXEC
---@see PGClient.queryParams
---@param query string
---@param callback PGQueryCallback
function Client:query(query, callback)
    self.queries:push({
        command = "query",
        query = query,
        callback = callback,
    })
    self:processQueue()
end

--- Sends a query with given parameters to the server
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQEXECPARAMS
---@param query string
---@param params PGAllowedParam[]
---@param callback PGQueryCallback
function Client:queryParams(query, params, callback)
    self.queries:push({
        command = "queryParams",
        query = query,
        params = params,
        callback = callback,
    })
    self:processQueue()
end

--- Sends a request to create prepared statement,
--- unnamed prepared statement will replace any existing unnamed prepared statement
---
--- If prepared statement with existing name exists, error will be thrown
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQPREPARE
---@see PGClient.queryPrepared
---@param name string
---@param query string
---@param callback PGQueryCallback
function Client:prepare(name, query, callback)
    self.queries:push({
        command = "prepare",
        name = name,
        query = query,
        callback = callback,
    })
    self:processQueue()
end

--- Sends a request to execute prepared statement
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQEXECPREPARED
---@see PGClient.prepare
---@param name string
---@param params PGAllowedParam[]
---@param callback PGQueryCallback
function Client:queryPrepared(name, params, callback)
    self.queries:push({
        command = "queryPrepared",
        name = name,
        params = params,
        callback = callback,
    })
    self:processQueue()
end

--- Sends a request to describe prepared statement
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQDESCRIBEPREPARED
---@param name string
---@param callback PGQueryCallback
function Client:describePrepared(name, callback)
    self.queries:push({
        command = "describePrepared",
        name = name,
        callback = callback,
    })
    self:processQueue()
end

--- Sends a request to describe portal
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQDESCRIBEPORTAL
---@param name string
---@param callback PGQueryCallback
function Client:describePortal(name, callback)
    self.queries:push({
        command = "describePortal",
        name = name,
        callback = callback,
    })
    self:processQueue()
end

--- Closes current connection to the databse
--- and clears all queries in the queue
---
--- If `wait = true`, will wait until all queries are processed
---
--- P.S. You can change `client.closed` variable to false, and reuse the client
---@param wait boolean?
function Client:close(wait)
    if wait then
        local iterations = 0
        while self:wait() do
            iterations = iterations + 1
            if iterations > 1000 then
                ErrorNoHaltWithStack(
                    "PGClient:close() - waiting for queries too long, closing forcefully")
                break
            end
        end
    end

    local iterations = 0
    while self.queries:size() ~= 0 do
        local q = self.queries:pop()
        xpcall(q.callback, ErrorNoHaltWithStack, false, "connection to the database was closed")

        iterations = iterations + 1
        if iterations > 1000 then
            ErrorNoHaltWithStack("PGClient:close() - queries are infinite, ignoring them")
            break
        end
    end

    self.queries = Queue.new()
    self.conn = nil
    self.closed = true
    collectgarbage() -- collect PGconn so it will be closed
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
    return setmetatable({
        url = url,
        connecting = false,
        queries = Queue.new(),
        maxRetries = math.huge,
        retryAttempted = 0,
    }, Client)
end
