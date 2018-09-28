using UnityEngine;
using Moon;
using System.Threading.Tasks;
using System;

public class Serializer : ISerializer
{
    T ISerializer.Deserialize<T>(byte[] data,int index, int count)
    {
        return JsonUtility.FromJson<T>(System.Text.Encoding.Default.GetString(data, index, count));
    }

    byte[] ISerializer.Serialize<TMsg>(TMsg msg)
    {
        return System.Text.Encoding.Default.GetBytes(JsonUtility.ToJson(msg));
    }
}

public class Network:MonoBehaviour
{
    static Network<MSGID, Serializer> net = new Network<MSGID, Serializer>();

    static public SocketMessage Connect(string ip, int port)
    {
        return net.Connect(ip, port);
    }

    static public Task<SocketMessage> AsyncConnect(string host, int port)
    {
        return net.AsyncConnect(host, port);
    }

    static public int ServerID
    {
        set { net.DefaultServerID = value; }
        get { return net.DefaultServerID; }
    }

    static public Action<int, int, string> OnError
    {
        set { net.OnError = value; }
    }

    static public async Task<TResponse> Call<TResponse>(object msg)
    {
        return await net.Call<TResponse>(msg);
    }

    static public bool Send(object msg)
    {
        return net.Send(msg);
    }

    static public void Close(int sessionid)
    {
        net.Close(sessionid);
    }

    static public void Register<TResponse>(Action<TResponse> callback)
    {
        MSGID msgid = net.GetOrAddMessageID(typeof(TResponse));
        net.Register(msgid, msg =>
        {
            var response = JsonUtility.FromJson<TResponse>(System.Text.Encoding.Default.GetString(msg.Bytes,msg.Index,msg.Count));
            callback(response);
        });
    }

    void Update()
    {
        net.Update();
    }

    void OnApplicationQuit()
    {
        Debug.Log("Close net...");
        net.CloseAll();
    }
}
