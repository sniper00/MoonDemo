using UnityEngine;

public class UnityUtils
{
    public static Transform CreateEmpty(Vector3 postion,string name,Transform parent = null)
    {
        var obj = new GameObject();
        obj.name = name;
        if (null == parent)
        {
            obj.transform.position = postion;
        }
        else
        {
            obj.transform.SetParent(parent);
            obj.transform.localPosition = postion;
        }
        return obj.transform;
    }

    //查找第一层游戏对象Transform
    public static Transform FindTransform(string name)
    {
        var obj = GameObject.Find(name);
        if(null != obj)
        {
            return obj.transform;
        }
        return null;
    }

    public static bool TouchBegin()
    {
        if (Input.GetMouseButtonDown(0))
        {
            return true;
        }
        if (Input.touchCount > 0 && Input.GetTouch(0).phase == TouchPhase.Began)
        {
            return true;
        }
        return false;
    }

    public static bool TouchEnd()
    {
        if (Input.GetMouseButtonUp(0))
        {
            return true;
        }
        if (Input.touchCount > 0 && Input.GetTouch(0).phase == TouchPhase.Ended)
        {
            return true;
        }
        return false;
    }

    public static bool TouchIng()
    {
        if (Input.GetMouseButton(0))
        {
            return true;
        }
        else if (Input.touchCount > 0 && Input.GetTouch(0).phase == TouchPhase.Moved)
        {
            return true;
        }
        return false;
    }

    public static Vector3 ScreenPointToWorld(Vector3 screenPos,string hitObjectName)
    {
        Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
        RaycastHit hitInfo = new RaycastHit();
        if (Physics.Raycast(ray, out hitInfo))
        {
            if (hitInfo.collider.name == hitObjectName)
            {
                return hitInfo.point;
            }
        }
        return Vector3.zero;
    }

    static public Sprite LoadSprite(string filePath)
    {
        var tex = Resources.Load<Texture2D>(filePath);    
        var spr = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f));
        return spr;
    }
}

