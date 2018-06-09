using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Player
{
    public GameObject go;
    public Vector2 dir;
    public float speed;
    public float radius;
    public bool self;
}

public class Game : MonoBehaviour {
    public int nline = 40;
    Player me;
    Dictionary<int, Player> players = new Dictionary<int, Player>();
    Dictionary<int, GameObject> food = new Dictionary<int, GameObject>();
    Dictionary<int, string> foodsprite = new Dictionary<int, string>();
    Dictionary<int, string> playersprite = new Dictionary<int, string>();

    Text xpos;
    Text ypos;
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

        var parent = transform.parent;
        xpos = parent.Find("UI/Xpos").GetComponent<Text>();
        ypos = parent.Find("UI/Ypos").GetComponent<Text>();

        Network.Register<S2CEnterViewPlayer>(MSGID.S2CEnterViewPlayer, v =>
        {
            GameObject go = Instantiate(Resources.Load<GameObject>("Prefab/Player"));
            var spr = go.GetComponent<SpriteRenderer>();
            string source;
            if (!foodsprite.TryGetValue(v.spriteid, out source))
            {
                source = "Texture/bean_polygon5_1";
            }
            spr.sprite = UnityUtils.LoadSprite(source);
            go.transform.localPosition = new Vector3(v.x, v.y, 0);
            go.transform.SetParent(transform);
            go.AddComponent<LineRenderer>();
            var direction = new Vector2(Mathf.Cos(Mathf.Deg2Rad * v.dir), Mathf.Sin(Mathf.Deg2Rad * v.dir));
            players.Add(v.id, new Player { go = go, dir = direction,speed = v.speed,radius = v.radius,self = false });

            Debug.LogFormat("Enterview player id{0} pos x {1},y {2}", v.id, v.y, v.x,v.dir,v.speed);
        });

        Network.Register<S2CEnterViewFood>(MSGID.S2CEnterViewFood,v =>
        {
            GameObject go = Instantiate(Resources.Load<GameObject>("Prefab/Player"));
            var spr = go.GetComponent<SpriteRenderer>();
            string source;
            if(!foodsprite.TryGetValue(v.spriteid,out source))
            {
                source = "Texture/bean_polygon3_1";
            }
            spr.sprite = UnityUtils.LoadSprite(source);
            go.transform.localPosition = new Vector3(v.x, v.y, 0);
            go.transform.SetParent(transform);
            Debug.LogFormat("Enterview Food id{0} pos x {1},y {2}", v.id, v.y, v.x);
            food.Add(v.id, go);
        });

        Network.Register<S2CLeaveViewFood>(MSGID.S2CLeaveViewFood, v =>
        {
            if (food.ContainsKey(v.id))
            {
                Debug.LogFormat("Food LeaveView id{0}", v.id);
                Destroy(food[v.id]);
                food.Remove(v.id);
            }

            if (players.ContainsKey(v.id))
            {
                Debug.LogFormat("Player LeaveView id{0}", v.id);
                Destroy(players[v.id].go);
                players.Remove(v.id);
            }
        });

        Network.Register<S2CCommandMoveB>(MSGID.S2CCommandMoveB, v =>
        {
            Player p;
            if(players.TryGetValue(v.id, out p))
            {
                var direction = new Vector2(Mathf.Cos(Mathf.Deg2Rad * v.dir), Mathf.Sin(Mathf.Deg2Rad * v.dir));
                p.dir = direction;
            }
        });

        Network.Register<S2CPlayerDead>(MSGID.S2CPlayerDead, v =>
        {
            if (players.ContainsKey(v.id))
            {
                SceneManager.LoadScene("Login");
                Debug.LogFormat("Player dead id{0}", v.id);
                Destroy(players[v.id].go);
                players.Remove(v.id);
            }
        });

        Network.Register<S2CBoradcastRadius>(MSGID.S2CBoradcastRadius, v =>
        {
            Player p;
            if (players.TryGetValue(v.id, out p))
            {
                Debug.LogFormat("S2CBoradcastRadius id{0} radius{1}", v.id,v.radius);
                p.radius = v.radius;
            }
        });

        ReqEnterRoom();
    }
	
    async void CommandMove(float angle)
    {
        var msg =  await Network.Call<S2CCommandMove>(new C2SCommandMove { angle = angle });
        SetMePosition(new Vector2(msg.x, msg.y));
    }

    void SetMePosition(Vector2 pos)
    {
        me.go.transform.localPosition = pos;
        xpos.text = string.Format("{0:F}", pos.x);
        ypos.text = string.Format("{0:F}", pos.y);
    }

	// Update is called once per frame
	void Update () {
        if (Input.GetMouseButtonDown(0))
        {
            Vector2 mousePosition = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            Vector3 target = new Vector3(mousePosition.x, mousePosition.y, 0);
            me.dir = target - me.go.transform.localPosition;
            float angle = Mathf.Atan2(me.dir.y, me.dir.x) * Mathf.Rad2Deg;
            CommandMove(angle);
        }

        foreach(var kv in players)
        {
            var dir = kv.Value.dir;
            Vector2 pos = kv.Value.go.transform.localPosition;
            Vector2 newPosition = pos + dir.normalized * kv.Value.speed * Time.deltaTime;
            if(kv.Value == me)
            {
                SetMePosition(newPosition);
                Camera.main.transform.localPosition = new Vector3(newPosition.x, newPosition.y, Camera.main.transform.localPosition.z);
            }
            else
            {
                kv.Value.go.transform.localPosition = newPosition;
            }

            var lr = kv.Value.go.GetComponent<LineRenderer>();
            lr.positionCount = nline;
            lr.startWidth = 0.01f;
            lr.endWidth = 0.01f;
            for(int i = 0; i < lr.positionCount-1; i++)
            {
                var x = newPosition.x +  Mathf.Sin((360f * i / nline) * Mathf.Deg2Rad) * kv.Value.radius;
                var y = newPosition.y + Mathf.Cos((360f * i / nline) * Mathf.Deg2Rad) * kv.Value.radius;
                lr.SetPosition(i, new Vector3(x, y));
            }
            lr.SetPosition(lr.positionCount-1, lr.GetPosition(0));
        }
    }

    async void ReqEnterRoom()
    {
        var v = await Network.Call<S2CEnterRoom>(new C2SEnterRoom { username = UserData.username });
        var go = Instantiate(Resources.Load<GameObject>("Prefab/Player"));
        go.AddComponent<LineRenderer>();
        var dir = new Vector3(Mathf.Cos(Mathf.Deg2Rad * v.dir), Mathf.Sin(Mathf.Deg2Rad * v.dir));
        me = new Player { go = go, dir = dir, speed = v.speed, radius = v.radius, self = true };
        var spr = me.go.GetComponent<SpriteRenderer>();
        string source;
        if (!foodsprite.TryGetValue(v.spriteid, out source))
        {
            source = "Texture/bean_polygon5_1";
        }
        spr.sprite = UnityUtils.LoadSprite(source);
        me.go.transform.localPosition = new Vector3(v.x, v.y, 0);
        me.go.transform.SetParent(transform);
        players.Add(UserData.playerid,me);
        Debug.LogFormat("enter room success pos x {0},y {1} dir{2}{3}",v.x,v.y, dir.x,dir.y);
    }
}
