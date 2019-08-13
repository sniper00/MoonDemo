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
            Port.text = 22345.ToString();
        }

        if (UserData.LoginSeverID != 0)
        {
            Network.Close(UserData.LoginSeverID);
            UserData.LoginSeverID = 0;
        }

        if (UserData.GameSeverID != 0)
        {
            Network.Close(UserData.GameSeverID);
            UserData.GameSeverID = 0;
        }
    }

    public async void OnClickLogin()
    {
        if (UserData.LoginSeverID == 0)
        {
            var result = await Network.AsyncConnect("127.0.0.1", 42346, Moon.SocketProtocolType.Text);
            if (result.ConnectionId == 0)
            {
                MessageBox.Show(result.Data.GetString());
                return;
            }
            UserData.LoginSeverID = result.ConnectionId;
        }

        string handshake = "";
        {
            var line = await Network.ReadLine(UserData.LoginSeverID);
            Debug.LogFormat("1. challenge {0}", line.Data.GetString());
            var challenge = BitConverter.ToUInt64(Crypt.Base64Decode(line.Data.GetString()), 0);
            var clientkey = Crypt.Random();
            Network.Send(UserData.LoginSeverID, Crypt.Base64Encode(Crypt.DHExchange(clientkey)) + "\n");

            line = await Network.ReadLine(UserData.LoginSeverID);

            var secret = Crypt.DHSecret(BitConverter.ToUInt64(Crypt.Base64Decode(line.Data.GetString()), 0), clientkey);
            Debug.Log(string.Format("2. sceret is {0}", Crypt.ToHex(BitConverter.GetBytes(secret))));
            Network.Send(UserData.LoginSeverID, Crypt.HMAC64_BASE64(challenge, secret) + "\n");

            string server = "game_3";
            string user = userName.text;
            string pass = "password";

            string token = string.Format("{0}@{1}:{2}", Crypt.Base64Encode(user), Crypt.Base64Encode(server), Crypt.Base64Encode(pass));
            var etoken = Crypt.DesEncodeBase64(BitConverter.GetBytes(secret), Encoding.Default.GetBytes(token));
            Network.Send(UserData.LoginSeverID, etoken + "\n");
            line = await Network.ReadLine(UserData.LoginSeverID);

            var result = line.Data.GetString();
            var code = result.Substring(0, 3);
            Debug.LogFormat("3. code {0}", code);
            if (code != "200")
            {
                return;
            }
            Network.Close(UserData.LoginSeverID);
            UserData.LoginSeverID = 0;

            var subid = Crypt.Base64Decode(result.Substring(4));
            Debug.Log("login ok, subid= " + Encoding.Default.GetString(subid));

            handshake = string.Format("{0}@{1}#{2}:{3}", Crypt.Base64Encode(user), Crypt.Base64Encode(server), Crypt.Base64Encode(subid), 1);
            string hmac = Crypt.HMAC64_BASE64(BitConverter.ToUInt64(Crypt.HashKey(handshake), 0), secret);
            handshake = handshake + ":" + hmac;

            UserData.uid = int.Parse(Encoding.Default.GetString(subid));
        }


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

            var result = await Network.AsyncConnect(Ip.text, int.Parse(Port.text),Moon.SocketProtocolType.Socket);
            if (result.ConnectionId == 0)
            {
                MessageBox.Show(result.Data.GetString());
                return;
            }
            UserData.GameSeverID = result.ConnectionId;
        }

        var v = await Network.Call<S2CLogin>(UserData.GameSeverID, new C2SLogin { token = handshake });
        if (v.res == "200 OK")
        {
            UserData.username = userName.text;

            SceneManager.LoadScene("Game");
        }
        else
        {
            MessageBox.Show(v.res);
            Debug.Log(v.res);
        }
    }
}
