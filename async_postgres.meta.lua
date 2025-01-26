---@meta
--- Just a meta file for native async_postgres module

async_postgres = {}

async_postgres.VERSION = "1.0.0"
async_postgres.BRANCH = "main"
async_postgres.URL = "https://github.com/Pika-Software/gmsv_async_postgres"
async_postgres.PQ_VERSION = 160004
async_postgres.LUA_API_VERSION = 1

async_postgres.CONNECTION_OK = 0
async_postgres.CONNECTION_BAD = 1

async_postgres.PQTRANS_IDLE = 0
async_postgres.PQTRANS_ACTIVE = 1
async_postgres.PQTRANS_INTRANS = 2
async_postgres.PQTRANS_INERROR = 3
async_postgres.PQTRANS_UNKNOWN = 4

async_postgres.PQERRORS_TERSE = 0
async_postgres.PQERRORS_DEFAULT = 1
async_postgres.PQERRORS_VERBOSE = 2
async_postgres.PQERRORS_SQLSTATE = 3

async_postgres.PQSHOW_CONTEXT_NEVER = 0
async_postgres.PQSHOW_CONTEXT_ERRORS = 1
async_postgres.PQSHOW_CONTEXT_ALWAYS = 2

--- Creates connection to a PostgreSQL database with given connection string
--- see https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-CONNSTRING
---@param url string
---@return PGconn
function async_postgres.connect(url)
end

---@class PGconn : userdata
local PGconn = {}

function PGconn:query(query, callback)
end

function PGconn:queryParams(query, params, callback)
end

function PGconn:prepare(name, query, callback)
end

function PGconn:queryPrepared(name, params, callback)
end

function PGconn:describePrepared(name, callback)
end

function PGconn:describePortal(name, callback)
end

function PGconn:reset(callback)
end

function PGconn:wait()
end

function PGconn:isBusy()
end

function PGconn:querying()
end

function PGconn:resetting()
end

function PGconn:db()
end

function PGconn:host()
end

function PGconn:hostaddr()
end

function PGconn:port()
end

function PGconn:status()
end

function PGconn:transactionStatus()
end

function PGconn:parameterStatus()
end

function PGconn:protocolVersion()
end

function PGconn:serverVersion()
end

function PGconn:errorMessage()
end

function PGconn:backendPID()
end

function PGconn:sslInUse()
end

function PGconn:sslAttribute(name)
end

function PGconn:clientEncoding()
end

function PGconn:setClientEncoding(encoding)
end

function PGconn:encryptPassword(user, password, algorithm)
end

function PGconn:escape(str)
end

function PGconn:escapeIdentifier(str)
end

function PGconn:escapeBytea(str)
end

function PGconn:unescapeBytea(str)
end
