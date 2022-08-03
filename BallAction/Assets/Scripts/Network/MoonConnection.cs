using System.Net;

namespace Moon
{
    public class MoonConnection : BaseConnection
    {
        //two bytes len head
        const int headLen = sizeof(ushort);
        readonly byte[] head_ = new byte[headLen];

        const int MASK_CONTINUED = 1 << (sizeof(ushort) * 8 - 1);
        const int MAX_CHUNK_SIZE = MASK_CONTINUED ^ ushort.MaxValue;

        Buffer buf = null;

        override public void Start()
        {
            ReadHead();
        }

        public override bool Send(Buffer data)
        {
            var len = (short)data.Count;
            len = IPAddress.HostToNetworkOrder(len);
            data.WriteFront(len);
            return base.Send(data);
        }

        void ReadHead()
        {
            AsyncRead(head_, 0, headLen, (bytesTransferred, e) =>
            {
                if (null != e)
                {
                    Error(e);
                    return;
                }

                var size = ToInt16(head_);
                size = IPAddress.NetworkToHostOrder(size);

                bool fin = ((size & MASK_CONTINUED) == 0);
                if (!fin)
                {
                    size &= MAX_CHUNK_SIZE;
                }

                ReadBody(size, fin);
            });
        }

        void ReadBody(short size, bool fin)
        {
            if (buf == null)
            {
                buf = new Buffer(fin ? size : 5 * size);
            }
            else
            {
                buf.Prepare(size);
            }

            AsyncRead(buf.Data, buf.WritePos, size, (bytesTransferred, e) =>
            {
                if (null != e)
                {
                    Error(e);
                    return;
                }

                buf.Commit(bytesTransferred);

                if (fin)
                {
                    var m = new SocketMessage(ConnectionID, SocketMessageType.Message, buf, 0);
                    buf = null;
                    HandleMessage(m);
                }

                ReadHead();
            });
        }

        short ToInt16(byte[] bytes)
        {
            int v1 = bytes[0];
            int v2 = bytes[1];

            var value = v1
                | (v2 << 8);
            return (short)value;
        }
    }
}
