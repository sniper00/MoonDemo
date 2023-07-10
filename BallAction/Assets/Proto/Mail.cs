using System.Collections.Generic;
using ProtoBuf;

namespace NetMessage{
    [ProtoContract]
    class C2SMailList{
    }

    [ProtoContract]
    class S2CMailList{
        [ProtoMember(1,Name = @"mail_list")]
        public Dictionary<long,MailData> MailList { get; set; }
    }

    [ProtoContract]
    class S2CUpdateMail{
        [ProtoMember(1,Name = @"mail_list")]
        public List<MailData> MailList { get; set; }
    }

    [ProtoContract]
    class C2SMailRead{
        [ProtoMember(1, Name = @"id")]
        public long Id { get; set; }
    }

    [ProtoContract]
    class C2SMailLock{
        [ProtoMember(1, Name = @"id")]
        public long Id { get; set; }
    }

    [ProtoContract]
    class C2SMailReward{
        [ProtoMember(1,Name = @"mail_id_list")]
        public List<long> MailIdList { get; set; }
    }

    [ProtoContract]
    class C2SMailMark{
        [ProtoMember(1, Name = @"id")]
        public long Id { get; set; }
    }

    [ProtoContract]
    class C2SMailDel{
        [ProtoMember(1,Name = @"mail_id_list")]
        public List<long> MailIdList { get; set; }
    }

    [ProtoContract]
    class S2CMailDel{
        [ProtoMember(1,Name = @"mail_id_list")]
        public List<long> MailIdList { get; set; }
    }

}

