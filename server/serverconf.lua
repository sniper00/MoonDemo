local db_redis = {
    [1] = {host = "127.0.0.1", port = 6379, timeout = 1000},
    [2] = {host = "127.0.0.1", port = 6379, timeout = 1000}
}

---注意:修改你的数据库名
local db_pg = {
    [1] = { user = "postgres", database = "postgres", password = "123456", host = "127.0.0.1", port = 5432, connect_timeout = 1000 },
    [2] = { user = "postgres", database = "postgres", password = "123456", host = "127.0.0.1", port = 5432, connect_timeout = 1000 },
}

---服务器相关配置
local conf = {
    ---动态获取服务器配置地址,保证和node.json中hub的host一致
    ---如果有多个hub节点建议用nginx做一个负载均衡http代理
    NODE_ETC_URL = "http://127.0.0.1:8003/conf.node?node=%s",
    CLUSTER_ETC_URL = "http://127.0.0.1:8003/conf.cluster?node=%s",
}

---每个区服的数据库配置
conf.db = {}

conf.db[1] = {redis = db_redis[1], pg = db_pg[1]}
conf.db[2] = {redis = db_redis[1], pg = db_pg[1]}
conf.db[3] = {redis = db_redis[1], pg = db_pg[1]}

return conf