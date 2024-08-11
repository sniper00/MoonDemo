local moon = require("moon")
local uuid = require("uuid")
local json = require("json")
local task = require("moon.task")
local socket = require("moon.socket")
local clusterd = require("cluster")
local httpserver = require("moon.http.server")

local node_list = {}

local function split_cmdline(cmdline)
    local split = {}
    for i in string.gmatch(cmdline, "%S+") do
        table.insert(split,i)
    end
    return split
end

local function format_table(t)
    local index = {}
    for k in pairs(t) do
        table.insert(index, k)
    end
    table.sort(index, function(a, b)
        a = tostring(a)
        b = tostring(b)
        if #a==#b then
            return a<b
        end
        return #a<#b
    end)
    local result = {}
    for _,v in ipairs(index) do
        table.insert(result, string.format("%s:%s",v,tostring(t[v])))
    end
    return table.concat(result,"\t")
end

local function dump_line(print, key, value)
    if type(value) == "table" then
        print(key, format_table(value))
    else
        print(key, tostring(value))
    end
end

local function dump_list(print, list)
    local index = {}
    for k in pairs(list) do
        table.insert(index, k)
    end
    table.sort(index, function(a, b)
        a = tostring(a)
        b = tostring(b)
        if #a==#b then
            return a<b
        end
        return #a<#b
    end)
    for _,v in ipairs(index) do
        dump_line(print, v, list[v])
    end
end

local function handle_one(split, to_serverid, echo)
    split[2] = "Console."..split[2]
    local res, err = clusterd.call(to_serverid, "node", table.unpack(split, 2))
    if echo then
        if res then
            if type(res) == "table" then
                dump_list(echo, res)
            else
                echo(tostring(res))
            end
            echo("<CMD OK>")
        else
            echo(err)
            echo("<CMD Error>")
        end
    else
        return res, err
    end
end

local function command_handler(cmdline, echo)
    cmdline = string.trim(cmdline)
    if cmdline ~= "" then
        local split = split_cmdline(cmdline)
        local flag = string.sub(split[1],1,1)
        if flag~="S" and flag ~= "U" and flag ~= 'T' then
            echo("Error console command: "..cmdline)
            return
        end

        for k,v in ipairs(split) do
            split[k] = math.tointeger(v) or v
        end

        local serverid = -1
        if flag == "S" then--server
            serverid = math.tointeger(string.sub(split[1],2))
        elseif flag =="U" then--user gm
            local uid = math.tointeger(string.sub(split[1],2))
            if uuid.isuid(uid) then
                serverid = uuid.serverid(uid)
                table.insert(split, 3, uid)
            end
        elseif flag == "T" then
            local typename = string.sub(split[1],2)
            local tasklist = {}
            local res = {
                code = 0,
                data = {}
            }
            for k, v in pairs(node_list) do
                if v.type == typename then
                    table.insert(tasklist, function()
                        local t,err = handle_one(split, k)
                        if t then
                            local first = string.byte(t, 1, 1)
                            if first == 91 or first == 123 then-- '{', '}'
                                res.data[k] = json.encode(t)
                            else
                                res.data[k] = t
                            end
                        else
                            res.data[k] = err
                        end
                    end)
                end
            end
            task.wait_all(tasklist)
            echo(json.encode(res))
            echo("<CMD OK>")
            return
        end

        if not serverid or serverid < 0 then
            echo("Error console command, get serverid from uid failed: "..cmdline)
            echo("<CMD Error>")
            return
        end

        if serverid > 0 then
            handle_one(split, serverid, echo)
        else
            local results = {}
            for i in pairs(node_list) do
                local res, err = handle_one(split, i)
                if res then
                    results[i] = res
                else
                    results[i] = err
                end
            end
            dump_list(echo, results)
            echo("<CMD Done>")
        end
        return
    end
end

httpserver.content_max_len = 8192

