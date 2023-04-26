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

}

