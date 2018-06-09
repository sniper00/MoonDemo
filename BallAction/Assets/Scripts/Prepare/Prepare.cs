using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Prepare: MonoBehaviour {

    static public Prepare instance;
    bool isInit = false;
    GameObject go;

    void Awake()
    {
        instance = this;
        if (!isInit)
        {
            go = new GameObject("Network");
            go.AddComponent<Network>();
            isInit = true;
            DontDestroyOnLoad(go);
        }
    }

    // Use this for initialization
    void Start () {
        SceneManager.LoadScene("Login");
    }
	
	// Update is called once per frame
	void Update () {
		
	}
}