httpserver.on("/console",function(request, response)
    local command = string.trim(request.body)
    if request.headers["content-type"] == "application/json" then
        command = json.decode(command).command
    end

    local res = {}
    local Code = 200
    command_handler(command, function(...)
        local t = { ... }
        if #t==1 then
            local t1 = tostring(t[1])
            if #t1>0 and t1:sub(1,1) =='<' then
                if t1 == "<CMD Error>" then
                    Code  = 400
                    return
                end
                if t1 == "<CMD OK>" or t1 == "<CMD Done>" then
                    return
                end
            end
        end
        for k,v in ipairs(t) do
            t[k] = tostring(v)
        end
        table.insert(res,table.concat(t,"\t"))
        table.insert(res, "\r\n")
    end)

    if Code == 400 then
        response.status_code = Code
        response:write_header("Content-Type","application/text")
        response:write(table.concat(res,""))
        moon.error(request.body, table.concat(res,""))
    else
        response.status_code = Code
        local content = table.concat(res,"")
        local isjson = false
        if #content>0 then
            local first = string.byte(content, 1,1)
            --'[' or '}'
            if first==91 or first ==123 then
                isjson = true
            end
        end
        if isjson then
            response:write_header("Content-Type","application/json")
        else
            response:write_header("Content-Type","application/text")
        end
        response:write(table.concat(res,""))
    end
end)

httpserver.on("/conf.updatenode",function(request, response)
    local i = 1
    while true do
        local addr = moon.queryservice("hub"..i)
        if addr > 0 then
            moon.send("lua", addr, "loadnode")
        else
            break
        end
        i = i + 1
    end

    response.status_code = 200
    response:write_header("Content-Type","text/plain")
    response:write("OK")
end)

httpserver.on("/conf.node",function(request, response)
    local query = request:parse_query()
    local node = tonumber(query.node)
    local cfg = node_list[node]
    if not cfg then
        response.status_code = 404
        response:write_header("Content-Type","text/plain")
        response:write("not found")
        return
    end
    response.status_code = 200
    response:write_header("Content-Type","application/json")
    response:write(json.encode(cfg))
end)

httpserver.on("/conf.cluster", function(request, response)
    local query = request:parse_query()
    local node = tonumber(query.node)
    local cfg = node_list[node]
    if not cfg or not cfg.cluster then
        response.status_code = 404
        response:write_header("Content-Type","text/plain")
        response:write("cluster node not found "..tostring(query.node))
        return
    end
    response.status_code = 200
    response:write_header("Content-Type","application/json")
    response:write(json.encode({host = cfg.cluster.host, port = cfg.cluster.port}))
end)

httpserver.static("static/www")

local command = {}

function command.start(fd, timeout)

    local function echo(...)
        local t = { ... }
        for k,v in ipairs(t) do
            t[k] = tostring(v)
        end
        socket.write(fd, table.concat(t,"\t"))
        socket.write(fd, "\r\n")
    end

    while true do
        local cmdline = socket.read(fd, "\n")
        if not cmdline then
            break
        end

        if cmdline:sub(1,4) == "GET " or cmdline:sub(1,4) == "POST" then
            httpserver.start(fd, timeout, cmdline.."\n")
            break
        end
        command_handler(cmdline, echo)
    end
end

function command.loadnode()
    node_list = {}
    local configname = moon.env("NODE_FILE_NAME")
    local res = json.decode(io.readfile(configname))
    for _,v in ipairs(res) do
        local host, port = v.host:match("([^:]+):?(%d*)$")
        port = math.tointeger(port) or 80
        v.host = host
        v.port = port

        if v.cluster then
            host, port = v.cluster:match("([^:]+):?(%d*)$")
            port = math.tointeger(port) or 80
            v.cluster = {
                host = host,
                port = port
            }
        end
        node_list[v.node] = v
    end
    print("loadnode")
end

local function xpcall_ret(ok, ...)
    if ok then
        return moon.pack(...)
    end
    return moon.pack(false, ...)
end

moon.dispatch("lua", function(sender, session, cmd, ...)
    ---@cast sender integer

    local fn = command[cmd]
    if fn then
        if session ~= 0 then
            moon.raw_send("lua", sender, xpcall_ret(xpcall(fn, debug.traceback, ...)), session)
        else
            fn(...)
        end
    else
        moon.error(moon.name, "recv unknown cmd "..tostring(cmd))
    end
end)

moon.shutdown(function()
    moon.quit()
end)