

using UnityEngine;

[System.Serializable]
public class C2SLogin
{
    public string username;
}

[System.Serializable]
public class S2CLogin
{
    public string ret;
    public int uid;
}

[System.Serializable]
public class C2SEnterRoom
{
    public string username;
}

[System.Serializable]
public class S2CEnterRoom
{
    public int id;
}

[System.Serializable]
public class C2SCommandMove
{
    public float x;
    public float y;
}

[System.Serializable]
public class S2CEnterView
{
    public int id;
}

[System.Serializable]
public class S2CLeaveView
{
    public int id;
}

[System.Serializable]
public class S2CDead
{
    public int id;
}

[System.Serializable]
public class S2CMover
{
    public int id;
}

[System.Serializable]
public class S2CFood
{
    public int id;
}

[System.Serializable]
public class S2CBaseData
{
    public int id;
    public Component.BaseData data;
}

[System.Serializable]
public class S2CPosition
{
    public int id;
    public Component.Position data;
}

[System.Serializable]
public class S2CDirection
{
    public int id;
    public Vector2 data;
}

[System.Serializable]
public class S2CSpeed
{
    public int id;
    public Component.Speed data;
}

[System.Serializable]
public class S2CColor
{
    public int id;
    public Component.Color data;
}

[System.Serializable]
public class S2CRadius
{
    public int id;
    public Component.Radius data;
}