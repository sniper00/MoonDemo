using UnityEngine;

namespace Component
{

    [System.Serializable]
    public class BaseData
    {
        public int id;
        public string name;
        public int spriteid;
    }


    [System.Serializable]
    public class Position
    {
        public float x;
        public float y;
    }

    [System.Serializable]
    public class Direction
    {
        public float x;
        public float y;
    }

    [System.Serializable]
    public class Speed
    {
        public float value;
    }

    [System.Serializable]
    public class Color
    {
        public int r;
        public int g;
        public int b;
    }

    [System.Serializable]
    public class Radius
    {
        public float value;
    }

    [System.Serializable]
    public class EnterView
    {

    }

    [System.Serializable]
    public class LeaveView
    {

    }
}