using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Entity
{
    public long id;
    public float radius;
    public long spriteid;
    public float speed;
    public string name;
    public long movetime;
    public Vector2 pos;
    public Vector2 dir;
    public GameObject Go { get; set; }
    public Component.Color Color { get; set; }
    public GameObject NameText { get; set; }
}

public class Game : MonoBehaviour {
    public int nline = 40;
    Dictionary<long, Entity> entitas = new Dictionary<long, Entity>();
    Dictionary<int, string> foodsprite = new Dictionary<int, string>();
    Dictionary<int, string> playersprite = new Dictionary<int, string>();

    Text xpos;
    Text ypos;
    Text countDown;
    int time = 60;

    Transform scene;

    bool gameOver = false;

    GameObject playerPrefab;
    GameObject namePrefab;

    Entity local;

    long uid = 0;

    static bool IsPlayer(long id)
    {
        return ((id >> 62) == 0);
    }

    long now = Millseconds();

    // Use this for initialization
    void Start () {
        foodsprite.Add(1, "Texture/bean_polygon3_1");
        foodsprite.Add(2, "Texture/bean_polygon3_2");
        foodsprite.Add(3, "Texture/bean_polygon3_3");
        foodsprite.Add(4, "Texture/bean_polygon3_4");
        foodsprite.Add(5, "Texture/bean_polygon3_5");
        foodsprite.Add(6, "Texture/bean_polygon3_6");
        foodsprite.Add(7, "Texture/bean_polygon4_1");
        foodsprite.Add(8, "Texture/bean_polygon4_2");
        foodsprite.Add(9, "Texture/bean_polygon4_3");
        foodsprite.Add(10, "Texture/bean_polygon4_4");
        foodsprite.Add(11, "Texture/bean_polygon4_5");
        foodsprite.Add(12, "Texture/bean_polygon4_6");

        playersprite.Add(1, "Texture/bean_polygon5_1");
        playersprite.Add(2, "Texture/bean_polygon5_2");
        playersprite.Add(3, "Texture/bean_polygon5_3");
        playersprite.Add(4, "Texture/bean_polygon5_4");
        playersprite.Add(5, "Texture/bean_polygon5_5");
        playersprite.Add(6, "Texture/bean_polygon5_6");

        xpos = transform.Find("UI/Xpos").GetComponent<Text>();
        ypos = transform.Find("UI/Ypos").GetComponent<Text>();
        countDown = transform.Find("UI/CountDown").GetComponent<Text>();

        scene = UnityUtils.FindTransform("Scene/World");

        playerPrefab = Resources.Load<GameObject>("Prefab/Player");
        namePrefab = Resources.Load<GameObject>("Prefab/TextName");



        Network.Register<NetMessage.S2CEnterRoom>(v => {
            uid = v.Id;
            UserData.time = v.Time;
            UserData.uid = v.Id;
            now = Millseconds();

            Debug.LogFormat("Entity User  id {0} S2CEnterRoom", v.Id);
        });

        Network.Register<NetMessage.S2CEnterView>(v => {
            if(!entitas.ContainsKey(v.Id))
            {
                var e = new Entity();
                e.id = v.Id;
                e.radius = v.Radius;
                e.speed = v.Speed;
                e.spriteid = v.Spriteid;
                e.pos =  new Vector2 { x = v.X, y = v.Y };
                if(null!=v.Dir)
                    e.dir = new Vector2 { x= v.Dir.X, y =v.Dir.Y };
                e.name = v.Name;
                e.movetime = v.Movetime;
                bool isplayer = IsPlayer(e.id);
                GameObject go = Instantiate(playerPrefab, new Vector3(e.pos.x, e.pos.y, 0), Quaternion.identity);
                var spr = go.GetComponent<SpriteRenderer>();
                string source;
                if (isplayer)
                {
                    if (!playersprite.TryGetValue((int)e.spriteid, out source))
                    {
                        source = "Texture/bean_polygon5_1";
                    }
                    Debug.LogFormat("Entity User  id {0} enter view", v.Id);
                }
                else
                {
                    if (!foodsprite.TryGetValue((int)e.spriteid, out source))
                    {
                        source = "Texture/bean_polygon3_1";
                    }
                }

                spr.sprite = UnityUtils.LoadSprite(source);
                spr.sortingLayerName = "Player";
                go.transform.position = new Vector3(e.pos.x, e.pos.y, 0);
                go.transform.SetParent(scene);
                //go.AddComponent<LineRenderer>();
                e.Go = go;
                e.NameText = Instantiate(namePrefab);
                e.NameText.transform.SetParent(transform);
                var text = e.NameText.GetComponent<Text>();

                long number = e.id;
                int numDigitsToKeep = 8;
                string result = number.ToString().Substring(Math.Max(0, number.ToString().Length - numDigitsToKeep));

                text.text = isplayer ? e.name : "food" + result;
                text.color = UnityEngine.Color.green;
                text.alignment = TextAnchor.UpperCenter;
                text.fontStyle = FontStyle.Bold;
                text.fontSize = 21;
                entitas.Add(v.Id, e);
                Debug.LogFormat("Entity  id {0} enter view", v.Id);

                if(v.Id == uid)
                {
                    local = e;
                }
            }
        });

        Network.Register<NetMessage.S2CLeaveView>(v =>
        {
            Entity e;
            if (entitas.TryGetValue(v.Id, out e))
            {
                var text = e.NameText.GetComponent<Text>();
                text.text = "DEAD";
                e.NameText.transform.SetParent(null);
                e.Go.transform.SetParent(null);
                Destroy(e.NameText);
                Destroy(e.Go);
                e.NameText = null;
                e.Go = null;
                if(entitas.Remove(v.Id))
                {
                    Debug.LogFormat("Entity Destroy {0} {1} {2}", v.Id, e.pos.x, e.pos.y);
                }
            }
        });

        Network.Register<NetMessage.S2CMove>(v =>{
            Entity e;
            if (entitas.TryGetValue(v.Id, out e))
            {
                //var delta = (UserData.time - e.movetime) / 1000.0f;
                //var deltalen = e.dir.normalized * e.speed * delta;
                //Vector2 nowPos = e.pos + deltalen;
                //Debug.LogFormat("S2CMove {0} {1} {2} {3}", UserData.time, e.movetime, nowPos.x, nowPos.y);
                e.pos.x = v.X;
                e.pos.y = v.Y;
                e.dir.x = v.Dirx;
                e.dir.y = v.Diry;
                e.movetime = v.Movetime;
            }
        });

        Network.Register<NetMessage.S2CUpdateRadius>(v =>
        {
            Entity e;
            if (entitas.TryGetValue(v.Id, out e))
            {
                e.radius = v.Radius;
            }
        });

        Network.Register<NetMessage.S2CDead>(v =>
        {
            Entity e;
            if (entitas.TryGetValue(v.Id, out e))
            {
                Debug.LogFormat("You dead id {0} dead", v.Id);
                if (v.Id == UserData.uid)
                {
                    SceneManager.LoadScene("Login");
                    return;
                }
            }
        });

        Network.Register<NetMessage.S2CGameOver>(v => {
            gameOver = true;
            MessageBox.Show(string.Format("Game Over, Score : {0}", v.Score),(res)=> {
                SceneManager.LoadScene("Login");
            });
        });

        Network.Send(UserData.GameSeverID, new NetMessage.C2SEnterRoom { Name = UserData.username });

        InvokeRepeating("CountDown", 1f, 1.0f);
    }

