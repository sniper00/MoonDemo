using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

class Crypt
{
    public static byte[] HashKey(byte[] str)
    {
        var key = new byte[8];

        uint djb_hash = 5381;
        uint js_hash = 1315423911;

        for (int i = 0; i < str.Length; i++)
        {
            byte c = str[i];
            djb_hash += (djb_hash << 5) + c;
            js_hash ^= ((js_hash << 5) + c + (js_hash >> 2));
        }

        key[0] = (byte)( djb_hash & 0xff);
        key[1] = (byte)((djb_hash >> 8) & 0xff);
        key[2] = (byte)((djb_hash >> 16) & 0xff);
        key[3] = (byte)((djb_hash >> 24) & 0xff);

        key[4] = (byte)(js_hash & 0xff);
        key[5] = (byte)((js_hash >> 8) & 0xff);
        key[6] = (byte)((js_hash >> 16) & 0xff);
        key[7] = (byte)((js_hash >> 24) & 0xff);

        return key;
    }

    public static byte[] HashKey(string str)
    {
        return HashKey(Encoding.Default.GetBytes(str));
    }

    public static byte[] RandomKey()
    {
        byte[] buffer = Guid.NewGuid().ToByteArray();
        int iSeed = BitConverter.ToInt32(buffer, 0);
        Random random = new Random(iSeed);
        var tmp = new byte[8];
        int i;
        byte x = 0;
        for (i = 0; i < 8; i++)
        {
            tmp[i] = (byte)(random.Next() & 0xff);
            x ^= tmp[i];
        }
        if (x == 0)
        {
            tmp[0] |= 1;    // avoid 0
        }
        return tmp;
    }

    public static ulong Random()
    {
        byte[] buffer = Guid.NewGuid().ToByteArray();
        int iSeed = BitConverter.ToInt32(buffer, 0);
        Random random = new Random(iSeed);
        byte[] buf = new byte[8];
        random.NextBytes(buf);
        return BitConverter.ToUInt64(buf, 0);
    }

    public static byte[] DesEncode(byte[] key, byte[] data)
    {
        DESCryptoServiceProvider provider = new DESCryptoServiceProvider();
        provider.Mode = CipherMode.ECB;
        provider.Padding = PaddingMode.PKCS7;
        provider.Key = key;
        using (MemoryStream mStream = new MemoryStream())
        {
            using (CryptoStream cStream = new CryptoStream(mStream, provider.CreateEncryptor(), CryptoStreamMode.Write))
            {
                cStream.Write(data, 0, data.Length);
                cStream.FlushFinalBlock();
                return mStream.ToArray();
            }
        }
    }

    public static string DesEncodeBase64(byte[] key, byte[] data)
    {
        return Convert.ToBase64String(DesEncode(key,data));
    }

    public static byte[] DesDecode(byte[] key, byte[] data)
    {
        DESCryptoServiceProvider provider = new DESCryptoServiceProvider
        {
            Mode = CipherMode.ECB,
            Padding = PaddingMode.PKCS7,
            Key = key
        };
        using (MemoryStream mStream = new MemoryStream())
        {
            using (CryptoStream cStream = new CryptoStream(mStream, provider.CreateDecryptor(), CryptoStreamMode.Write))
            {
                cStream.Write(data, 0, data.Length);
                cStream.FlushFinalBlock();
                return mStream.ToArray();
            }
        }
    }

    public static byte[] DesDecodeBase64(byte[] key, string data)
    {
        return DesDecode(key, Convert.FromBase64String(data));
    }

    public static string Base64Encode(string data)
    {
        return Convert.ToBase64String(Encoding.Default.GetBytes(data));
    }

    public static string Base64Encode(byte[] data)
    {
        return Convert.ToBase64String(data);
    }

    public static string Base64Encode(ulong v)
    {
        return Convert.ToBase64String(BitConverter.GetBytes(v));
    }

    public static byte[] Base64Decode(string data)
    {
        return Convert.FromBase64String(data);
    }

    const string hex = "0123456789abcdef";

    public static string ToHex(byte[] text)
    {
        return BitConverter.ToString(text, 0).Replace("-", string.Empty).ToLower();
    }

    static void HEX(out byte v, char c)
    {
        char tmp = c; if (tmp >= '0' && tmp <= '9') { v = (byte)(tmp - '0'); } else { v = (byte)(tmp - 'a' + 10); }
    }

    public static byte[] FromHex(string text)
    {
        var len = text.Length * 2;
        var buffer = new byte[text.Length/2];
        for (int i = 0; i < len; ++i)
        {
            byte hi;
            byte low;
            HEX(out  hi, text[i]);
            HEX(out  low, text[i+1]);
            if (hi > 16 || low > 16)
            {
                throw new ArgumentException(string.Format("Invalid hex text {0}",text));
            }
        }
        return buffer;
    }

