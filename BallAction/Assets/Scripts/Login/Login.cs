using System.Collections;
using System.Collections.Generic;
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

        if (Network.SetServerID != 0)
        {
            Network.Close(Network.SetServerID);
            Network.SetServerID = 0;
        }
    }

    public async void OnClickLogin()
    {
        if (Network.SetServerID==0)
        {
            if(Ip.text.Length == 0)
            {
                Ip.text = "127.0.0.1";
            }

            if (Port.text.Length == 0)
            {
                Port.text = 12345.ToString();
            }

            var id = Network.Connect(Ip.text, int.Parse(Port.text));
            if(id == 0)
            {
                return;
            }
            Network.SetServerID = id;
        }

        var v = await Network.Call<S2CLogin>(new C2SLogin { username = userName.text });
        if (v.ret == "OK")
        {
            UserData.username = userName.text;
            UserData.uid = v.uid;
            SceneManager.LoadScene("Game");
        }
        else
        {
            MessageBox.Show("玩家已经在线");
            Debug.Log(v.ret);
        }
    }
}
