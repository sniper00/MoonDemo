
public class C2SLogin
{
    public string username;
}

public class S2CLogin
{
    public string ret;
    public int playerid;
}

public class C2SEnterRoom
{
    public string username;
}

public class S2CEnterRoom
{
    public float x;
    public float y;
    public float dir;
    public float speed;
    public float radius;
    public int spriteid;
}

public class S2CEnterViewPlayer
{
    public float x;
    public float y;
    public float dir;
    public float speed;
    public float radius;
    public int id;
    public string name;
    public int spriteid;
}

public class S2CEnterViewFood
{
    public float x;
    public float y;
    public int id;
    public int spriteid;
}

public class C2SCommandMove
{
    public float angle;
}

public class S2CCommandMove
{
    public float x;
    public float y;
}

public class S2CCommandMoveB
{
    public int id;
    public float x;
    public float y;
    public float dir;
}

public class S2CLeaveViewPlayer
{
    public int id;
}

public class S2CLeaveViewFood
{
    public int id;
}

public class S2CPlayerDead
{
    public int id;
}

public class S2CBoradcastRadius
{
    public int id;
    public float radius;
}

