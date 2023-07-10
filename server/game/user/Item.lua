local moon = require "moon"
local common = require "common"
local GameCfg = common.GameCfg
local ErrorCode = common.ErrorCode
local CmdCode = common.CmdCode

---@type user_context
local context = ...
local scripts = context.scripts

---@class Item
local Item = {}

function Item.Init()
    local data = scripts.UserModel.Get()
    if not data.itemlist then
        data.itemlist = {}
    end
end

function Item.Start()
    -- body
end

--检查物品数量是否足够
function Item.Check(id, count)
    if count <=0 then
        return ErrorCode.ParamInvalid
    end
    local DB = scripts.UserModel.Get()
    local item = DB.itemlist[id]
    if not item or item.count < count  then
        return ErrorCode.ItemNotEnough
    end
    return 0
end


function Item.Cost(id, count, trace, send_list)
    if count <=0 then
        return ErrorCode.ParamInvalid
    end

    local DB = scripts.UserModel.MutGet()

    local item = DB.itemlist[id]

    if not item or item.count < count  then
        return ErrorCode.ItemNotEnough
    end
    item.count = item.count - count

    if not send_list then
        context.S2C(CmdCode.S2CUpdateItem,{list={item}})
    else
        table.insert(send_list, item)
    end
end

function Item.Costlist(list, trace)
    local DB = scripts.UserModel.MutGet()
    for _, v in ipairs(list) do
        local item = DB.itemlist[v[1]]
        if not item or item.count < v[2]  then
            return ErrorCode.ItemNotEnough
        end
    end

    local send_list = {}
    for _, v in ipairs(list) do
        Item.Cost(v[1], v[2], trace, send_list)
    end
    context.S2C(CmdCode.S2CUpdateItem,{list= send_list})
end

function Item.AddItemList(list, trace)
    local send_list = {}
    for _,v in ipairs(list) do
        Item.AddItem(v.id, v.count, trace, send_list)
    end
    if #send_list > 0 then
        context.S2C(CmdCode.S2CUpdateItem,{list=send_list})
    end
end

function Item.AddItem(id, count, trace, send_list)
    print("AddItem", id, count, trace)

    local cfg = GameCfg.item[id]
    if not cfg then
        moon.error("item not exist", id)
        return ErrorCode.ItemNotExist
    end

    local DB = scripts.UserModel.MutGet()

    local item = DB.itemlist[id]
    if not item then
        item = {count = 0}
        DB.itemlist[id] = item
    end
    item.id = id
    item.count = item.count + count

    if not send_list then
        context.S2C(CmdCode.S2CUpdateItem,{list={item}})
    else
        table.insert(send_list, item)
    end
    return ErrorCode.None
end

function Item.C2SItemList()
    context.S2C(CmdCode.S2CItemList, {list = scripts.UserModel.Get().itemlist})
end

---@param req C2SUseItem
function Item.C2SUseItem(req)
    local cfg = GameCfg.item[req.id]
    if not cfg then
        return ErrorCode.ItemNotExist
    end
end

return Item