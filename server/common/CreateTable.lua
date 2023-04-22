local pgsql = require("sqldriver")

---@param res pg_result|pg_error
local function check_err(res)
    assert(not res.code, table.tostring(res))
end

return function (addr_db)
    local sql = string.format([[
        --create userdata table
        create table if not exists userdata (
            uid bigint PRIMARY KEY NOT NULL,
            data text
           );
    ]])
    check_err(pgsql.query(addr_db, sql))
end

