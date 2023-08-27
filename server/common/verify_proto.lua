--- 由于lua是脚本语言,灵活性较强。用于开发环境中, 运行时严格验证游戏内的数据结构。

print('Deprecated, use require("schema") instead.')

local moon = require("moon")
local json = require("json")

local protos

if moon.DEBUG() then
	local content = io.readfile([[./protocol/json_verify.json]])
	if content then
		protos = json.decode(content)
	end
end

local type_check = {}

type_check["int32"] = function(v) return type(v) == "number" and math.tointeger(v) end
type_check["uint32"] = type_check["int32"]
type_check["int64"] = type_check["int32"]
type_check["uint64"] = type_check["int32"]
type_check["sint32"] = type_check["int32"]
type_check["sint64"] = type_check["int32"]
type_check["fixed32"] = type_check["int32"]
type_check["fixed64"] = type_check["int32"]
type_check["sfixed32"] = type_check["int32"]
type_check["sfixed64"] = type_check["int32"]
type_check["bool"] = function(v) return type(v) == "boolean" end
type_check["float"] = function(v) return type(v) == "number" end
type_check["double"] = function(v) return type(v) == "number" end
type_check["string"] = function(v) return type(v) == "string" end
type_check["bytes"] = function(v) return type(v) == "string" end

local function is_array(t)
	local size = #t
	if size == 0 then
		return true
	end

	for k,v in next,t do
		if type(k) == "number" then
			if k<0 or k > size then
				return false
			end
		else
			return false
		end
	end
	return true
end

local function verify_proto(proto_name, data, trace)
	if not protos or not moon.DEBUG() then
		return
	end

	if not trace then
		trace = {}
		trace[#trace+1] = proto_name
	end
	assert(type(data)=="table", string.format("proto type %s data need table, got %s. trace: %s", proto_name, type(data), table.concat(trace,".")))
	local proto = protos[proto_name]
	assert(proto, string.format("undefined proto: %s. trace: %s", proto_name, table.concat(trace,".")))
	for key , value in pairs(data) do
		local field = proto[key]
		if not field then
			assert(field, string.format("attemp use unknown field : %s.%s . trace: %s %s", proto_name, key, table.concat(trace,"."), tostring(value)))
		else
			if field.container == "array" then
				assert(type(value) == "table", string.format("%s.%s need table, got %s. trace: %s", proto_name, key, type(value), table.concat(trace,".")))
				assert(is_array(value), string.format("%s.%s need array, got hash. trace: %s", proto_name, key, table.concat(trace,".")))
				for _, item_value in ipairs(value) do
					local fn = type_check[field.value_type]
					if not fn then
						trace[#trace+1] = string.format("%s[%d]", key,  _)
						if string.match(field.value_type, "[array|map]_(.*)") then
							verify_proto(field.value_type, {data = item_value}, trace)
						else
							verify_proto(field.value_type, item_value, trace)
						end
						table.remove(trace)
					else
						assert(fn(item_value),string.format("%s.%s[%d] need %s. trace: %s", proto_name, key,  _, field.value_type, table.concat(trace,".")))
					end
				end
			elseif field.container == "object" then
				assert(type(value) == "table", string.format("%s.%s need table, got %s. trace: %s", proto_name, key, type(value), table.concat(trace,".")))
				for key_value, item_value in pairs(value) do
					local fn = type_check[field.key_type]
					if not fn then
						verify_proto(field.key_type, key_value)
					else
						assert(fn(key_value),string.format("%s[%s] %s: %s", proto_name, key, field.key_type, tostring(key_value)))
					end

					fn = type_check[field.value_type]
					if not fn then
						trace[#trace+1] = string.format("%s[%s]", key, tostring(key_value))
						if string.match(field.value_type, "[array|map]_(.*)") then
							verify_proto(field.value_type, {data = item_value}, trace)
						else
							verify_proto(field.value_type, item_value, trace)
						end
						table.remove(trace)
					else
						assert(fn(item_value),string.format("%s.%s[%s] need %s. trace: %s", proto_name, key, tostring(key_value), field.value_type, table.concat(trace,".")))
					end
				end
			else
				local fn = type_check[field.value_type]
				if not fn then
					trace[#trace+1] = key
					verify_proto(field.value_type, value, trace)
					table.remove(trace)
				else
					assert(fn(value),string.format("%s.%s need %s. trace: %s", proto_name, key, field.value_type, table.concat(trace,".")))
				end
			end
		end
	end
end

return verify_proto
