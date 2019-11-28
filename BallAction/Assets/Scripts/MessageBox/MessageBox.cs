using UnityEngine;
using System.Collections.Generic;

public class MessageBox : MonoBehaviour
{
    List<MessageBoxContext> waringList = new List<MessageBoxContext>();

    static MessageBox instace;
    MessageBoxWnd wnd;

    void Awake()
    {
        instace = this;
        wnd = GetComponent<MessageBoxWnd>();
    }

    // Use this for initialization
    void Start()
    {
    }

    // Update is called once per frame
    void Update()
    {
        if (waringList.Count > 0)
        {
            MessageBoxContext err = waringList[0];
            waringList.RemoveAt(0);
            wnd.active(err);
        }
    }

    void Add(MessageBoxContext  ctx)
    {
        waringList.Add(ctx);
        Update();
    }

    public static void Show(string text, MessageBoxCallBack callBack = null)
    {
        instace.Add(new MessageBoxContext(text, callBack));
    }

    public static  void SetVisible(bool show)
    {
        instace.wnd.SetVisible(show);
    }
}
