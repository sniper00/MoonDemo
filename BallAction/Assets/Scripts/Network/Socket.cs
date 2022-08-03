using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;

namespace Moon
{
    public interface ISerializer
    {
        T Deserialize<T>(byte[] data, int index, int count);
        byte[] Serialize<TMsg>(TMsg msg);
    }

    public enum SocketMessageType
    {
        Connect,
        Message,
        Close,
    }

    public enum SocketProtocolType
    {
        Tcp,
        TcpMoon,
    }

    class LogicException : ApplicationException
    {
        public LogicException(string message) : base(message)
        {
        }
    }

    public class SocketMessage
    {
        public SocketMessageType MessageType { get; }
        public long ConnectionId { get; }
        public int SessionId { get; }
        public Buffer Data { get; }

        public SocketMessage(long connectionId, SocketMessageType messageType, Buffer data, int sessionId)
        {
            ConnectionId = connectionId;
            MessageType = messageType;
            Data = data;
            SessionId = sessionId;
        }

        public SocketMessage(long connectionId, SocketMessageType messageType, byte[] data, int sessionId)
        {
            ConnectionId = connectionId;
            MessageType = messageType;
            Data = new Buffer(data, 0, data.Length);
            SessionId = sessionId;
        }
    }

    public class Socket
    {
        Dictionary<long, BaseConnection> connections = new Dictionary<long, BaseConnection>();

        ConcurrentQueue<SocketMessage> messageQueue = new ConcurrentQueue<SocketMessage>();

        public Action<SocketMessage> HandleMessage { get; set; }

        long connectionIdSeq = 0;

        BaseConnection MakeConnection(SocketProtocolType protocolType)
        {
            switch (protocolType)
            {
                case SocketProtocolType.TcpMoon:
                    {
                        return new MoonConnection();
                    }
                case SocketProtocolType.Tcp:
                    {
                        return new StreamConnection();
                    }
                default:
                    return null;
            }
        }

        public SocketMessage Connect(string host, int port, SocketProtocolType protocolType)
        {
            try
            {
                var connection = MakeConnection(protocolType);
                connection.HandleMessage = PushMessage;
                connection.Socket.Connect(host, port);
                connection.ConnectionID = ++connectionIdSeq;
                connections.Add(connection.ConnectionID, connection);
                connection.Start();
                return new SocketMessage(connection.ConnectionID, SocketMessageType.Connect, (Buffer)null, 0);
            }
            catch (Exception e)
            {
                return new SocketMessage(0, SocketMessageType.Connect, BaseConnection.GetErrorMessage(e), 0);
            }
        }

        public void AsyncConnect(string host, int port, SocketProtocolType protocolType, int sessionid, int timeout = 0)
        {
            try
            {
                var connection = MakeConnection(protocolType);
                connection.HandleMessage = PushMessage;
                connection.ConnectionID = ++connectionIdSeq;
                var socket = connection.Socket;

                Timer tmr = null;

                if (timeout > 0)
                {
                    tmr = new Timer((obj) =>
                    {
                        var c = (BaseConnection)obj;
                        if (!c.Connected())
                        {
                            c.Close();
                            PushMessage(new SocketMessage(
                                0,
                                SocketMessageType.Connect,
                                BaseConnection.GetErrorMessage(new LogicException("timeout")),
                                sessionid)
                                );
                        }
                    }, connection, timeout, 0);
                }

                var asyncResult = socket.BeginConnect(host, port, (ar) =>
                {
                    try
                    {
                        var c = (BaseConnection)ar.AsyncState;
                        var s = c.Socket;
                        if (s != null)
                        {
                            s.EndConnect(ar);

                            if (tmr != null)
                                tmr.Dispose();
                            connections.Add(c.ConnectionID, c);
                            c.Start();

                            Buffer buf = new Buffer();
                            buf.Write(host + ":" + port.ToString());
                            PushMessage(new SocketMessage(c.ConnectionID, SocketMessageType.Connect, buf, sessionid));
                        }
                    }
                    catch (Exception e)
                    {
                        PushMessage(new SocketMessage(0, SocketMessageType.Connect, BaseConnection.GetErrorMessage(e), sessionid));
                    }
                }, connection);
            }
            catch (Exception e)
            {
                PushMessage(new SocketMessage(0, SocketMessageType.Connect, BaseConnection.GetErrorMessage(e), sessionid));
            }
        }

        void PushMessage(SocketMessage m)
        {
            if (m.MessageType == SocketMessageType.Close && m.ConnectionId > 0)
            {
                Close(m.ConnectionId);
            }
            messageQueue.Enqueue(m);
        }

        public void Close(long connectionID)
        {
            if (connections.TryGetValue(connectionID, out BaseConnection value))
            {
                value.Close();
                connections.Remove(connectionID);
            }
        }

        public void CloseAll()
        {
            foreach (var s in connections)
            {
                s.Value.Close();
            }
        }

        public void Send(long connectionID, byte[] data)
        {
            Buffer buf = new Buffer();
            buf.Write(data, 0, data.Length);
            Send(connectionID, buf);
        }

        public bool Send(long connectionID, Buffer data)
        {
            if (connections.TryGetValue(connectionID, out BaseConnection c))
            {
                c.Send(data);
                return true;
            }
            return false;
        }

        public bool Read(long connectionId, bool line, int count, int sessionid)
        {
            if (connections.TryGetValue(connectionId, out BaseConnection c))
            {
                c.Read(line, count, sessionid);
                return true;
            }
            return false;
        }

        public void Update()
        {
            while (messageQueue.TryDequeue(out SocketMessage m))
            {
                HandleMessage(m);
            }
        }
    }
}
