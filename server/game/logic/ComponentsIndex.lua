-- ID - Components 映射，方便处理网络消息

local Components = require('Components')

local M = {}

M[1] = Components.CommandUpdate
M[2] = Components.CommandRemove

--客户端发给服务器 详见MSGID.lua
M[0x0301] = Components.CommandCreate
M[0x0303] = Components.CommandMove

Components.CommandCreate._id = 0x0301
Components.CommandMove._id = 0x0303

Components.EnterView._id = 0x0304
Components.LeaveView._id = 0x0305

Components.Mover._id = 0x0306
Components.Food._id = 0x0307

Components.BaseData._id = 0x0308
Components.Position._id = 0x0309
Components.Direction._id = 0x0310
Components.Speed._id = 0x0311
Components.Color._id = 0x0312
Components.Radius._id = 0x0313

return M