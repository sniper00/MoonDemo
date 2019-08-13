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
            go = new GameObject("DontDestroy");
            go.AddComponent<Network>();
            mbox = Instantiate((GameObject)Resources.Load("Prefab/MessageBox"));
            mbox.transform.parent = go.transform;
            isInit = true;
            DontDestroyOnLoad(go);

            Network.OnError = (connectId, errmsg) =>
            {
                var str = string.Format("Sessonid: {0} ErrorMessage: {1}", connectId, errmsg);
                if(connectId == UserData.GameSeverID)
                {
                    MessageBox.Show(str, (res) => {
                        SceneManager.LoadScene("Login");
                    });
                }
                Debug.Log(str);
            };
        }
    }

    // Use this for initialization
    void Start () {
        SceneManager.LoadScene("Login");
    }
}
