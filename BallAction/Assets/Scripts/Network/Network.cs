using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Sockets;
using System.Threading.Tasks;

namespace Moon
{
    public interface ISerializer
    {
        T Deserialize<T>(byte[] data, int index, int count);
        byte[] Serialize<TMsg>(TMsg msg);
    }

    public enum SocketMessageType
    {
        Connect,
        Recv,
        Close,
        Error
    }

    public class SocketMessage
    {
        public SocketMessageType MessageType { get; }
        public int ConnectionID { get; }
        public int TaskID { get; }
        public int Index { set; get; }
        public int Count { set; get; }
        public byte[] Bytes { get; }

        public SocketMessage(int connectionID, SocketMessageType messageType, byte[] bytes, int taskID)
        {
            ConnectionID = connectionID;
            MessageType = messageType;
            Bytes = bytes;
            TaskID = taskID;
        }
    }

    public class SocketErrorMessage : SocketMessage
    {
        public int ErrorCode { get; }
        public string Message { get; }

        public SocketErrorMessage(int connectionID, SocketMessageType messageType,int errorcode, string message, int taskID = 0)
            : base(connectionID, messageType, null, taskID)
        {
            ErrorCode = errorcode;
            Message = message;
        }
    }

    public class Network<TEMsg, TSerializer>
        where TSerializer : ISerializer, new()
    {
        Dictionary<int, MoonConnection> connections = new Dictionary<int, MoonConnection>();
        Queue<SocketMessage> messageQueue = new Queue<SocketMessage>();

        Dictionary<int, Action<SocketMessage>> actionMap = new Dictionary<int, Action<SocketMessage>>();
        Dictionary<int, TaskCompletionSource<SocketMessage>> taskMap = new Dictionary<int, TaskCompletionSource<SocketMessage>>();
        Dictionary<Type, TEMsg> messageIDmap = new Dictionary<Type, TEMsg>();
        readonly TSerializer serializer = new TSerializer();

        int connectionUUID = 1;

        public int DefaultServerID { get; set; }

        public Action<int, int, string> OnError { get; set; }

        readonly int AsyncOpBeginUUID = 0xFFFF;
        int AsyncOpUUID = 0xFFFF;

        int MakeConnectionUUID()
        {
            do
            {
                if (connectionUUID == AsyncOpBeginUUID)
                {
                    connectionUUID = 1;
                }
                else
                {
                    connectionUUID++;
                }
            } while (connections.ContainsKey(connectionUUID));
            return connectionUUID;
        }

        int MakeAsyncOpUUID()
        {
            do
            {
                if (AsyncOpUUID == int.MaxValue)
                {
                    AsyncOpUUID = AsyncOpBeginUUID;
                }
                else
                {
                    AsyncOpUUID++;
                }
            } while (taskMap.ContainsKey(AsyncOpUUID));
            return AsyncOpUUID;
        }

        public SocketMessage Connect(string host, int port)
        {
            int connectionID = MakeConnectionUUID();
            try
            {
                MoonConnection connection = new MoonConnection(connectionID)
                {
                    OnMessage = PushMessage
                };
                connection.Socket.Connect(host, port);
                connections.Add(connectionID, connection);
                connection.ReadHead();
                return new SocketMessage(connectionID,SocketMessageType.Connect,null,0);
            }
            catch (SocketException se)
            {
                return new SocketErrorMessage(connectionID, SocketMessageType.Connect,se.ErrorCode, se.Message);
            }
            catch (Exception e)
            {
                return new SocketErrorMessage(connectionID, SocketMessageType.Connect, -1, e.Message);
            }
        }

        public Task<SocketMessage> AsyncConnect(string host, int port)
        {
            int connectionID = MakeConnectionUUID();
            var task = new TaskCompletionSource<SocketMessage>();
            var taskID = MakeAsyncOpUUID();
            taskMap.Add(taskID, task);
            try
            {
                MoonConnection connection = new MoonConnection(connectionID)
                {
                    OnMessage = PushMessage
                };
                connections.Add(connectionID, connection);
                Socket socket = connection.Socket;
                socket.BeginConnect(host, port, (ar) =>
                {
                    try
                    {
                        Socket s = (Socket)ar.AsyncState;
                        s.EndConnect(ar);
                        PushMessage(new SocketMessage(connectionID, SocketMessageType.Connect, null, taskID));
                        connection.ReadHead();
                    }
                    catch (SocketException se)
                    {
                        PushMessage(new SocketErrorMessage(0, SocketMessageType.Connect, se.ErrorCode, se.Message, taskID));
                    }
                    catch (Exception e)
                    {
                        PushMessage(new SocketErrorMessage(0, SocketMessageType.Connect, 0, e.Message, taskID));
                    }
                }, socket);
            }
            catch (SocketException se)
            {
                connections.Remove(connectionID);
                PushMessage(new SocketErrorMessage(0, SocketMessageType.Connect, se.ErrorCode, se.Message, taskID));
            }
            catch (Exception e)
            {
                connections.Remove(connectionID);
                PushMessage(new SocketErrorMessage(0, SocketMessageType.Connect, 0, e.Message, taskID));
            }
            return task.Task;
        }

        void PushMessage(SocketMessage m)
        {
            lock (messageQueue)
            {
                messageQueue.Enqueue(m);
            }
        }

        public void Close(int connectionID)
        {
            if (connections.ContainsKey(connectionID))
            {
                connections[connectionID].Close();
            }
        }

        public void CloseAll()
        {
            foreach (var s in connections)
            {
                s.Value.Close();
            }
        }

        public void Send(int connectionID, byte[] data)
        {
            Buffer buf = new Buffer();
            buf.Write(data,0,data.Length);
            Send(connectionID, buf);
        }

        public void Send(int connectionID, Buffer data)
        {
            if (connections.ContainsKey(connectionID))
            {
                connections[connectionID].Send(data);
            }
            else
            {
                throw new Exception("network send to unknown connection");
            }
        }

        public void Update()
        {
            lock (messageQueue)
            {
                while (messageQueue.Count != 0)
                {
                    var m = messageQueue.Dequeue();
                    Dispatch(m);
                }
            }
        }

        public void Register(TEMsg id, Action<SocketMessage> callback)
        {
            int intID = (int)Convert.ChangeType(id, typeof(int));
            actionMap[intID] = callback;
        }

        public TEMsg GetOrAddMessageID(Type t)
        {
            TEMsg id;
            if (!messageIDmap.TryGetValue(t, out id))
            {
                var name = t.Name;
                id = (TEMsg)Enum.Parse(typeof(TEMsg), name);
                messageIDmap.Add(t, id);
            }
            return id;
        }

        public async Task<TResponse> Call<TResponse>(object msg)
        {
            var sendmsgid = GetOrAddMessageID(msg.GetType());
            var responseEnumID = GetOrAddMessageID(typeof(TResponse));
            int responsemsgid = (int)Convert.ChangeType(responseEnumID, typeof(int));
            var tcs = new TaskCompletionSource<SocketMessage>();
            taskMap[responsemsgid] = tcs;

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
                        Send(DefaultServerID, ms.ToArray());
                    }
                    else
                    {
                        return default(TResponse);
                    }
                }
            }
            var ret = await tcs.Task;
            return serializer.Deserialize<TResponse>(ret.Bytes, ret.Index, ret.Count);
        }

        public bool Send<TMsg>(TMsg msg)
        {
            var bytes = serializer.Serialize(msg);
            if (null == bytes)
            {
                OnError(0, -1, string.Format("Send Message {0}, Serialize error", msg.ToString()));
                return false;
            }

            var enumID = GetOrAddMessageID(msg.GetType());
            var msgID = Convert.ToUInt16(enumID);
            Buffer buf = new Buffer();
            buf.Write(msgID);
            buf.Write(bytes,0, bytes.Length);
            Send(DefaultServerID, buf);
            return true; 
        }

        void Dispatch(SocketMessage m)
        {
            switch (m.MessageType)
            {
                case SocketMessageType.Connect:
                    {
                        TaskCompletionSource<SocketMessage> tcs;
                        if (taskMap.TryGetValue(m.TaskID, out tcs))
                        {
                            taskMap.Remove(m.TaskID);
                            tcs.SetResult(m);
                        }
                        break;
                    }
                case SocketMessageType.Recv:
                    {
                        using (MemoryStream ms = new MemoryStream(m.Bytes))
                        {
                            using (BinaryReader br = new BinaryReader(ms))
                            {
                                var msgID = br.ReadUInt16();
                                m.Index = (int)ms.Position;
                                m.Count = (int)(m.Count - ms.Position);

                                Action<SocketMessage> action;
                                if (actionMap.TryGetValue(msgID, out action))
                                {
                                    action(m);
                                }
                                else
                                {
                                    TaskCompletionSource<SocketMessage> tcs;
                                    if (taskMap.TryGetValue(msgID, out tcs))
                                    {
                                        taskMap.Remove(msgID);
                                        tcs.SetResult(m);
                                    }
                                    else
                                    {
                                        OnError(0, -1, string.Format("message{0} not register!!", msgID));
                                    }
                                }
                            }
                        }
                        break;
                    }
                case SocketMessageType.Close:
                case SocketMessageType.Error:
                    {
                        var errmsg = m as SocketErrorMessage;
                        OnError(errmsg.ConnectionID, errmsg.ErrorCode, errmsg.Message);
                        break;
                    }
            }
        }
    }
}
