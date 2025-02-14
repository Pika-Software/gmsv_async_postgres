--- !!! Do not put this file to `lua/includes/modules/` directory
--- !!! it will break the module loading
---
--- I would advice putting this file into your project locally
--- and just include it

--- MIT License
---
--- Copyright (c) 2023 Pika Software
---
--- Permission is hereby granted, free of charge, to any person obtaining a copy
--- of this software and associated documentation files (the "Software"), to deal
--- in the Software without restriction, including without limitation the rights
--- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--- copies of the Software, and to permit persons to whom the Software is
--- furnished to do so, subject to the following conditions:
---
--- The above copyright notice and this permission notice shall be included in all
--- copies or substantial portions of the Software.
---
--- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--- SOFTWARE.

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
---@field user              fun(self: PGconn): string
---@field pass              fun(self: PGconn): string
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
---@field setNotifyCallback fun(self: PGconn, callback: fun(channel: string, payload: string, backendPID: number))
---@field getNotifyCallback fun(self: PGconn): fun(channel: string, payload: string, backendPID: number)
---@field setArrayResult    fun(self: PGconn, enabled: boolean)
---@field getArrayResult    fun(self: PGconn): boolean

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


---@class async_postgres_module : async_postgres
local module = setmetatable({}, { __index = async_postgres })

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
---@field array_result boolean option to receive PGResult row fields as array instead of table (default: false)
---@field private conn PGconn native connection object (do not use it directly, otherwise be careful not to store it anywhere else, otherwise closing connection will be impossible)
---@field private queries { push: fun(self, q: PGQuery), prepend: fun(self, q: PGQuery), pop: (fun(self): PGQuery), size: fun(self): number } list of queries
---@field package errorHandler function function that just calls self:onError(...)
---@field package acquired boolean
---@field package pool PGPool?
local Client = {}

---@private
Client.__index = Client

---@private
function Client:__tostring()
    return string.format("PGClient<%s@%s:%d/%s (%s)>",
        self:user(), self:host(), self:port(), self:db(), self:connected() and "connected" or "disconnected")
