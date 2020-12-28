using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Login : MonoBehaviour
{
    Text userName;
    InputField Ip;
    InputField Port;
    // Use this for initialization
    void Start()
    {
        userName = transform.Find("Username/Text").GetComponent<Text>();
        Ip = transform.Find("IP").GetComponent<InputField>();
        Port = transform.Find("Port").GetComponent<InputField>();

        if (Ip.text.Length == 0)
        {
            Ip.text = "127.0.0.1";
        }

        if (Port.text.Length == 0)
        {
            Port.text = 12345.ToString();
        }

        if (UserData.GameSeverID.Length != 0)
        {
            Network.Close(UserData.GameSeverID);
            UserData.GameSeverID = "";
        }

        Network.Register<S2CMatchSuccess>((res) =>
        {
            MessageBox.SetVisible(false);
            SceneManager.LoadScene("Game");
        });
    }

    public async void OnClickLogin()
    {
        if (UserData.GameSeverID.Length == 0)
        {
            if(Ip.text.Length == 0)
            {
                Ip.text = "127.0.0.1";
            }

            if (Port.text.Length == 0)
            {
                Port.text = 12345.ToString();
            }

            var result = await Network.AsyncConnect(Ip.text, int.Parse(Port.text),Moon.SocketProtocolType.Socket);
            if (result.ConnectionId.Length == 0)
            {
                MessageBox.Show(result.Data.GetString());
                return;
            }
            UserData.GameSeverID = result.ConnectionId;
        }

        var v = await Network.Call<S2CLogin>(UserData.GameSeverID, new C2SLogin { openid = userName.text });
        if (v.ok)
        {
            UserData.time = v.time;
            UserData.username = userName.text;
            await Network.Call<S2CMatch>(UserData.GameSeverID, new C2SMatch {});
            SceneManager.LoadScene("MatchWait");
        }
        else
        {
            MessageBox.Show("auth failed");
        }
    }
}
