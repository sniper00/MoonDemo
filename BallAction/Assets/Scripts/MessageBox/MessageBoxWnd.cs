using UnityEngine;
using System.Collections;
using UnityEngine.UI;
using System.Collections.Generic;

public enum EMessageResult
{
    OK,
    Cancel
}

public delegate void MessageBoxCallBack(EMessageResult eret);

public class MessageBoxContext
{
    public MessageBoxCallBack result;
    public string value;

    public MessageBoxContext(string value, MessageBoxCallBack result = null)
    {
        this.value = value;
        this.result = result;
    }
}

public class MessageBoxWnd : MonoBehaviour {

    Text errorText = null;
    // Use this for initialization

    MessageBoxCallBack result;

    GameObject canvas;

    void Awake()
    {
        canvas = transform.Find("Canvas").gameObject;
        var t = transform.Find("Canvas/Shade/Background/Text");
        errorText = t.gameObject.GetComponent<Text>();
    }

    void Start()
    {

    }

    public void active(MessageBoxContext value)
    {
        errorText.text = value.value;
        result = value.result;
        canvas.SetActive(true);
    }

    public void OnOK()
    {
        canvas.SetActive(false);
        if (result != null)
        {
            result(EMessageResult.OK);
        }
    }

    public void OnCancel()
    {
        canvas.SetActive(false);
        if (result != null)
        {
            result(EMessageResult.Cancel);
        }
    }

    public void SetVisible(bool show)
    {
        canvas.SetActive(show);
    }
}


