using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Login : MonoBehaviour
{

    Text userName;
    // Use this for initialization
    void Start()
    {
        userName = transform.Find("Username/Text").GetComponent<Text>();
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
            var id = Network.Connect("127.0.0.1", 12345);
            Network.SetServerID = id;
        }

        var v = await Network.Call<S2CLogin>(new C2SLogin { username = userName.text });
        if (v.ret == "OK")
        {
            UserData.username = userName.text;
            UserData.playerid = v.playerid;
            SceneManager.LoadScene("Game");
        }
        else
        {
            Debug.Log(v.ret);
        }
    }
}
