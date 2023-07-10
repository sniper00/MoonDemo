
---@enum ErrorCode
local ErrorCode = {
    None = 0,
    ServerInternalError = 1,
    ParamInvalid = 2,
    ConfigError =3,
    OperationNotPermit = 4,

    ---没有这个装备
    EquipNotFound = 101,
    ---这个部位没有装备
    EquipSlotEmpty = 102,
    ---无效的装备槽位
    EquipInvalidSlot = 103,
    ---分解不存在的装备或者穿戴中的装备
    EquipInvalidDecompose = 104,

    ---正在战斗中
    FightAlreadyStart = 201,

    ---道具不足
    ItemNotEnough = 301,
    ---道具不存在
    ItemNotExist = 302,

    ---宝物相关错误码
    ---没有拥有该宝物
    TreasureNotFound = 401,
    ---宝物CD中
    TreasureInCD = 402,

    ---没有这个商品ID
    ShopItemNotExist = 501,

    ---商品已售
    ShopItemSoldOut = 502,

    ---兑换次数不够
    ExchangeNotEnough = 503,


    ---奖励已经领取过
    DailyTaskReceived = 701,
}

return ErrorCode