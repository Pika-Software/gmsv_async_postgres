![gmsv_async_postgres](https://socialify.git.ci/Pika-Software/gmsv_async_postgres/image?custom_description=Async+PostgreSQL+binary+for+Garry%27s+Mod&description=1&font=Raleway&issues=1&language=1&name=1&pattern=Formal+Invitation&pulls=1&stargazers=1&theme=Auto)

Simple PostgreSQL connector module for Garry's Mod
using [libpq] with asynchronousity in mind.

Besides binary module you'll probably need to add [`async_postgres.lua`][lua module] to your project.

## Features
* Fully asynchronous, yet allows to wait for a query to finish
* Provides full simplified [libpq] interface
* Simple, robust, and efficient
* Flexible [lua module] which extends functionality
* [Type friendly][LuaLS] [lua module] with documentation

## Installation
1. Go to [releases](https://github.com/Pika-Software/gmsv_async_postgres/releases)
2. Download `async_postgres.lua` and `gmsv_async_postgres_xxx.dll` files
> [!NOTE]
> If you are unsure which binary to download, you can run this command inside the console of your server
> ```lua
> lua_run print("gmsv_async_postgres_" .. (system.IsWindows() and "win" or system.IsOSX() and "osx" or "linux") .. (jit.arch == "x64" and "64" or not system.IsLinux() and "32" or "") .. ".dll")
> ```
3. Put `gmsv_async_postgres_xxx.dll` inside the `garrysmod/lua/bin/` folder (if the folder does not exist, create it)
4. Put `async_postgres.lua` inside `garrysmod/lua/autorun/server/` or inside your project folder
5. Profit 🎉

## Caveats
* When `queryParams` is used and the parameter is `string`, then the string will be sent as bytes!<br>
    You'll need to convert numbers **explicitly** to the `number` type, otherwise
    PostgreSQL will interpret the parameter as a binary integer, and will return an error
    or unexpected results may happen.

* Result rows are returned as strings, you'll need to convert them to numbers if needed.
* You'll need to use `Client:unescapeBytea(...)` to convert bytea data to string from the result.

## Usage
`async_postgres.Client` usage example
```lua
-- Lua module will require the binary module automatically, and will provide Client and Pool classes
include("async_postgres.lua")

-- See https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING for connection string format
local client = async_postgres.Client("postgresql://postgres:postgres@localhost")

-- Do not forget to connect to the server
client:connect(function(ok, err)
    assert(ok, err)
    print("Connected to " .. client:host() .. ":" .. client:port())
end)

-- PostgreSQL can only process one query at a time,
-- but async_postgres.Client has an internal queue for queries
-- so you can queue up as many queries as you want
-- and they will be executed one by one when possible
--
-- For example, this query will be executed after the connection is established
client:query("select now()", function(ok, res)
    assert(ok, res)
    print("Current time is " .. res.rows[1].now)
end)

-- You can also pass parameters to the query without the need of using client:escape(...)
client:queryParams("select $1 as a, $2 as b", { 5, 10 }, function(ok, res)
    assert(ok, res)
    PrintTable(res.rows) -- will output [1] = { ["a"] = "5", ["b"] = "10" }
end)

client:prepare("test", "select $1 as value", function(ok, err)
    assert(ok, err)
end)

client:queryPrepared("test", { "foobar" }, function(ok, res)
    assert(ok, res)
    print("Value is: " .. res.rows[1].value) -- will output "Value is foobar"
end)

-- You can also wait for all queries to finish
while client:isBusy() do
    -- Will wait for the next query/reset to finish
    client:wait()
end

-- And :close() will close the connection to the server
client:close() -- passing true will wait for all queries to finish, but we did waiting in the loop above
```

`async_postgres.Pool` usage example
```lua
local pool = async_postgres.Pool("postgresql://postgres:postgres@localhost")

-- You can make the same queries as with Client
-- but with Pool you don't need to worry about connection
-- Pool will manage connections for you
pool:query("select now()", function(ok, res)
    assert(ok, res)
    print("Current time is " .. res.rows[1].now)
end)

-- With Pool you also can create transactions
-- callback will be called in coroutine with ctx
-- which has query methods that don't need callback
-- and will return results directly
pool:transaction(function(ctx)
    -- you can also use ctx.client for methods like :db() if you want

    local res = ctx:query("select now()")
    print("Time in transaction is: " .. res.rows[1].now)

    local res = ctx:query("select $1 as value", { "barfoo" })
    print("Value in transaction is: " .. res.rows[1].value) -- will output "Value in transaction is barfoo"

    -- If error happens in transaction, it will be rolled back
    error("welp something went wrong :p")

    -- if no error happens, transaction will be committed
end)

-- Or you can use :connect() to create your own transactions or for something else
-- :connect() will acquire the first available connected Client from the Pool
-- and you'll need to call client:release() when you're done
pool:connect(function(client)
    client:query("select now()", function(ok, res)
        client:release() -- don't forget to release the client!

        assert(ok, res)
        print("Current time is " .. res.rows[1].now)
    end)
end)
```

## Reference
### Enums
- `async_postgres.VERSION`: string, e.g., "1.0.0"
- `async_postgres.BRANCH`: string, e.g., "main"
- `async_postgres.URL`: string
- `async_postgres.PQ_VERSION`: number, e.g., 160004
- `async_postgres.LUA_API_VERSION`: number, e.g., 1
- `async_postgres.CONNECTION_OK`: number
- `async_postgres.CONNECTION_BAD`: number
- `async_postgres.PQTRANS_IDLE`: number
- `async_postgres.PQTRANS_ACTIVE`: number
- `async_postgres.PQTRANS_INTRANS`: number
- `async_postgres.PQTRANS_INERROR`: number
- `async_postgres.PQTRANS_UNKNOWN`: number
- `async_postgres.PQERRORS_TERSE`: number
- `async_postgres.PQERRORS_DEFAULT`: number
- `async_postgres.PQERRORS_VERBOSE`: number
- `async_postgres.PQERRORS_SQLSTATE`: number
- `async_postgres.PQSHOW_CONTEXT_NEVER`: number
- `async_postgres.PQSHOW_CONTEXT_ERRORS`: number
- `async_postgres.PQSHOW_CONTEXT_ALWAYS`: number

### `async_postgres.Client` Class
- `async_postgres.Client(conninfo)`: Creates a new client instance

#### Methods
- `Client:connect(callback)`: Connects to the database (or reconnects if was connected)
- `Client:reset(callback)`: Reconnects to the database
- `Client:query(query, callback)`: Sends a query to the server
- `Client:queryParams(query, params, callback)`: Sends a query with parameters to the server
- `Client:prepare(name, query, callback)`: Creates a prepared statement
- `Client:queryPrepared(name, params, callback)`: Executes a prepared statement
- `Client:describePrepared(name, callback)`: Describes a prepared statement
- `Client:describePortal(name, callback)`: Describes a portal
- `Client:close(wait)`: Closes the connection to the database
- `Client:pendingQueries()`: Returns the number of queued queries (excludes currently executing query)
- `Client:db()`: Returns the database name
- `Client:user()`: Returns the user name
- `Client:pass()`: Returns the password
- `Client:host()`: Returns the host name
- `Client:hostaddr()`: Returns the server IP address
- `Client:port()`: Returns the port
- `Client:transactionStatus()`: Returns the transaction status (see `PQTRANS` enums)
- `Client:parameterStatus(paramName)`: Looks up a current parameter setting
- `Client:protocolVersion()`: Interrogates the frontend/backend protocol being used
- `Client:serverVersion()`: Returns the server version as integer
- `Client:errorMessage()`: Returns the last error message
- `Client:backendPID()`: Returns the backend process ID
- `Client:sslInUse()`: Returns true if SSL is used
- `Client:sslAttribute(name)`: Returns SSL-related information
- `Client:encryptPassword(user, password, algorithm)`: Prepares the encrypted form of a password
- `Client:escape(str)`: Escapes a string for use within an SQL command
- `Client:escapeIdentifier(str)`: Escapes a string for use as an SQL identifier
- `Client:escapeBytea(str)`: Escapes binary data for use within an SQL command
- `Client:unescapeBytea(str)`: Converts an escaped bytea data into binary data
- `Client:release(suppress)`: Releases the client back to the pool

#### Events
- `Client:onNotify(channel, payload, backendPID)`: Called when a NOTIFY message is received
- `Client:onNotice(message, errdata)`: Called when the server sends a notice/warning message during a query
- `Client:onError(message)`: Called whenever an error occurs inside connect/query callback
- `Client:onEnd()`: Called whenever connection to the server is lost/closed

### `async_postgres.Pool` Class
- `async_postgres.Pool(conninfo)`: Creates a new pool instance

#### Methods
- `Pool:connect(callback)`: Acquires a client from the pool
- `Pool:query(query, callback)`: Sends a query to the server
- `Pool:queryParams(query, params, callback)`: Sends a query with parameters to the server
- `Pool:prepare(name, query, callback)`: Creates a prepared statement
- `Pool:queryPrepared(name, params, callback)`: Executes a prepared statement
- `Pool:describePrepared(name, callback)`: Describes a prepared statement
- `Pool:describePortal(name, callback)`: Describes a portal
- `Pool:transaction(callback)`: Begins a transaction and runs the callback with a transaction context

#### Events
- `Pool:onConnect(client)`: Called when a new client connection is established
- `Pool:onAcquire(client)`: Called when a client is acquired
- `Pool:onError(message, client)`: Called when an error occurs
- `Pool:onRelease(client)`: Called when a client is released back to the pool

### I need more documentation!
Please check [`async_postgres.lua`][lua module] for full interface documentation.

And you also can check [libpq documentation][libpq] for more information on method behavior.

## Credit
* [goobie-mysql](https://github.com/Srlion/goobie-mysql) for inspiring with many good ideas
* @unknown-gd for being a good friend


[libpq]: https://www.postgresql.org/docs/16/libpq.html
[lua module]: ./async_postgres.lua
[LuaLS]: https://luals.github.io/
