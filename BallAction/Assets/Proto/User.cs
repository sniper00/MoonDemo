using System.Collections.Generic;
using ProtoBuf;

namespace NetMessage{
    [ProtoContract]
    class S2CErrorCode{
        [ProtoMember(1, Name = @"code")]
        public int Code { get; set; }//错误码
    }

    [ProtoContract]
    class C2SLogin{
        [ProtoMember(1, Name = @"openid")]
        public string Openid { get; set; }//openid
    }

    [ProtoContract]
    class S2CLogin{
        [ProtoMember(1, Name = @"ok")]
        public bool Ok { get; set; }//是否登录成功
        [ProtoMember(2, Name = @"time")]
        public long Time { get; set; }//服务器当前时间ms
        [ProtoMember(3, Name = @"timezone")]
        public long Timezone { get; set; }//服务器当前时区
    }

    [ProtoContract]
    class C2SItemList{
    }

    [ProtoContract]
    class S2CItemList{
        [ProtoMember(11,Name = @"list")]
        public Dictionary<int,ItemData> List { get; set; }//道具列表
    }

    [ProtoContract]
    class C2SUseItem{
        [ProtoMember(1, Name = @"id")]
        public int Id { get; set; }
        [ProtoMember(2, Name = @"count")]
        public long Count { get; set; }
    }

    [ProtoContract]
    class S2CUpdateItem{
        [ProtoMember(1,Name = @"list")]
        public List<ItemData> List { get; set; }
    }

    [ProtoContract]
    class C2SHello{
        [ProtoMember(1, Name = @"hello")]
        public string Hello { get; set; }
    }

    [ProtoContract]
    class S2CWorld{
        [ProtoMember(1, Name = @"world")]
        public string World { get; set; }
    }

}

