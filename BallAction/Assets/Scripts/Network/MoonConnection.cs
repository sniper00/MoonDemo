using System.Net;

namespace Moon
{
    public class MoonConnection: BaseConnection
    {
        //two bytes len head
        const int headLen = sizeof(ushort);
        readonly byte[] head_ = new byte[headLen];

        override public void Start() 
        {
            base.Start();
            ReadHead();
        }

        public override bool Send(Buffer data)
        {
            var len = (short)data.Count;
            len = IPAddress.HostToNetworkOrder(len);
            data.WriteFront(len);
            return base.Send(data);
        }

        public void ReadHead()
        {
            AsyncRead(head_, 0, headLen, (bytesTransferred, e) =>
            {
                if (null != e)
                {
                    Error(e);
                    return;
                }

                if (0 == bytesTransferred)
                {
                    ReadHead();
                    return;
                }

                var size = ToInt16(head_);
                size = IPAddress.NetworkToHostOrder(size);
                ReadBody(size);
            });
        }

        void ReadBody(short size)
        {
            Buffer buf = new Buffer(size, 0);
            AsyncRead(buf.Data, buf.WritePos, size, (bytesTransferred, e) =>
            {
                if (null != e)
                {
                    Error(e);
                    return;
                }

                if (0 == bytesTransferred)
                {
                    ReadHead();
                    return;
                }

                buf.OffsetWritePos(bytesTransferred);

                var m = new SocketMessage(ConnectionID, SocketMessageType.Recv, buf, 0);
                HandleMessage(m);
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
