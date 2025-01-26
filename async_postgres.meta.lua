---@meta
--- Just meta file for native async_postgres module

async_postgres = {}

async_postgres.VERSION = "1.0.0"
async_postgres.BRANCH = "main"
async_postgres.URL = "https://github.com/Pika-Software/gmsv_async_postgres"
async_postgres.PQ_VERSION = 160004
async_postgres.LUA_API_VERSION = 1


--- Creates connection to a PostgreSQL database with given connection string
--- see https://www.postgresql.org/docs/16/libpq-connect.html#LIBPQ-CONNSTRING
---@param url string
---@return PGconn
function async_postgres.connect(url)
end

---@class PGconn
local PGconn = {}
