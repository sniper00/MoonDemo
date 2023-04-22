---降低require多个文件查找消耗,注意内部避免递归require

return {
    vector2 = require("common.vector2"),
    setup = require("common.setup"),
    protocol = require("common.protocol"),
    protocol_pb = require("common.protocol_pb"),

    CmdCode = require("common.CmdCode"),
    Database = require("common.Database"),
    GameCfg = require("common.GameCfg"),
    GameDef = require("common.GameDef"),
    ErrorCode = require("common.ErrorCode"),
    CreateTable = require("common.CreateTable")
}
