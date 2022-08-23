
---所有数据配置
local db = {
    [1] = {host = "127.0.0.1", port = 6379, timeout = 1000},
    [2] = {host = "127.0.0.1", port = 6379, timeout = 1000}
}

---服务器相关配置
local conf = {
    ---动态获取服务器配置地址,保证和node.json中hub的host一致
    ---如果有多个hub节点建议用nginx做一个负载均衡http代理
    NODE_ETC_HOST = "127.0.0.1:8003",
}

---每个区服的数据库配置
conf.db = {}

conf.db[1] = db[1]
conf.db[2] = db[1]
conf.db[3] = db[1]

return conf