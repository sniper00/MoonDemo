using UnityEngine;
using Moon;
using System.Threading.Tasks;
using System;
using System.Collections.Generic;
using System.Text;
using System.IO;

public static class Serializer
{
    public static Message Decode<Message>(byte[] data, int index, int count)
    {
        using (MemoryStream memory = new MemoryStream(data, index, count))
        {
            //Type t = Type.GetType(Message);
            return (Message)ProtoBuf.Serializer.Deserialize(typeof(Message), memory);
        }
    }

    public static byte[] Encode<Message>(Message msg)
    {
        using (MemoryStream memory = new MemoryStream())
        {
            ProtoBuf.Serializer.Serialize(memory, msg);
            return memory.ToArray();
        }
    }
}

public class Network : MonoBehaviour
{
    static SocketManager mgr = new SocketManager();

    static Dictionary<int, Action<AsyncResult>> actions = new Dictionary<int, Action<AsyncResult>>();
    static Dictionary<long, TaskCompletionSource<AsyncResult>> tasks = new Dictionary<long, TaskCompletionSource<AsyncResult>>();

    static Dictionary<Type, CmdCode> messageIDmap = new Dictionary<Type, CmdCode>();

    static long uuid = 0xFFFF;

    static public async Task<ConnectResult> AsyncConnect(string ip, int port, SocketProtocolType protocolType)
    {
        var session = ++uuid;
        var task = new TaskCompletionSource<AsyncResult>();
        tasks.Add(session, task);
        mgr.AsyncConnect(string.Format("{0}:{1}", ip, port), protocolType, session);
        var res = await task.Task;
        if(res.Data.GetString() != "Success")
        {
            mgr.Close(res.ConnectionId);
        }
        return res as ConnectResult;
    }

    static public Action<long, string> OnError
    {
        set; private get;
    }

    static public async Task<Response> Wait<Response>(long connectionId)
    {
        var responseId = (int)Convert.ChangeType(ToMessageID(typeof(Response)), typeof(int));
        var task = new TaskCompletionSource<AsyncResult>();
        tasks[responseId] = task;
        var res = await task.Task;
        return Serializer.Decode<Response>(res.Data.Data, res.Data.Index, res.Data.Count);
    }

    public class CallResult<T1, T2>
    {
        public bool IsFirstResponse { get; set; }
        public T1 Response1 { get; set; }
        public T2 Response2 { get; set; }
    }

    static public async Task<CallResult<T1, T2>> Call<T1, T2>(long connectionId, object msg)
    {
        var task1 = CreateTaskCompletionSource<T1>(out int responseId1);
        var task2 = CreateTaskCompletionSource<T2>(out int responseId2);

        var requestId = ToMessageID(msg.GetType());
        Moon.Buffer buffer = new Moon.Buffer();
        buffer.Write(Convert.ToUInt16(requestId));

        var sdata = Serializer.Encode(msg);
        if (sdata != null)
        {
            buffer.Write(sdata, 0, sdata.Length);
            Send(connectionId, buffer);
        }
        else
        {
            return new CallResult<T1, T2> { IsFirstResponse = true, Response1 = default(T1), Response2 = default(T2) };
        }

        var res = await Task.WhenAny(task1.Task, task2.Task).ConfigureAwait(false);
        if (res == task1.Task)
        {
            tasks.Remove(responseId2);
            var response = Serializer.Decode<T1>(res.Result.Data.Data, res.Result.Data.Index, res.Result.Data.Count);
            return new CallResult<T1, T2> { IsFirstResponse = true, Response1 = response, Response2 = default(T2) };
        }
        else
        {
            tasks.Remove(responseId1);
            var response = Serializer.Decode<T2>(res.Result.Data.Data, res.Result.Data.Index, res.Result.Data.Count);
            return new CallResult<T1, T2> { IsFirstResponse = false, Response1 = default(T1), Response2 = response };
        }
    }

    private static TaskCompletionSource<AsyncResult> CreateTaskCompletionSource<T>(out int responseId)
    {
        responseId = (int)Convert.ChangeType(ToMessageID(typeof(T)), typeof(int));
        var task = new TaskCompletionSource<AsyncResult>();
        tasks[responseId] = task;
        return task;
    }

