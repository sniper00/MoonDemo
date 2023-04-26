using System.Collections.Generic;
using ProtoBuf;

namespace NetMessage{
    [ProtoContract]
    class C2SMatch{
    }

    [ProtoContract]
    class S2CMatch{
        [ProtoMember(1, Name = @"res")]
        public bool Res { get; set; }
    }

    [ProtoContract]
    class S2CMatchSuccess{
    }

    [ProtoContract]
    class S2CGameOver{
        [ProtoMember(1, Name = @"score")]
        public long Score { get; set; }
    }

}

