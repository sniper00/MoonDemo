using System.Collections.Generic;
using ProtoBuf;

namespace NetMessage{
    [ProtoContract]
    class Vector2{
        [ProtoMember(1, Name = @"x")]
        public float X { get; set; }
        [ProtoMember(2, Name = @"y")]
        public float Y { get; set; }
    }

    [ProtoContract]
    class ItemData{
        [ProtoMember(1, Name = @"id")]
        public int Id { get; set; }//道具id
        [ProtoMember(2, Name = @"count")]
        public long Count { get; set; }//道具数量
    }

    [ProtoContract]
    class MailData{
        [ProtoMember(1, Name = @"id")]
        public long Id { get; set; }//邮件唯一ID
        [ProtoMember(2, Name = @"mail_key")]
        public string MailKey { get; set; }//邮件配置key, 因为要在代码里面写死，推荐用有意义的字符串做key
        [ProtoMember(3, Name = @"ctime")]
        public long Ctime { get; set; }//邮件创建时间
        [ProtoMember(4, Name = @"flag")]
        public int Flag { get; set; }//1<<0:是否可领取 1<<1:是否只展示 1<<2:是否已读 1<<3:是否锁定
        [ProtoMember(5,Name = @"rewards")]
        public List<ItemData> Rewards { get; set; }//可领取奖励列表 或者 奖励展示列表
        [ProtoMember(6, Name = @"trace")]
        public int Trace { get; set; }//追踪奖励邮件的来源
        [ProtoMember(7, Name = @"parmas")]
        public string Parmas { get; set; }//json格式邮件自定义参数
    }

}

