using System.Net;

namespace Moon
{
    public class CustomConnection : BaseConnection
    {
        //two bytes len head
        byte[] readBuff = new byte[1024];
        Buffer data = new Buffer(1024);
        public CustomConnection(int id)
            : base(id)
        {

        }

        void ReadLine()
        {

        }

        void ReadSome()
        {
            AsyncRead(readBuff, 0, readBuff.Length, (bytesTransferred, e) =>
            {
                if (null != e)
                {
                    OnClose(e);
                    return;
                }

                if (0 == bytesTransferred)
                {
                    ReadSome();
                    return;
                }
            },ReadMode.Some);
        }


    }
}