    static public async Task<Response> Call<Response>(long connectionId, object msg)
    {
        var requestId = ToMessageID(msg.GetType());
        var responseId = (int)Convert.ChangeType(ToMessageID(typeof(Response)), typeof(int));
        var task = new TaskCompletionSource<AsyncResult>();
        tasks[responseId] = task;

        Moon.Buffer buffer = new Moon.Buffer();
        buffer.Write(Convert.ToUInt16(requestId));

        var sdata = Serializer.Encode(msg);
        if (null != sdata)
        {
            buffer.Write(sdata, 0, sdata.Length);
            Send(connectionId, buffer);
        }
        else
        {
            return default;
        }
        var res = await task.Task;
        return Serializer.Decode<Response>(res.Data.Data, res.Data.Index, res.Data.Count);
    }

    static public void Send(long connectionId, string data)
    {
        mgr.Send(connectionId, Encoding.Default.GetBytes(data));
    }

    static public void Send(long connectionId, byte[] data)
    {
        mgr.Send(connectionId, data);
    }

    static public void Send(long connectionId, Moon.Buffer data)
    {
        mgr.Send(connectionId, data);
    }

    static public bool Send<Message>(long connectionId, Message msg)
    {
        var bytes = Serializer.Encode(msg);
        if (null == bytes)
        {
            OnError(0, string.Format("Send Message {0}, Serialize error", msg.ToString()));
            return false;
        }

        var id = Convert.ToUInt16(ToMessageID(msg.GetType()));
        Moon.Buffer buffer = new Moon.Buffer();
        buffer.Write(id);
        buffer.Write(bytes, 0, bytes.Length);
        Send(connectionId, buffer);
        return true;
    }

    static public CmdCode ToMessageID(Type t)
    {
        if (!messageIDmap.TryGetValue(t, out CmdCode id))
        {
            var name = t.Name;
            id = (CmdCode)Enum.Parse(typeof(CmdCode), name);
            messageIDmap.Add(t, id);
        }
        return id;
    }

    static public void Close(long connectionId)
    {
        mgr.Close(connectionId);
    }

    static public void Register<Response>(Action<Response> callback)
    {
        int id = (int)Convert.ChangeType(ToMessageID(typeof(Response)), typeof(int));
        actions[id] = message =>
        {
            var response = Serializer.Decode<Response>(message.Data.Data, message.Data.Index, message.Data.Count);
            callback(response);
        };
    }

    static void Dispatch(AsyncResult m)
    {
        switch (m.MessageType)
        {
            case SocketMessageType.Connect:
                {
                    TaskCompletionSource<AsyncResult> tcs;
                    if (tasks.TryGetValue(m.Session, out tcs))
                    {
                        tasks.Remove(m.Session);
                        tcs.SetResult(m);
                    }
                    break;
                }
            case SocketMessageType.Message:
                {
                    if (m.Session != 0)
                    {
                        if (tasks.TryGetValue(m.Session, out TaskCompletionSource<AsyncResult> tcs))
                        {
                            tasks.Remove(m.Session);
                            tcs.SetResult(m);
                        }
                        else
                        {
                            OnError(0, string.Format("session{0} not register!", m.Session));
                        }
                        break;
                    }

                    var msgId = m.Data.ReadUInt16();

                    Action<AsyncResult> action;
                    if (actions.TryGetValue(msgId, out action))
                    {
                        action(m);
                    }
                    else
                    {
                        TaskCompletionSource<AsyncResult> tcs;
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
                    if(m.Session!=0)
                    {
                        TaskCompletionSource<AsyncResult> tcs;
                        if (tasks.TryGetValue(m.Session, out tcs))
                        {
                            tasks.Remove(m.Session);
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

    }

    void Update()
    {
        while (true)
        {
            var m = mgr.PopMessage();
            if (m == null)
            {
                break;
            }
            Dispatch(m);
        }
    }

    void OnApplicationQuit()
    {
        Debug.Log("close network...");
        mgr.CloseAll();
    }
}
