using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Entity
{
    public bool Mover { get; set; }
    public bool Food { get; set; }
    public GameObject Go { get; set; }
    public Component.BaseData BaseData { get; set; }
    public Component.Position Position { get; set; }
    public Vector2 Direction { get; set; }
    public Component.Speed Speed { get; set; }
    public Component.Color Color { get; set; }
    public Component.Radius Radius { get; set; }
    public GameObject NameText { get; set; }
}

public class Game : MonoBehaviour {
    public int nline = 40;
    Dictionary<int, Entity> entitas = new Dictionary<int, Entity>();
    Dictionary<int, string> foodsprite = new Dictionary<int, string>();
    Dictionary<int, string> playersprite = new Dictionary<int, string>();

    Text xpos;
    Text ypos;
    Text countDown;
    int time = 60;

    Transform scene;

    bool gameOver = false;

    Entity local;
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

        Network.Register<S2CEnterRoom>(v => {
            var e = new Entity();
            entitas.Add(v.id, e);
            local = e;
        });

        Network.Register<S2CEnterView>(v => {
            var e = new Entity();
            if(!entitas.ContainsKey(v.id))
            {
                entitas.Add(v.id, e);
                Debug.LogFormat("Entity  id {0} enter view", v.id);
            }
        });

        Network.Register<S2CLeaveView>(v =>
        {
            Entity e;
            if (entitas.TryGetValue(v.id, out e))
            {
                if(e.Mover)
                {
                    e.NameText.transform.SetParent(null);
                }

                //Debug.LogFormat("Entity id {0} leave view", v.id);
                Destroy(e.Go);
                entitas.Remove(v.id);
            }
        });

        Network.Register<S2CDead>(v =>
        {
            Entity e;
            if (entitas.TryGetValue(v.id, out e))
            {
                e.NameText.transform.SetParent(null);
                Debug.LogFormat("Entity id {0} dead", v.id);
                if (v.id == UserData.uid)
                {
                    SceneManager.LoadScene("Login");
                    return;
                }
                Destroy(e.Go);
                entitas.Remove(v.id);
            }
        });

        Network.Register<Mover>(v => {
            Entity e;
            if (entitas.TryGetValue(v.id, out e))
            {
                e.Mover =true;
            }
        });

        Network.Register<Food>(v => {
            Entity e;
            if (entitas.TryGetValue(v.id, out e))
            {
                e.Food = true;
            }
        });

        Network.Register<BaseData>(v => {
            Entity e;
            if(entitas.TryGetValue(v.id,out e))
            {
                e.BaseData = v.data;

                GameObject go = Instantiate(Resources.Load<GameObject>("Prefab/Player"));
                var spr = go.GetComponent<SpriteRenderer>();
                string source;
                if(e.Mover)
                {
                    if (!playersprite.TryGetValue(e.BaseData.spriteid, out source))
                    {
                        source = "Texture/bean_polygon5_1";
                    }
                }
                else if(e.Food)
                {
                    if (!foodsprite.TryGetValue(e.BaseData.spriteid, out source))
                    {
                        source = "Texture/bean_polygon3_1";
                    }
                }
                else
                {
                    return;
                }

                spr.sprite = UnityUtils.LoadSprite(source);
                spr.sortingLayerName = "Player";
                go.transform.position = new Vector3(0, 0, 0);
                go.transform.SetParent(scene);
                //go.AddComponent<LineRenderer>();
                e.Go = go;

                if(e.Mover)
                {
                    e.NameText  = Instantiate(Resources.Load<GameObject>("Prefab/TextName"));
                    e.NameText.transform.SetParent(transform);
                    var text = e.NameText.GetComponent<Text>();
                    text.text = e.BaseData.name;
                    text.color = UnityEngine.Color.green;
                    text.alignment = TextAnchor.UpperCenter;
                    text.fontStyle = FontStyle.Bold;
                    text.fontSize = 21;
                }
            }
        });

        Network.Register<Position>(v => {
            Entity e;
            if (entitas.TryGetValue(v.id, out e))
            {
                e.Position = v.data;
                if(null != e.Go)
                {
                    e.Go.transform.position = new Vector3(e.Position.x, e.Position.y, e.Go.transform.position.z);
                    Debug.LogFormat("Entity id {0} Position {1} {2}", v.id, e.Position.x, e.Position.y);
                }
            }
        });

        Network.Register<Direction>(v => {
            Entity e;
            if (entitas.TryGetValue(v.id, out e))
            {
                e.Direction = v.data;
            }
        });

        Network.Register<Speed>(v => {
            Entity e;
            if (entitas.TryGetValue(v.id, out e))
            {
                e.Speed = v.data;
            }
        });

        Network.Register<Color>(v => {
            Entity e;
            if (entitas.TryGetValue(v.id, out e))
            {
                e.Color = v.data;
            }
        });

        Network.Register<Radius>(v => {
            Entity e;
            if (entitas.TryGetValue(v.id, out e))
            {
                e.Radius = v.data;
                var rect = e.Go.GetComponent<RectTransform>();
                rect.localScale = new Vector3(2*e.Radius.value/0.3f, 2 * e.Radius.value / 0.3f, 1);
            }
        });

        Network.Register<S2CGameOver>(v => {
            gameOver = true;
            MessageBox.Show(string.Format("Game Over, Score : {0}", v.score),(res)=> {
                SceneManager.LoadScene("Login");
            });
        });

        Network.Send(UserData.GameSeverID, new C2SEnterRoom { username = UserData.username });

        InvokeRepeating("CountDown", 1f, 1.0f);
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
        if(null == local || local.Go == null || gameOver)
        {
            return;
        }
        
        if (Input.GetMouseButtonDown(0))
        {
            Vector2 mousePosition = Camera.main.ScreenToWorldPoint(Input.mousePosition);
            Vector3 target = new Vector3(mousePosition.x, mousePosition.y, 0);
            var dir = target - local.Go.transform.position;
            dir.Normalize();
            local.Direction = dir;
            Network.Send(UserData.GameSeverID, new CommandMove { x = dir.x,y= dir.y });
            //Debug.LogFormat("dir {0} {1}", local.Direction.x, local.Direction.y);
        }

        foreach(var e in entitas.Values)
        {
            if(!e.Mover || e.Radius==null)
            {
                continue;
            }

            Vector2 pos = e.Go.transform.position;
            var deltalen = e.Direction.normalized * e.Speed.value * Time.deltaTime; ;
            Vector2 newPosition = pos + deltalen;
            if (e == local)
            {
                Setposition(newPosition);
                Camera.main.transform.position = new Vector3(newPosition.x, newPosition.y, Camera.main.transform.position.z);
            }
            else
            {
                e.Go.transform.position = newPosition;
            }

            var uipos = Camera.main.WorldToScreenPoint(e.Go.transform.position);

            e.NameText.transform.position = new Vector3(uipos.x, uipos.y+10, 0);

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
