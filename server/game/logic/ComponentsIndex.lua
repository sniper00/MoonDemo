-- ID - Components 映射，方便处理网络消息

local Components = require('Components')

local M = {}

M[1] = Components.CommandUpdate
M[2] = Components.CommandRemove

--客户端发给服务器 详见MSGID.lua
M[0x0301] = Components.CommandCreate
M[0x0305] = Components.CommandMove

return M