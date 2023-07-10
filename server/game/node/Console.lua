local moon = require("moon")
local json = require("json")
local fs = require("fs")
local datetime = require("moon.datetime")
local sharetable = require("sharetable")

---@type node_context
local context = ...

local NODEID = math.tointeger(moon.env("NODE"))
local THREAD_NUM = math.tointeger(moon.env("THREAD_NUM"))

local static_tables_md5 = {}

local function Response(code, message, data)
	return json.encode({ code = code, message = message, data = data })
end

local function ResponseV2(res, err)
	if res == false then
		return json.encode({ code = -1, message = err, data = err })
	end
	return json.encode({ code = 0, data = res })
end

---@class Console
local Console = {}

function Console.Init()
	static_tables_md5 = Console.table_md5()
	return true
end

local help = [[
param '<>' means require
param '()' means optional

Gloabl command format:S<nodeid> command params. e. S1 help
Command List:
	tstate:                            Get worker thread state.
	list:                              List all services.
	quit <address>:                    Force close the specificed service.
	time:                              Print current server's time.
	adjtime <seconds>:                 Forward adjust server time in seconds.
	settime <Y-M-D H:M:S>:             Forward set server time.
	next_hour:                         Forward adjust server time to next hour.
	loglevel <LEVEL>:                  Set log level 'DEBUG','INFO','WARN','ERROR'.
	gc:                                Let all services run gc.
	state:                             List all services's state.
	mem:                               List all services's lua memory.
	ping <address> :                   Ping the specificed service.
	reload:                            Reload static table files.
	hotfix <servicename> <filename_no_path_no_ext_1> <filename_no_path_no_ext_2>....: Hotfix script file. e. S1 hotfix user Hello

User command format:     U<uid> command params
Command List:
	addscore <count> #增加积分. U1234567 addscore 999 给玩家1234567增加999积分
]]

function Console.help()
	return help
end

---热更某个服务目录下的脚本
function Console.hotfix(sname, ...)
	local modlist = { ... }
	if #modlist == 0 then
		return string.format("server %d hotfix failed, empty file list", NODEID)
	end

	local fixlist = {}
	for _, modname in ipairs(modlist) do
		local filepath = string.format("game/%s/%s.lua", sname, modname)
		local content, err = io.readfile(filepath)
		if not content then
			return string.format("server %d hotfix %s failed, %s", NODEID, filepath, tostring(err))
		end
		fixlist[modname] = filepath
		moon.env(filepath, content)
	end

	if sname == "user" then
		moon.send("lua", moon.queryservice("auth"), "hotfix", fixlist)
	else
		moon.send("lua", moon.queryservice(sname), "hotfix", fixlist)
	end
	return Response(0, "OK", modlist)
end

function Console.table_md5()
	local res = {}
	local list = fs.listdir("static/table")
	for _, file in ipairs(list) do
		if not fs.isdir(file) then
			local name = fs.stem(file)
			local md5str = moon.md5(io.readfile(file))
			res[name] = md5str
		end
	end
	return res
end

