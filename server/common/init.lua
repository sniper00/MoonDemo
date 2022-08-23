---降低require多个文件查找消耗,注意内部避免递归require

return {
    cmdcode = require("common.cmdcode"),
    database = require("common.database"),
    GameCfg = require("common.GameCfg"),
    GameDef = require("common.GameDef"),
    vector2 = require("common.vector2"),
    setup = require("common.setup"),
    protocol = require("common.protocol")
}
