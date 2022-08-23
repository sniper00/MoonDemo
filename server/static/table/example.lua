---@class example_cfg
---@field public id integer @序列号
---@field public name string @名字
---@field public rate integer @概率(万分比)
---@field public cost integer[] @等级消耗,数组类型
---@field public open boolean @是否开启
---@field public srcpath string @资源路径
---@field public values table @属性
---@field public map table @字典

local M = {
	[3] = {
		id = 3,
		name = 'chui',
		rate = 1000,
		cost = {1,2,3,4},
		open = true,
		srcpath = 'D:/1.png',
		values = {
			v6 = 2,
			v61 = 3,
		},
		map = {[1] = 2,[3] = 4,[5] = 6},
	},
	[4] = {
		id = 4,
		name = '王大锤',
		rate = 1000,
		cost = {1,2,3,4},
		open = false,
		srcpath = 'D:/1.png',
		values = {
			v11 = 2,
			v12 = 3,
		},
		map = {[1] = 2,[3] = 4,[5] = 6},
	},
	[101] = {
		id = 101,
		name = 'wang',
		rate = 1000,
		cost = {1,2,3,4},
		open = true,
		srcpath = 'D:/1.png',
		values = {
			v1 = 2,
			v2 = 100,
		},
		map = {[1] = 2,[3] = 4,[5] = 6},
	},
	[201] = {
		id = 201,
		name = 'da',
		rate = 1000,
		cost = {1,2,3,4},
		open = false,
		srcpath = 'D:/1.png',
		values = {
			v5 = 2,
			v51 = 3,
		},
		map = {[1] = 2,[3] = 4,[5] = 6},
	},
}
return M