end

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

    if not self.conn then
        error("client was not connected to the database")
    end

    self.conn:reset(function(ok, err)
        self.connecting = false
        if ok then
            self.retryAttempted = 0
        end

        xpcall(callback, self.errorHandler, ok, err)
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
    local ok, err = pcall(async_postgres.connect, self.url, function(ok, conn)
        finished = true
        self.connecting = false

        if ok then
            ---@cast conn PGconn
            self.conn = conn
            self.conn:setNotifyCallback(function(channel, payload, backendPID)
                xpcall(self.onNotify, self.errorHandler, self, channel, payload, backendPID)
            end)

            xpcall(callback, self.errorHandler, ok)
            self:processQueue()
        else
            ---@cast conn string
            callback(ok, conn)
        end
    end)

    -- async_postgres.connect() can throw error if for example url is invalid
    if not ok then
        xpcall(callback, self.errorHandler, false, err)
        return
    end

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

---@private
---@param query PGQuery
function Client:runQuery(query)
    local array_result = self.array_result
    if array_result then
        self.conn:setArrayResult(true)
    end

    local function callback(ok, result, errdata)
        if array_result and not self.conn:querying() then
            -- final query, reset array result
            self.conn:setArrayResult(false)
        end

        if not ok then
            local success, retry = xpcall(function() return self:onEnd() end, self.errorHandler)
            if success and retry then
                self.queries:prepend(query)
                self:processQueue() -- just in case if we somehow already reconnected
                return
            end
        end

        xpcall(query.callback, self.errorHandler, ok, result, errdata)
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
        xpcall(query.callback, self.errorHandler, false, err)
    end
end

--- Sends a query to the server
---
--- It's recommended to use queryParams to prevent sql injections if you are going to pass parameters to a query.
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQEXEC
---@see PGClient.queryParams to send a query with parameters
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
---@see PGClient.queryPrepared to use a prepared statement
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
---@see PGClient.prepare to prepare a statement
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
                self:onError("PGClient:close() - waiting for queries too long, closing forcefully")
                break
            end
        end
    end

    local iterations = 0
    while self.queries:size() ~= 0 do
        local q = self.queries:pop()
        xpcall(q.callback, self.errorHandler, false, "connection to the database was closed")

        iterations = iterations + 1
        if iterations > 1000 then
            self:onError("PGClient:close() - queries are infinite, ignoring them")
            break
        end
    end

    self.queries = Queue.new()
    self.conn = nil
    self.closed = true
    collectgarbage() -- collect PGconn so it will be closed

    xpcall(function() return self:onEnd() end, self.errorHandler)
end

--- Returns number of queued queries (does not includes currently executing query)
---@see PGClient.isBusy to check if any query currently executing
---@return number
function Client:pendingQueries()
    return self.queries:size()
end

--- Returns the database name of the connection.
---@return string
function Client:db()
    return self.conn and self.conn:db() or "unknown"
end

--- Returns the user name of the connection.
---@return string
function Client:user()
    return self.conn and self.conn:user() or "unknown"
end

--- Returns the password of the connection.
---@return string
function Client:pass()
    return self.conn and self.conn:pass() or "unknown"
end

--- Returns the host name of the connection.
---@return string
function Client:host()
    return self.conn and self.conn:host() or "unknown"
end

--- Returns the server IP address of the active connection.
---@return string
function Client:hostaddr()
    return self.conn and self.conn:hostaddr() or "unknown"
end

--- Returns the port of the active connection.
---@return number
function Client:port()
    return self.conn and self.conn:port() or 0
end

--- Returns the current in-transaction status of the server.
---@return PGTransStatus
function Client:transactionStatus()
    return self.conn and self.conn:transactionStatus() or async_postgres.PQTRANS_UNKNOWN
end

--- Looks up a current parameter setting of the server.
---
--- https://www.postgresql.org/docs/16/libpq-status.html#LIBPQ-PQPARAMETERSTATUS
---@param paramName string
---@return string
function Client:parameterStatus(paramName)
    return self.conn and self.conn:parameterStatus(paramName) or "unknown"
end

--- Interrogates the frontend/backend protocol being used.
---@return number
function Client:protocolVersion()
    return self.conn and self.conn:protocolVersion() or 0
end

--- Returns an integer representing the server version.
---@return number
function Client:serverVersion()
    return self.conn and self.conn:serverVersion() or 0
end

--- Returns the error message most recently generated by an operation on the connection.
---@return string
function Client:errorMessage()
    return self.conn and self.conn:errorMessage() or "unknown"
end

--- Returns the process ID (PID) of the backend process handling this connection.
---@return number
function Client:backendPID()
    return self.conn and self.conn:backendPID() or 0
end

--- Returns true if the connection uses SSL, false if not.
---@return boolean
function Client:sslInUse()
    return self.conn and self.conn:sslInUse() or false
end

--- Returns SSL-related information about the connection.
---
--- https://www.postgresql.org/docs/16/libpq-status.html#LIBPQ-PQSSLATTRIBUTE
---@param name string
---@return string
function Client:sslAttribute(name)
    return self.conn and self.conn:sslAttribute(name) or "unknown"
end

--- Prepares the encrypted form of a PostgreSQL password.
---
--- https://www.postgresql.org/docs/16/libpq-misc.html#LIBPQ-PQENCRYPTPASSWORDCONN
---@param user string
---@param password string
---@param algorithm string
---@return string
function Client:encryptPassword(user, password, algorithm)
    if not self.conn then
        error("client was not connected to the database, please use :connect() first")
    end
    return self.conn:encryptPassword(user, password, algorithm)
end

--- Escapes a string for use within an SQL command.
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQESCAPELITERAL
---@see PGClient.queryParams does not needs to escape parameters
---@return string
function Client:escape(str)
    if not self.conn then
        error("client was not connected to the database, please use :connect() first")
    end
    return self.conn:escape(str)
end

--- Escapes a string for use as an SQL identifier, such as a table, column, or function name
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQESCAPEIDENTIFIER
---@return string
function Client:escapeIdentifier(str)
    if not self.conn then
        error("client was not connected to the database, please use :connect() first")
    end
    return self.conn:escapeIdentifier(str)
end

--- Escapes binary data for use within an SQL command with the type `bytea`.
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQESCAPEBYTEACONN
---@return string
function Client:escapeBytea(str)
    if not self.conn then
        error("client was not connected to the database, please use :connect() first")
    end
    return self.conn:escapeBytea(str)
end

--- Converts a string representation of binary data into binary data — the reverse of `Client:escapeBytea(str)`.
---
--- https://www.postgresql.org/docs/16/libpq-exec.html#LIBPQ-PQUNESCAPEBYTEA
---@return string
function Client:unescapeBytea(str)
    if not self.conn then
        error("client was not connected to the database, please use :connect() first")
    end
    return self.conn:unescapeBytea(str)
end

--- Releases client back to the pool, only use after getting it from the pool
---@see PGPool.connect to acquire a client from the pool
---@param suppress boolean? if true, then Pool:onRelease won't be called
function Client:release(suppress)
    if self.acquired == false then
        error("client was not acquired, :release() was called multiple times or misused")
    end
    if not self.pool then
        error("client is not in the pool, :release() is misused")
    end

    local pool = self.pool
    self.acquired = false
    self.pool = nil

    ---@cast pool PGPool

    if not suppress then
        xpcall(function() return pool:onRelease(self) end, self.errorHandler)
    end

    pool:processQueue() -- after client was release, we need to process pool queue
end

--- This **event** function is called when NOTIFY message is received
---
--- You can set it to your own function to handle NOTIFY messages
---@param channel string
---@param payload string
---@param backendPID number
function Client:onNotify(channel, payload, backendPID)
end

--- This **event** function is called whenever an error occurs inside connect/query callback.
---
--- You can set it to your own function to handle errors.
--- By default this function calls `ErrorNoHaltWithStack`
---@param message string error message
function Client:onError(message)
    -- return used here to hide additional stack trace
    return ErrorNoHaltWithStack(message)
end

--- This **event** function is called whenever connection to the server is lost/closed.
---
--- You can set it to your own function to handle connection loss.
---@return boolean? return true if you want to retry last query
function Client:onEnd()
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
function module.Client(url)
    ---@class PGClient
    local client = setmetatable({
        url = url,
        connecting = false,
        queries = Queue.new(),
    }, Client)

    client.errorHandler = function(...) return client:onError(...) end

    return client
end

---@class PGTransactionContext
---@field client PGClient
local TransactionContext = {}

---@private
TransactionContext.__index = TransactionContext

---@async
---@param fn fun(callback: function)
---@return PGResult
local function async(fn)
    local co = coroutine.running()
    assert(co, "async function must be called inside coroutine")
    local ok, res
    fn(function(_ok, _res)
        if ok == nil then
            ok, res = _ok, _res
            coroutine.resume(co)
        end
    end)
    if ok == nil then
        coroutine.yield()
    end
    if not ok then
        error(res)
    end
    return res
end

--- Sends a query to the server
---@see PGClient.query
---@async
---@param query string
function TransactionContext:query(query)
    return async(function(callback)
        self.client:query(query, callback)
    end)
end

--- Sends a query with given parameters to the server
---@see PGClient.queryParams
---@async
---@param query string
---@param params PGAllowedParam[]
function TransactionContext:queryParams(query, params)
    return async(function(callback)
        self.client:queryParams(query, params, callback)
    end)
end

--- Sends a request to create prepared statement
---@see PGClient.prepare
---@async
---@param name string
---@param query string
function TransactionContext:prepare(name, query)
    return async(function(callback)
        self.client:prepare(name, query, callback)
    end)
end

--- Sends a request to execute prepared statement
---@see PGClient.queryPrepared
---@async
---@param name string
---@param params PGAllowedParam[]
function TransactionContext:queryPrepared(name, params)
    return async(function(callback)
        self.client:queryPrepared(name, params, callback)
    end)
end

--- Sends a request to describe prepared statement
---@see PGClient.describePrepared
---@async
---@param name string
function TransactionContext:describePrepared(name)
    return async(function(callback)
        self.client:describePrepared(name, callback)
    end)
end

--- Sends a request to describe portal
---@see PGClient.describePortal
---@async
---@param name string
function TransactionContext:describePortal(name)
    return async(function(callback)
        self.client:describePortal(name, callback)
    end)
end

---@package
---@param client PGClient
---@return PGTransactionContext
function TransactionContext.new(client)
    return setmetatable({
        client = client,
    }, TransactionContext)
end

---@class PGPool
---@field url string **readonly** connection url
---@field max number maximum number of clients in the pool (default: 10)
---@field threshold number threshold of waiting :connect(...) acquire functions to create a new client (default: 5)
---@field private clients PGClient[]
---@field private queue { push: fun(self, f: function), prepend: fun(self, f: function), pop: (fun(self): function), size: fun(self): number }
---@field private errorHandler function function that just calls self:onError(...)
local Pool = {}

---@private
Pool.__index = Pool

---@private
function Pool:__tostring()
    local client = self.clients[1] -- first client MUST BE ALWAYS PRESENT
    return string.format("PGPool<%s@%s:%d/%s (%d/%d clients)>",
        client:user(), client:host(), client:port(), client:db(), #self.clients, self.max)
end

---@private
---@return boolean
function Pool:acquireClient()
    if self.queue:size() == 0 then
        return true
    end

    for _, client in ipairs(self.clients) do
        if not client.acquired then
            -- first we must lock client
            client.acquired = true
            client.pool = self

            -- then if client is ready to use, just call callback immideatly
            if client:connected() then
                -- notify about acquired client
                xpcall(function() return self:onAcquire(client) end, client.errorHandler)

                -- call callback
                local callback = self.queue:pop()
                xpcall(callback, client.errorHandler, client)

                -- if client was not connected, begin connection process
                -- unless it's already connecting, then just wait until it will be connected
            elseif not client.connecting then
                client:connect(function(ok, err)
                    if ok then
                        client:release(true)
                        xpcall(function() return self:onConnect(client) end, client.errorHandler)
                        self:acquireClient()
                        return
                    end

                    self:onError("PGPool - failed to connect to the database: " .. err)

                    -- try to restart acquiring, maybe we can connect with another try
                    timer.Simple(5, function()
                        client:release(true)
                        self:acquireClient()
                    end)
                end)
            end

            return true
        end
    end
    return false
end

---@package
function Pool:processQueue()
    -- first find available client
    if self:acquireClient() then
        -- client was found, nothing to do
        return
    end

    -- if we haven't found available clients, and queue is too big, we need to create new client
    local clients = #self.clients
    local waiters = self.queue:size()
    local threshold = clients * self.threshold
    if clients < self.max and waiters > threshold then
        local client = module.Client(self.url)
        client.onError = function(client, message)
            return self:onError(message)
        end

        self.clients[clients + 1] = client
        self:acquireClient()
    end
end

--- Acquires a first available client from the pool,
--- or waits until any client will be available
---
--- If waiting queue exceeds the power of 2 of the number of clients,
--- new client will be created and connected
---
--- After you are done with client, you MUST release it with client:release()
--- ```lua
--- pool:connect(function(client)
---     client:query("select now()", function(ok, res)
---         client:release() -- DO NOT FORGET TO RELEASE CLIENT
---         -- ...
---     end)
--- end)
--- ```
---@see PGClient.release for releasing client after you are done with it
---@param callback fun(client: PGClient)
function Pool:connect(callback)
    self.queue:push(callback)
    self:processQueue()
end

--- Sends a query to the server
---@see PGClient.query
---@param query string
---@param callback PGQueryCallback
function Pool:query(query, callback)
    return self:connect(function(client)
        return client:query(query, function(...)
            client:release()
            return callback(...)
        end)
    end)
end

--- Sends a query with given parameters to the server
---@see PGClient.queryParams
---@param query string
---@param params PGAllowedParam[]
---@param callback PGQueryCallback
function Pool:queryParams(query, params, callback)
    return self:connect(function(client)
        return client:queryParams(query, params, function(...)
            client:release()
            return callback(...)
        end)
    end)
end

--- Sends a request to create prepared statement
---@see PGClient.prepare
---@param name string
---@param query string
---@param callback PGQueryCallback
function Pool:prepare(name, query, callback)
    return self:connect(function(client)
        return client:prepare(name, query, function(...)
            client:release()
            return callback(...)
        end)
    end)
end

--- Sends a request to execute prepared statement
---@see PGClient.queryPrepared
---@param name string
---@param params PGAllowedParam[]
---@param callback PGQueryCallback
function Pool:queryPrepared(name, params, callback)
    return self:connect(function(client)
        return client:queryPrepared(name, params, function(...)
            client:release()
            return callback(...)
        end)
    end)
end

--- Sends a request to describe prepared statement
---@see PGClient.describePrepared
---@param name string
---@param callback PGQueryCallback
function Pool:describePrepared(name, callback)
    return self:connect(function(client)
        return client:describePrepared(name, function(...)
            client:release()
            return callback(...)
        end)
    end)
end

--- Sends a request to describe portal
---@see PGClient.describePortal
---@param name string
---@param callback PGQueryCallback
function Pool:describePortal(name, callback)
    return self:connect(function(client)
        return client:describePortal(name, function(...)
            client:release()
            return callback(...)
        end)
    end)
end

---@async
---@param client PGClient
---@param callback fun(ctx: PGTransactionContext)
local function transactionThread(client, callback)
    xpcall(function()
        local ctx = TransactionContext.new(client)
        local ok = xpcall(function()
            ctx:query("BEGIN")
            callback(ctx)
            ctx:query("COMMIT")
        end, client.errorHandler)

        if not ok then
            ctx:query("ROLLBACK")
        end
    end, client.errorHandler)
    client:release()
end

--- Begins a transaction and runs callback with transaction context
---
--- at the end transaction will be commited,
--- if any error will be thrown, transaction will be rolled back
---
--- TransactionContext passed into callback has `query`, `queryParams`, `prepare`, `queryPrepared`, `describePrepared`, `describePortal` methods
--- ```lua
--- pool:transaction(function(ctx)
---     local oid = ctx:queryParams("INSERT INTO players (name, id) VALUES ($1, $2)", { "Player", 1234 }).oid
---     local data = ctx:queryParams("SELECT * FROM players WHERE OID = $1", { oid }).rows[1]
---     PrintTable(data)
--- end)
--- ```
---@see PGTransactionContext
---@param callback async fun(ctx: PGTransactionContext)
function Pool:transaction(callback)
    return self:connect(function(client)
        local co = coroutine.create(transactionThread)
        coroutine.resume(co, client, callback)
    end)
end

--- This **event** function is called whenever new client connection
--- was estabileshed.
--- You can run setup commands on a client.
--- ```lua
--- function pool:onConnect(client)
---     client:query("SET DATESTYLE = iso, mdy")
--- end
--- ```
---@param client PGClient client that was connected
function Pool:onConnect(client)
end

--- This **event** function is called whenever a client was acquired.
---@param client PGClient client that was acquired
function Pool:onAcquire(client)
end

--- This **event** function is called whenever an error occurs inside connect/query callback for client or pool.
---@param message string error message
---@param client PGClient? client that caused the error, or nil if error happened in pool
function Pool:onError(message, client)
    return ErrorNoHaltWithStack(message)
end

--- This **event** function is called whenever a client was released back to the pool.
---
--- Warning! This funct
---@param client PGClient client that was released
function Pool:onRelease(client)
end

--- Creates a new connection pool with given connection url,
--- then use :connect() to get available connection,
--- and then :release() to release it back to the pool
function module.Pool(url)
    ---@class PGPool
    local pool = setmetatable({
        url = url,
        clients = { module.Client(url) },
        queue = Queue.new(),
        max = 10,
        threshold = 5,
    }, Pool)

    pool.clients[1].onError = function(client, message)
        return pool:onError(message, client)
    end

    pool.errorHandler = function(...) return pool:onError(...) end

    return pool
end

return module
