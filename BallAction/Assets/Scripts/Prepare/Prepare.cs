using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Prepare: MonoBehaviour {

    static public Prepare instance;
    bool isInit = false;
    GameObject go;
    GameObject mbox;

    void Awake()
    {
        instance = this;
        if (!isInit)
        {
            go = new GameObject("Network");
            go.AddComponent<Network>();
            mbox = Instantiate((GameObject)Resources.Load("Prefab/MessageBox"));
            mbox.transform.parent = go.transform;
            isInit = true;
            DontDestroyOnLoad(go);
        }
    }

    // Use this for initialization
    void Start () {
        Network.OnError((sessionid, ec, msg) =>
        {
            MessageBox.Show(string.Format("Network Error, Sessonid{0} ErrorCode{1} ErrorMessage{2}", sessionid, ec, msg));
        });
        SceneManager.LoadScene("Login");
    }
	
	// Update is called once per frame
	void Update () {
		
	}
}
