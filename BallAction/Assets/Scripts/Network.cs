using System;
using System.Threading.Tasks;
using Moon;
using UnityEngine;

public class Serializer:ISerializer
{
    T ISerializer.Deserialize<T>(byte[] data)
    {
        return JsonUtility.FromJson<T>(System.Text.Encoding.Default.GetString(data));
    }

    byte[] ISerializer.Serialize<TMsg>(TMsg msg)
    {
        return System.Text.Encoding.Default.GetBytes(JsonUtility.ToJson(msg));
    }
}

public class Network : MonoBehaviour {
    static public Network instance;
    Network<MSGID, Serializer> net;

    void Awake()
    {
        instance = this;
        net = new Network<MSGID, Serializer>();
        net.OnLog = (errmsg) => {
            Debug.Log(errmsg);
        };
    }

    // Use this for initialization
    void Start () {
      
    }
	
	// Update is called once per frame
	void Update () {
        net.Update();
    }

    void OnApplicationQuit()
    {
        Debug.Log("Close net...");
        instance.net.Close(instance.net.DefaultServerID);
    }

    static public int Connect(string ip,int port)
    {
        return instance.net.Connect(ip, port);
    }

    static public int SetServerID
    {
         set { instance.net.DefaultServerID = value; }
         get { return instance.net.DefaultServerID; }
    }

    static public async Task<TResponse> Call<TResponse>(object msg)
    {
        return  await instance.net.Call<TResponse>(msg);
    }

    static public bool Send(object msg)
    {
        return instance.net.Send(msg);
    }

    static public void Close(int sessionid)
    {
         instance.net.Close(sessionid);
    }

    static public void Register<TResponse>(MSGID msgid, Action<TResponse> callback)
    {
        instance.net.RegisterMessage(msgid, data=> {
            var response = JsonUtility.FromJson<TResponse>(System.Text.Encoding.Default.GetString(data));
            callback(response);
        });
    }

    static public void OnError(Action<int,int,string> action)
    {
        instance.net.OnError = action;
    }
}
