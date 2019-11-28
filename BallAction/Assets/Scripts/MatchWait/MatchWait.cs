using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class MatchWait : MonoBehaviour
{
    Text countDown;
    int time = 0;
    // Use this for initialization
    void Start()
    {
        countDown = transform.Find("CountDown").GetComponent<Text>();

        InvokeRepeating("CountDown", 0f, 1.0f);
    }

    void CountDown()
    {
        time++;
        countDown.text = string.Format("{0}s", time);
    }
}
