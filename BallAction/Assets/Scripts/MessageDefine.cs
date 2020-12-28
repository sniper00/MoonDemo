

using UnityEngine;

[System.Serializable]
public class C2SLogin
{
    public string openid;
}

[System.Serializable]
public class S2CLogin
{
    public bool ok;
    public long time;
    public long timezone;
}

[System.Serializable]
public class C2SMatch
{
}

[System.Serializable]
public class S2CMatch
{
    public bool res;
}

[System.Serializable]
public class S2CMatchSuccess
{

}

[System.Serializable]
public class C2SEnterRoom
{
    public string name;
}

[System.Serializable]
public class S2CEnterRoom
{
    public int id;
    public long time;
}

[System.Serializable]
public class C2SMove
{
    public float x;
    public float y;
}

[System.Serializable]
public class S2CMove
{
    public long id;
    public float x;
    public float y;
    public float dirx;
    public float diry;
    public long movetime;
}


[System.Serializable]
public class S2CEnterView
{
    public long id;
    public float x;
    public float y;
    public float radius;
    public long spriteid;
    public float speed;
    public Vector2 dir;
    public string name;
    public long movetime;
}

[System.Serializable]
public class S2CLeaveView
{
    public long id;
}

[System.Serializable]
public class S2CUpdateRadius
{
    public long id;
    public float radius;
}

[System.Serializable]
public class S2CDead
{
    public long id;
}

[System.Serializable]
public class S2CGameOver
{
    public long score;
}