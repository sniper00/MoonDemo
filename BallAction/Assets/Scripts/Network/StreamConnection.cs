namespace Moon
{
    public class StreamConnection : BaseConnection
    {
        class ReadRequest
        {
            public int Count { get; set; } = 0;
            public int SessionId { get; set; } = 0;
            public bool IsLine { get; set; } = false;
        }

        Buffer buffer = new Buffer(1024);

        ReadRequest request = new ReadRequest();

        public override void Start()
        {
            ReadSome();
        }

        public override void Read(bool line, int count, int sessionid)
        {
            lock(request)
            {
                if (Connected() && request.SessionId == 0)
                {
                    request.IsLine = line;
                    request.Count = count;
                    request.SessionId = sessionid;
                    if (buffer.Count > 0)
                    {
                        HandleReadRequest();
                    }
                }
            }
        }

        void ReadSome()
        {
            buffer.Prepare(1024);
            AsyncRead(buffer.Data, buffer.WritePos, buffer.WriteAbleSize(), (bytesTransferred, e) =>
            {
                if (null != e)
                {
                    Error(e);
                    return;
                }

                if (0 == bytesTransferred)
                {
                    ReadSome();
                    return;
                }

                buffer.Commit(bytesTransferred);

                lock (request)
                {
                    HandleReadRequest();
                }

                ReadSome();
            },ReadMode.Stream);
        }

        void HandleReadRequest()
        {
            if(buffer.Count == 0 || request.SessionId == 0)
            {
                return;
            }

            if(request.IsLine)
            {
                for (int i = 0; i < buffer.Count; ++i)
                {
                    int pos = buffer.Index + i;
                    if (buffer.Data[pos] == '\n')
                    {
                        int n = i + 1;
                        var buf = new byte[n-1];//ignore \n
                        System.Buffer.BlockCopy(buffer.Data, buffer.Index, buf, 0, buf.Length);
                        buffer.Index += n;
                        var m = new SocketMessage(ConnectionID, SocketMessageType.Recv, buf, request.SessionId);
                        Response(m);
                        return;
                    }
                }
                
                if(request.Count!=0 && buffer.Count> request.Count)
                {
                    //outoff limit
                }
            }
            else
            {
                if(buffer.Count>=request.Count)
                {
                    var buf = new byte[request.Count];
                    System.Buffer.BlockCopy(buffer.Data, buffer.Index, buf, 0, buf.Length);
                    buffer.Index += request.Count;
                    var m = new SocketMessage(ConnectionID, SocketMessageType.Recv, buf, request.SessionId);
                    Response(m);
                }
            }
        }

        void Response(SocketMessage m)
        {
            HandleMessage(m);
            request.Count = 0;
            request.SessionId = 0;
            request.IsLine = false;
        }
    }
}