    public static long Millseconds()
    {
        //100ns
        var ts = DateTime.UtcNow.Ticks - new DateTime(1970, 1, 1, 0, 0, 0, 0).Ticks;
        return ts / 10000;
    }

    void CountDown()
    {
        time--;
        if(time<=0)
        {
            time = 0;
        }
        countDown.text = string.Format("{0}s", time);
    }

    void Setposition(Vector2 pos)
    {
        local.Go.transform.position = pos;
        xpos.text = string.Format("{0:F}", pos.x);
        ypos.text = string.Format("{0:F}", pos.y);
    }

    // Update is called once per frame
    void Update () {
        var t = Millseconds();
        UserData.time += (t - now);
        now = t;
        if (gameOver)
        {
            return;
        }
        
        if (local !=null && local.Go && Input.GetMouseButtonDown(0))
        {
            Vector2 mousePosition = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            Vector3 target = new Vector3(mousePosition.x, mousePosition.y, 0);
            var dir = target - local.Go.transform.position;
            dir.Normalize();
            Network.Send(UserData.GameSeverID, new NetMessage.C2SMove { X = dir.x,Y= dir.y });
        }

        foreach(var e in entitas.Values)
        {
            if(e.Go == null)
            {
                continue;
            }

            if(IsPlayer(e.id))
            {
                var delta = (UserData.time - e.movetime) / 1000.0f;
                var deltalen = e.dir.normalized * e.speed * delta;
                Vector2 nowPos = e.pos + deltalen;
                if (e == local)
                {
                    Setposition(nowPos);
                    Camera.main.transform.position = new Vector3(nowPos.x, nowPos.y, Camera.main.transform.position.z);
                }
                else
                {
                    e.Go.transform.position = nowPos;
                }
            }

            var rect = e.Go.GetComponent<RectTransform>();
            rect.localScale = new Vector3(1 + e.radius, 1+ e.radius , 1);

            if (e.NameText!=null)
            {
                var uipos = Camera.main.WorldToScreenPoint(e.Go.transform.position);
                e.NameText.transform.position = new Vector3(uipos.x, uipos.y + 10, 0);
            }




            //var lr = e.Go.GetComponent<LineRenderer>();
            //lr.positionCount = nline;
            //lr.startWidth = 0.01f;
            //lr.endWidth = 0.01f;
            //for (int i = 0; i < lr.positionCount - 1; i++)
            //{
            //    var x = newPosition.x + Mathf.Sin((360f * i / nline) * Mathf.Deg2Rad) * e.Radius.value;
            //    var y = newPosition.y + Mathf.Cos((360f * i / nline) * Mathf.Deg2Rad) * e.Radius.value;
            //    lr.SetPosition(i, new Vector3(x, y));
            //}
            //lr.SetPosition(lr.positionCount - 1, lr.GetPosition(0));
        }
    }
}
