

using UnityEngine;

[System.Serializable]
public class C2SLogin
{
    public string token;
}

[System.Serializable]
public class S2CLogin
{
    public string res;
}

[System.Serializable]
public class C2SMatch
{
    public bool res;
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
    public string username;
}

[System.Serializable]
public class S2CEnterRoom
{
    public int id;
}

[System.Serializable]
public class CommandMove
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
public class Mover
{
    public int id;
}

[System.Serializable]
public class Food
{
    public int id;
}

[System.Serializable]
public class BaseData
{
    public int id;
    public Component.BaseData data;
}

[System.Serializable]
public class Position
{
    public int id;
    public Component.Position data;
}

[System.Serializable]
public class Direction
{
    public int id;
    public Vector2 data;
}

[System.Serializable]
public class Speed
{
    public int id;
    public Component.Speed data;
}

[System.Serializable]
public class Color
{
    public int id;
    public Component.Color data;
}

[System.Serializable]
public class Radius
{
    public int id;
    public Component.Radius data;
}

[System.Serializable]
public class S2CGameOver
{
    public int score;
}