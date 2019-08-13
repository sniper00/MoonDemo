local moon = require("moon")
local context = ...

local CMD = {}

--- called by gate. gate called by login server
function CMD.login(openid, uid, secret)
	-- you may use secret to make a encrypted data stream
	print("AGENT LOGIN:", openid,uid)
	context.openid = openid
	context.uid = uid
	-- you may load user data from database
	return true
end

function CMD.disconnect()
	-- todo: do something before exit
	CMD.logout()
end

function CMD.logout()
	print(string.format("AGENT: begin logout openid %s uid %s", tostring(context.openid), tostring(context.uid)))
	moon.co_call("lua", context.room, "LeaveRoom", context.uid)
	local res = moon.co_call("lua", context.gate, "logout", context.openid, context.uid)
	print(string.format("AGENT: end logout openid %s uid %s res:%s",
						tostring(context.openid),
						tostring(context.uid),
						res)
	)
    moon.quit()
end

return CMD