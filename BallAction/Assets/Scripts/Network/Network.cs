using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;

namespace Moon
{
    public interface ISerializer
    {
        T Deserialize<T>(byte[] data);
        byte[] Serialize<TMsg>(TMsg msg);
    }

    class Network<TMsgID, TSerializer>
        where TSerializer: ISerializer,new()
    {
        Dictionary<TMsgID, Action<byte[]>> MessageHanders = new Dictionary<TMsgID, Action<byte[]>>();
        Dictionary<TMsgID, TaskCompletionSource<byte[]>> ExceptHanders = new Dictionary<TMsgID, TaskCompletionSource<byte[]>>();
        Dictionary<Type, TMsgID> messageIDmap = new Dictionary<Type, TMsgID>();
        SessionManager sessionManager = new SessionManager();
        readonly TSerializer serializer = new TSerializer();

        public int DefaultServerID { get; set; }

        public Action<int, int, string> OnError { set { sessionManager.OnError = value; } }

        public Action<string> OnLog = null;

        public Network()
        {
            DefaultServerID = 0;
            sessionManager.OnData = OnData;
        }

        public int Connect(string ip, int port)
        {
            return sessionManager.Connect(ip, port);
        }

        public void Close(int sessonid)
        {
            sessionManager.Close(sessonid);
        }

        public void Update()
        {
            sessionManager.Update();
        }

        public void RegisterMessage(TMsgID id, Action<byte[]> callback)
        {
            MessageHanders[id] = callback;
        }

        TMsgID GetOrAddMessageID(Type t)
        {
            TMsgID id;
            if(!messageIDmap.TryGetValue(t, out id))
            {
                var name = t.Name;
                id = (TMsgID)Enum.Parse(typeof(TMsgID), name);
                messageIDmap.Add(t, id);
            }
            return id;
        }

        public async Task<TResponse> Call<TResponse>(object msg)
        {
            var sendmsgid = GetOrAddMessageID(msg.GetType());
            var responsemsgid = GetOrAddMessageID(typeof(TResponse));
            TaskCompletionSource<byte[]> tcs = new TaskCompletionSource<byte[]>();
            ExceptHanders[responsemsgid] = tcs;

            using (MemoryStream ms = new MemoryStream())
            {
                using (BinaryWriter bw = new BinaryWriter(ms))
                {
                    var len = Convert.ToUInt16(sendmsgid);
                    bw.Write(len);
                    var sdata = serializer.Serialize(msg);
                    if (null != sdata)
                    {
                        bw.Write(sdata);
                        sessionManager.Send(DefaultServerID, ms.ToArray());
                    }
                    else
                    {
                        return default(TResponse);
                    }
                }
            }
            var ret = await tcs.Task;
            return serializer.Deserialize<TResponse>(ret);
        }

        public bool Send<TMsg>(TMsg msg)
        {
            var sendmsgid = GetOrAddMessageID(msg.GetType());
            using (MemoryStream ms = new MemoryStream())
            {
                using (BinaryWriter bw = new BinaryWriter(ms))
                {
                    var len =  Convert.ToUInt16(sendmsgid);
                    bw.Write(len);
                    var sdata = serializer.Serialize(msg);
                    if (null != sdata)
                    {
                        bw.Write(sdata);
                        sessionManager.Send(DefaultServerID, ms.ToArray());
                        return true;
                    }
                }
            }

            if(OnLog!=null)
            {
                OnLog(string.Format("Send Message {0}, Serialize error", sendmsgid));
            }
            return false;
        }

        bool Dispatch(TMsgID msgID, byte[] msgData)
        {
            Action<byte[]> action;
            if (MessageHanders.TryGetValue(msgID,out action))
            {
                action(msgData);
                return true;
            }
            return false;
        }

        void OnData(int sessionID, byte[] data)
        {
            using (MemoryStream ms = new MemoryStream(data))
            {
                using (BinaryReader br = new BinaryReader(ms))
                {
                    var msgID = (TMsgID)Enum.ToObject(typeof(TMsgID), br.ReadUInt16());
                    var msgData = br.ReadBytes((int)(ms.Length - ms.Position));
                    if (!Dispatch(msgID, msgData))
                    {
                        TaskCompletionSource<byte[]> tcs;
                        if (ExceptHanders.TryGetValue(msgID, out tcs))
                        {
                            ExceptHanders.Remove(msgID);
                            tcs.SetResult(msgData);
                        }
                        else
                        {
                            if (OnLog != null)
                            {
                                OnLog(string.Format("message{0} not register!!", msgID));
                            }
                        }
                    }
                }
            }
        }
    }
}
