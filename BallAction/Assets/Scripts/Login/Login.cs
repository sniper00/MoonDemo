using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Login : MonoBehaviour
{
    Text userName;
    InputField Ip;
    InputField Port;

    Toggle toggleWS;

    Moon.SocketProtocolType protocolType = Moon.SocketProtocolType.Tcp;
    // Use this for initialization
    void Start()
    {
        userName = transform.Find("Username/Text").GetComponent<Text>();
        Ip = transform.Find("IP").GetComponent<InputField>();
        Port = transform.Find("Port").GetComponent<InputField>();
        toggleWS = transform.Find("ToggleWS").GetComponent<Toggle>();

        if (Ip.text.Length == 0)
        {
            Ip.text = "127.0.0.1";
        }

        if (Port.text.Length == 0)
        {
            Port.text = 12345.ToString();
        }

        if (UserData.GameSeverID != 0)
        {
            Network.Close(UserData.GameSeverID);
            UserData.GameSeverID = 0;
        }

        Network.Register<NetMessage.S2CMatchSuccess>((res) =>
        {
            MessageBox.SetVisible(false);
            SceneManager.LoadScene("Game");
        });

        toggleWS.onValueChanged.AddListener((bool value) =>
        {
            if (value)
            {
                Port.text = 12346.ToString();
                protocolType = Moon.SocketProtocolType.Ws;
            }
            else
            {
                Port.text = 12345.ToString();
                protocolType = Moon.SocketProtocolType.Tcp;
            }
        });

        if(IsWebPlatform())
        {
            toggleWS.gameObject.GetComponent<Toggle>().isOn = true;
        }
    }

    public async void OnClickLogin()
    {
        if (UserData.GameSeverID == 0)
        {
            if(Ip.text.Length == 0)
            {
                Ip.text = "127.0.0.1";
            }

            if (Port.text.Length == 0)
            {
                Port.text = 12345.ToString();
            }

            var result = await Network.AsyncConnect(Ip.text, int.Parse(Port.text), protocolType);
            if (result.Data.GetString() != "Success")
            {
                MessageBox.Show(result.Data.GetString());
                return;
            }
            UserData.GameSeverID = result.ConnectionId;
        }

        var v = await Network.Call<NetMessage.S2CLogin>(UserData.GameSeverID, new NetMessage.C2SLogin { Openid = userName.text });
        if (v.Ok)
        {
            UserData.time = v.Time;
            UserData.username = userName.text;
            await Network.Call<NetMessage.S2CMatch>(UserData.GameSeverID, new NetMessage.C2SMatch {});
            SceneManager.LoadScene("MatchWait");
        }
        else
        {
            MessageBox.Show("auth failed");
        }
    }

    private bool IsWebPlatform()
    {
        return Application.platform == RuntimePlatform.WebGLPlayer;
    }
}