    static readonly uint[] k = new uint[64]{
        0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee ,
        0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501 ,
        0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be ,
        0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821 ,
        0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa ,
        0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8 ,
        0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed ,
        0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a ,
        0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c ,
        0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70 ,
        0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05 ,
        0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665 ,
        0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039 ,
        0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1 ,
        0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1 ,
        0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
    };

    static readonly uint[] r = new uint[64]{
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
        5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
        4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
        6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
    };

    static uint LEFTROTATE(uint x, int c)
    {
        return ((x) << (c)) | ((x) >> (32 - (c)));
    }

    static void DigestMd5(uint[] w, uint []result)
    {
        uint a, b, c, d, f, g, temp;
        uint i;

        a = 0x67452301u;
        b = 0xefcdab89u;
        c = 0x98badcfeu;
        d = 0x10325476u;

        for (i = 0; i < 64; i++)
        {
            if (i < 16)
            {
                f = (b & c) | ((~b) & d);
                g = i;
            }
            else if (i < 32)
            {
                f = (d & b) | ((~d) & c);
                g = (5 * i + 1) % 16;
            }
            else if (i < 48)
            {
                f = b ^ c ^ d;
                g = (3 * i + 5) % 16;
            }
            else
            {
                f = c ^ (b | (~d));
                g = (7 * i) % 16;
            }

            temp = d;
            d = c;
            c = b;
            b = b + LEFTROTATE((a + f + k[i] + w[g]), (int)r[i]);
            a = temp;
        }

        result[0] = a;
        result[1] = b;
        result[2] = c;
        result[3] = d;
    }

    static void HMAC(uint[] x, uint[] y, uint[] result)
    {
        var w = new uint[16];
        var r = new uint[4];
        int i;
        for (i = 0; i < 16; i += 4)
        {
            w[i] = x[1];
            w[i + 1] = x[0];
            w[i + 2] = y[1];
            w[i + 3] = y[0];
        }

        DigestMd5(w, r);

        result[0] = r[2] ^ r[3];
        result[1] = r[0] ^ r[1];
    }

    static void HMAC_MD5(uint[] x, uint[] y, uint[] result)
    {
        var w = new uint[16];
        var r = new uint[4];
        int i;
        for (i = 0; i < 12; i += 4)
        {
            w[i] = x[0];
            w[i + 1] = x[1];
            w[i + 2] = y[0];
            w[i + 3] = y[1];
        }

        w[12] = 0x80;
        w[13] = 0;
        w[14] = 384;
        w[15] = 0;

        DigestMd5(w, r);

        result[0] = (r[0] + 0x67452301u) ^ (r[2] + 0x98badcfeu);
        result[1] = (r[1] + 0xefcdab89u) ^ (r[3] + 0x10325476u);
    }

    public static byte[] HMAC64(ulong x, ulong y)
    {
        var xx = new uint[2];
        var yy = new uint[2];
        xx[0] = (uint)x;
        xx[1] = (uint)(x >> 32);
        yy[0] = (uint)y;
        yy[1] = (uint)(y >> 32);
        var result = new uint[2];
        HMAC(xx, yy, result);

        ulong r = result[0];
        r |= ((ulong)result[1] << 32);
        return BitConverter.GetBytes(r);
    }

    public static string HMAC64_BASE64(ulong x, ulong y)
    {
        var xx = new uint[2];
        var yy = new uint[2];
        xx[0] = (uint)x;
        xx[1] = (uint)(x >> 32);
        yy[0] = (uint)y;
        yy[1] = (uint)(y >> 32);
        var result = new uint[2];
        HMAC(xx, yy, result);
        ulong r = result[0];
        r |= ((ulong)result[1] << 32);
        return Base64Encode(BitConverter.GetBytes(r));
    }

    const ulong P = 0xffffffffffffffc5ul;
    const ulong G = 5;

    private static ulong MUL_MOD_P(ulong a, ulong b)
    {
        ulong m = 0;
        while (b != 0)
        {
            if ((b & 1) != 0)
            {
                ulong t = P - a;
                if (m >= t) m -= t;
                else m += a;
            }
            if (a >= P - a) a = a * 2 - P;
            else a = a * 2;
            b >>= 1;
        }
        return m;

    }

    private static ulong POW_MOD_P(ulong a, ulong b)
    {
        if (b == 1) return a;
        ulong t = POW_MOD_P(a, b >> 1);
        t = MUL_MOD_P(t, t);
        if ((b % 2) != 0) t = MUL_MOD_P(t, a);
        return t;
    }

    // a ^ b % p
    private static ulong Powmodp(ulong a, ulong b)
    {
        if (a > P) a %= P;
        return POW_MOD_P(a, b);
    }

    public static ulong DHExchange(ulong i)
    {
        return Powmodp(G, i);
    }

    public static ulong DHSecret(ulong x, ulong y)
    {
        return Powmodp(x, y);
    }
}

