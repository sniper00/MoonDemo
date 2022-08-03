using UnityEngine;
using Moon;
using System.Threading.Tasks;
using System;
using System.Collections.Generic;
using System.Text;

public static class Serializer
{
    public static Message Decode<Message>(byte[] data,int index, int count)
    {
        return JsonUtility.FromJson<Message>(Encoding.Default.GetString(data, index, count));
    }

    public static byte[] Encode<Message>(Message msg)
    {
        return Encoding.Default.GetBytes(JsonUtility.ToJson(msg));
    }
}

public class Network:MonoBehaviour
{
    static Socket  socket = new Socket();

    static Dictionary<int, Action<SocketMessage>> actions = new Dictionary<int, Action<SocketMessage>>();
    static Dictionary<int, TaskCompletionSource<SocketMessage>> tasks = new Dictionary<int, TaskCompletionSource<SocketMessage>>();

    static Dictionary<Type, MSGID> messageIDmap = new Dictionary<Type, MSGID>();

    static int uuid = 0xFFFF;

    static int MakeSessionID()
    {
        do
        {
            if (uuid == 0xFFFFFFF)
            {
                uuid = 0xFFFF;
            }
            else
            {
                uuid++;
            }
        } while (tasks.ContainsKey(uuid));
        return uuid;
    }

    static public SocketMessage Connect(string ip, int port, SocketProtocolType protocolType)
    {
        return socket.Connect(ip, port, protocolType);
    }

    static public Task<SocketMessage> AsyncConnect(string host, int port, SocketProtocolType protocolType)
    {
        var sessionid = MakeSessionID();
        var task = new TaskCompletionSource<SocketMessage>();
        tasks.Add(sessionid, task);
        socket.AsyncConnect(host, port, protocolType, sessionid);
        return task.Task;
    }

    static public Action<long, string> OnError
    {
        set; private get;
    }

    static public async Task<Response> Call<Response>(long connectionId, object msg)
    {
        var requestId = ToMessageID(msg.GetType());
        var responseId = (int)Convert.ChangeType(ToMessageID(typeof(Response)),typeof(int));
        var task = new TaskCompletionSource<SocketMessage>();
        tasks[responseId] = task;

        Moon.Buffer buffer = new Moon.Buffer();
        buffer.Write(Convert.ToUInt16(requestId));

        var sdata = Serializer.Encode(msg);
        if (null != sdata)
        {
            buffer.Write(sdata,0,sdata.Length);
            Send(connectionId, buffer);
        }
        else
        {
            return default(Response);
        }
        var res = await task.Task;
        return Serializer.Decode<Response>(res.Data.Data, res.Data.Index, res.Data.Count);
    }

    static public void Send(long connectionId, string data)
    {
        socket.Send(connectionId, Encoding.Default.GetBytes(data));
    }

    static public void Send(long connectionId, byte[] data)
    {
        socket.Send(connectionId, data);
    }

    static public void Send(long connectionId, Moon.Buffer data)
    {
        socket.Send(connectionId, data);
    }

    static public bool Send<Message>(long connectionId, Message msg)
    {
        var bytes = Serializer.Encode(msg);
        if (null == bytes)
        {
            OnError(0,  string.Format("Send Message {0}, Serialize error", msg.ToString()));
            return false;
        }

        var id = Convert.ToUInt16(ToMessageID(msg.GetType()));
        Moon.Buffer buffer = new Moon.Buffer();
        buffer.Write(id);
        buffer.Write(bytes, 0, bytes.Length);
        Send(connectionId, buffer);
        return true;
    }

    static public Task<SocketMessage> Read(long connectionId, int count)
    {
        var sessionid = MakeSessionID();
        var task = new TaskCompletionSource<SocketMessage>();
        tasks.Add(sessionid, task);
        socket.Read(connectionId, false, count, sessionid);
        return task.Task;
    }

    static public Task<SocketMessage> ReadLine(long connectionId, int limit = 1024)
    {
        var sessionid = MakeSessionID();
        var task = new TaskCompletionSource<SocketMessage>();
        tasks.Add(sessionid, task);
        socket.Read(connectionId, true, limit, sessionid);
        return task.Task;
    }

    static public MSGID ToMessageID(Type t)
    {
        MSGID id;
        if (!messageIDmap.TryGetValue(t, out id))
        {
            var name = t.Name;
            id = (MSGID)Enum.Parse(typeof(MSGID), name);
            messageIDmap.Add(t, id);
        }
        return id;
    }

    static public void Close(long connectionId)
    {
        socket.Close(connectionId);
    }

    static public void Register<Response>(Action<Response> callback)
    {
        int id = (int)Convert.ChangeType(ToMessageID(typeof(Response)), typeof(int));
        actions[id] = msg =>
        {
            var response = Serializer.Decode<Response>(msg.Data.Data, msg.Data.Index, msg.Data.Count);
            callback(response);
        };
    }

    static void Dispatch(SocketMessage m)
    {
        switch (m.MessageType)
        {
            case SocketMessageType.Connect:
                {
                    TaskCompletionSource<SocketMessage> tcs;
                    if (tasks.TryGetValue(m.SessionId, out tcs))
                    {
                        tasks.Remove(m.SessionId);
                        tcs.SetResult(m);
                    }
                    break;
                }
            case SocketMessageType.Message:
                {
                    if(m.SessionId!=0)
                    {
                        TaskCompletionSource<SocketMessage> tcs;
                        if (tasks.TryGetValue(m.SessionId, out tcs))
                        {
                            tasks.Remove(m.SessionId);
                            tcs.SetResult(m);
                        }
                        else
                        {
                            OnError(0, string.Format("session{0} not register!", m.SessionId));
                        }
                        break;
                    }

                    var msgId = m.Data.ReadUInt16();

                    Action<SocketMessage> action;
                    if (actions.TryGetValue(msgId, out action))
                    {
                        action(m);
                    }
                    else
                    {
                        TaskCompletionSource<SocketMessage> tcs;
                        if (tasks.TryGetValue(msgId, out tcs))
                        {
                            tasks.Remove(msgId);
                            tcs.SetResult(m);
                        }
                        else
                        {
                            string sss = m.Data.GetString();
                            OnError(0, string.Format("message{0} not register!!{1}", msgId, sss));
                        }
                    }
                    break;
                }
            case SocketMessageType.Close:
                {
                    if(m.SessionId!=0)
                    {
                        TaskCompletionSource<SocketMessage> tcs;
                        if (tasks.TryGetValue(m.SessionId, out tcs))
                        {
                            tasks.Remove(m.SessionId);
                            tcs.SetResult(m);
                        }
                        break;
                    }
                    OnError(m.ConnectionId, m.Data.GetString());
                    break;
                }
        }
    }

    void Start()
    {
        socket.HandleMessage = Dispatch;
    }

    void Update()
    {
        socket.Update();
    }

    void OnApplicationQuit()
    {
        Debug.Log("close network...");
        socket.CloseAll();
    }
}