---更新配表,新表覆盖旧表后,执行这个命令
function Console.reload(...)
	local names = { ... }
	if #names == 0 then
		local tmp = Console.table_md5()
		for name, md5 in pairs(static_tables_md5) do
			local newmd5 = tmp[name]
			if md5 ~= newmd5 then
				table.insert(names, name)
			end
		end
		static_tables_md5 = tmp
	end

	local res = {}
	if #names > 0 then
		local all_ok = true
		for k, name in ipairs(names) do
			local filename = name .. ".lua"
			names[k] = filename
			local ok, err = sharetable.loadfile(filename)
			if ok then
				table.insert(res, string.format("%s(success)", name))
			else
				table.insert(res, string.format("%s(failed,%s)", name, tostring(err)))
				all_ok = false
				break
			end
		end

		if all_ok then
			local clients = sharetable.clients()
			for _, v in ipairs(clients) do
				moon.send("lua", v, "reload", names)
			end
		end
	end
	return string.format("server %d reload (count %d): %s", NODEID, #res, table.concat(res, " "))
end

local last_tstate_time = moon.clock()
function Console.tstate()
	local info = moon.server_stats()
	local t = json.decode(info)
	local res = {}
	for i, one in ipairs(t) do
		if one.id > 0 then
			local cpu = 100 * (one.cpu / (moon.clock() - last_tstate_time))
			one.cpu = string.format("%.02f", cpu)
		end
		res[#res + 1] = json.encode(one) .. "\n"
	end
	last_tstate_time = moon.clock()
	return table.concat(res)
end

function Console.queryservice(name)
	return string.format("%08X", moon.queryservice(name))
end

function Console.list()
	local num = THREAD_NUM
	local response = {}
	for i = 1, num do
		local s = json.decode(moon.scan_services(i))
		if s then
			for _, v in pairs(s) do
				table.insert(response, json.encode(v))
			end
		end
	end
	return table.concat(response, "\n")
end

function Console.quit(address)
	address = tonumber(address, 16)
	moon.kill(address)
	return true
end

function Console.time()
	return os.date("%Y-%m-%d %H:%M:%S", moon.time())
end

function Console.adjtime(offset)
	offset = math.tointeger(offset)
	if not offset or offset <= 0 then
		return "failed"
	end

	if moon.adjtime(offset * 1000) then
		return "ok"
	else
		return false, "failed: time can not rollback " .. offset
	end
end

function Console.settime(YMD, HMS)
	local strtime = YMD .. " " .. HMS
	local tm = datetime.parse(strtime)
	local t = os.time(tm)
	local now = moon.time()
	local delta = t - now
	if moon.adjtime(delta * 1000) then
		return "ok"
	else
		return false, "failed: time can not rollback " .. strtime
	end
end

function Console.next_hour()
	local diff = 3600000 - moon.now() % 3600000
	moon.adjtime(diff)
	return tostring(diff)
end

function Console.loglevel(lv)
	moon.loglevel(lv)
	return lv
end

function Console.gc(addr)
	if addr then
		local res, err = moon.call("debug", tonumber(addr, 16), "gc")
		if not res then
			return string.format("error(%s)", tostring(err))
		else
			return string.format("%s Kb", tostring(res))
		end
	else
		local num = THREAD_NUM
		local total = 0
		for i = 1, num do
			local services = json.decode(moon.scan_services(i))
			if services then
				for _, s in pairs(services) do
					local res, err = moon.call("debug", tonumber(s.serviceid, 16), "gc")
					if not res then
						print("error: ", err)
					else
						total = total + res
					end
				end
			end
		end
		return string.format("%.2f Kb", total)
	end
end

function Console.state(addr)
	if addr then
		local state, err = moon.call("debug", tonumber(addr, 16), "state")
		if not state then
			return string.format("error(%s)", err)
		else
			return state
		end
	else
		local num = THREAD_NUM
		local res = {}
		for i = 1, num do
			local services = json.decode(moon.scan_services(i))
			if services then
				for _, s in ipairs(services) do
					local state, err = moon.call("debug", tonumber(s.serviceid, 16), "state")
					if not state then
						s.state = string.format("error(%s)", err)
					else
						s.state = state
					end
					table.insert(res, json.encode(s))
				end
			end
		end
		return table.concat(res, "\n")
	end
end

function Console.mem(addr)
	if addr then
		local kb, err = moon.call("debug", tonumber(addr, 16), "mem")
		if not kb then
			return string.format("err (%s)", err)
		else
			return string.format("%.2f Kb", kb)
		end
	else
		local num = THREAD_NUM
		local res = {}
		for i = 1, num do
			local services = json.decode(moon.scan_services(i))
			if services then
				for _, s in pairs(services) do
					local kb, err = moon.call("debug", tonumber(s.serviceid, 16), "mem")
					if not kb then
						s.mem = string.format("err (%s)", err)
					else
						s.mem = string.format("%.2f Kb", kb)
					end
					table.insert(res, json.encode(s))
				end
			end
		end
		return table.concat(res, "\n")
	end
end

function Console.addscore(uid, count)
	local ok, err = context.call_user(uid, "User.AddScore", count)
	if not ok then
		return Response(-1, "Failed", err)
	end
	return Response(0, "OK")
end

function Console.addmail(uid, mail_key)
	local ok, err = moon.call("lua", context.addr_mail, "Mail.AddMail", uid, {
		mail_key = mail_key,
		flag = 0,
		rewards = {
			{id = 10001, count = 1},
			{id = 10002, count = 2},
		},
	})
	return ResponseV2(ok, err)
end

return Console
