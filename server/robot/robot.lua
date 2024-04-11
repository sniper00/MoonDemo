local moon = require("moon")
local socket = require("moon.socket")
local common = require("common")

local protocol = common.protocol_pb
local MSGID = common.CmdCode
local vector2 = common.vector2
local GameCfg = common.GameCfg

local conf = ...

local function read( fd )
    local data,err = socket.read(fd, 2)
    if not data then
        return false, err
    end
    local len = string.unpack(">H",data)
    data,err = socket.read(fd, len)
    if not data then
        return false, err
    end
    local name, t, id = protocol.decodestring(data)
    if id  == MSGID.S2CErrorCode then
        moon.error(print_r(t, true))
    end
    return name, t
end

local function send(fd, msgId, msg)
    local data = protocol.encodestring(msgId, msg)
    local len = #data
    return socket.write(fd, string.pack(">H",len)..data)
end

---@class Client
---@field fd integer
---@field expect_state table
---@field ok boolean
local Client = {}

function Client.new(host, port, name)
    local client = {
        fd = assert(socket.connect(host, port, moon.PTYPE_SOCKET_TCP)),
        expect_state = nil,
        ok = true
    }

    moon.async(function ()
        while true do
            local cmd,data = read(client.fd)
            if not cmd then
                print("socket error", data)
                client.ok = false
                return
            end
            local isfind = false
            local res
            if client.expect_state and (cmd == client.expect_state.cmd or cmd == "S2CErrorCode")then
                local fn = client.expect_state.fn
                isfind = true
                if fn then
                    isfind, res = fn(data)
                    if res then
                        data = res
                    end
                end
            end

            if isfind then
                local co = client.expect_state.co
                client.expect_state = nil
                if cmd == "S2CErrorCode" then
                    local ok, err = coroutine.resume(co, false, data)
                    if not ok then
                        error(err)
                    end
                else
                    local ok, err = coroutine.resume(co, data)
                    if not ok then
                        error(err)
                    end
                end
            else
                --print("recv:", cmd, print_r(data, true))
                if cmd == "S2CDead" then
                    print("ROBOT DEAD: ", name)
                    client.ok = false
                    return
                elseif cmd == "S2CGameOver" then
                    print("GAME OVER: ", name)
                    client.ok = false
                    return
                end
            end
        end
    end)

    return setmetatable(client, {__index = Client})
end

---阻塞等待指定消息返回
---@param self Client
---@param cmd string
---@param fn? function
---@return any
function Client.Expect(self, cmd, fn)
    assert(self.ok)
    self.expect_state = {cmd = cmd, fn = fn, co = coroutine.running()}
    return coroutine.yield()
end

---comment 发送消息
---@param self Client
---@param msgId any
---@param msg any
---@return boolean
function Client.Send(self, msgId, msg)
    if not self.ok then
        return false
    end
    send(self.fd, msgId, msg)
    return true
end

---comment 发送消息并等待返回
---@param self Client
---@param sendMsgId any
---@param sendMsg any
---@param recvMsgName any
---@return any
function Client.Call(self, sendMsgId, sendMsg, recvMsgName)
    assert(self.ok)
    send(self.fd, sendMsgId, sendMsg)
    return self:Expect(recvMsgName)
end


--游戏逻辑流程
local function client_handler(uname)

    local client = Client.new(conf.host, conf.port, uname)

    ---auth message
    local S2CLogin, err = client:Call(MSGID.C2SLogin, {openid = uname}, "S2CLogin")
    assert(S2CLogin.ok, "S2CLogin failed")

    ---@type S2CMailList
    local S2CMailList = client:Call(MSGID.C2SMailList, {}, "S2CMailList")
    print_r(S2CMailList)
    for key, value in pairs(S2CMailList.mail_list) do
        client:Send(MSGID.C2SMailReward, {mail_id_list = {value.id}})
        client:Send(MSGID.C2SMailDel, {mail_id_list = {value.id}})
    end

    --请求匹配
    local S2CMatch, S2CErrorCode = client:Call(MSGID.C2SMatch, {openid = uname}, "S2CMatch")
    assert(S2CMatch.res, "S2CMatch failed")

    --等待匹配成功
    local S2CMatchSuccess, S2CErrorCode = client:Expect("S2CMatchSuccess")

    local S2CEnterRoom, S2CErrorCode = client:Call(MSGID.C2SEnterRoom, {name = uname}, "S2CEnterRoom")

    print("robot", uname ," enter room success")




    --进入房间成功后，模拟随机移动
    local exit = false
    moon.async(function()
        while true do
            moon.sleep(3000)
            if exit then
                break
            end
            local dir = {x = math.random(-10, 10), y = math.random(-10, 10)}
            vector2.normalize(dir)

            if not client:Send(MSGID.C2SMove, dir) then
                return
            end
            --print("C2SMove", uname, dir.x, dir.y)
        end
    end)
end

moon.dispatch("lua", function()
    moon.warn("ignore")
end)

moon.async(function()
    GameCfg.Load()

    moon.sleep(10)
    local username = 0

    local create_user
    create_user = function (un)
        if not un then
            username = username + 1
            un = username
        end

        moon.async(function ()
            print(xpcall(client_handler, debug.traceback, "robot"..tostring(un)))
            moon.sleep(20)
            --create_user(un)
        end)
    end

    moon.sleep(3000)
    for _=1, GameCfg.constant.robot_num do
        create_user()
        moon.sleep(10)
    end
end)



