using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;

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
        Ws
    }

    public class AsyncResult
    {
        public AsyncResult(long connectionId, long session, SocketError errorCode, SocketMessageType messageType)
        {
            ConnectionId = connectionId;
            Session = session;
            MessageType = messageType;
            Data = new Buffer();
            Data.Write(errorCode.ToString());
        }

        public AsyncResult(long connectionId, long session, string errorMessage, SocketMessageType messageType)
        {
            ConnectionId = connectionId;
            Session = session;
            MessageType = messageType;
            Data = new Buffer();
            Data.Write(errorMessage);
        }

        public AsyncResult(long connectionId, SocketError errorCode)
        {
            ConnectionId = connectionId;
            Session = 0;
            MessageType = SocketMessageType.Close;
            Data = new Buffer();
            Data.Write(errorCode.ToString());
        }

        public AsyncResult(long connectionId, long session, Buffer data)
        {
            ConnectionId = connectionId;
            Session = session;
            MessageType = SocketMessageType.Message;
            Data = data;
        }

        public long ConnectionId { get; }
        public long Session { get; }

        public SocketMessageType MessageType { get; set; }

        public Buffer Data { get; set;}
    }

    public class ConnectResult : AsyncResult
    {
        public ConnectResult(long connectionId, long session, EndPoint endPoint, SocketError errorCode)
            : base(connectionId, session, errorCode, SocketMessageType.Connect)
        {
            EndPoint = endPoint;
        }

        public ConnectResult(long connectionId, long session, EndPoint endPoint, string errorMessage)
            : base(connectionId, session, errorMessage, SocketMessageType.Connect)
        {
            EndPoint = endPoint;
        }

        public EndPoint EndPoint { get; }
    }

    public class SocketMessage
    {
        public SocketMessageType MessageType { get; }
        public long ConnectionId { get; }
        public long Session { get; }
        public Buffer Data { get; }

        public SocketMessage(long connectionId, SocketMessageType messageType, Buffer data, long session)
        {
            ConnectionId = connectionId;
            MessageType = messageType;
            Data = data;
            Session = session;
        }

        public SocketMessage(long connectionId, SocketMessageType messageType, byte[] data, long session)
        {
            ConnectionId = connectionId;
            MessageType = messageType;
            Data = new Buffer(data, 0, data.Length);
            Session = session;
        }
    }

    public class SocketManager
    {
        Dictionary<long, IConnection> connections = new Dictionary<long, IConnection>();

        ConcurrentQueue<AsyncResult> messageQueue = new ConcurrentQueue<AsyncResult>();

        long connectionIdSeq = 0;

        IConnection MakeConnection(SocketProtocolType protocolType, long connectionId, Action<AsyncResult> action)
        {
            switch (protocolType)
            {
                case SocketProtocolType.Tcp:
                    {
                        return new TcpConnection(connectionId, action);
                    }
                case SocketProtocolType.Ws:
                    {
                        return new WSConnection(connectionId, action);
                    }
                default:
                    return null;
            }
        }

        public void AsyncConnect(string addr, SocketProtocolType protocolType, long session, int timeout = 0)
        {
            var c = MakeConnection(protocolType, ++connectionIdSeq, PushMessage);
            c.ConnectAsync(addr, session, timeout);
            connections.Add(connectionIdSeq, c);
        }

        void PushMessage(AsyncResult m)
        {
            if (m.MessageType == SocketMessageType.Close && m.ConnectionId > 0)
            {
                Close(m.ConnectionId);
            }
            messageQueue.Enqueue(m);
        }

        public void Close(long connectionID)
        {
            if (connections.TryGetValue(connectionID, out IConnection value))
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
            if (connections.TryGetValue(connectionID, out IConnection value))
            {
                value.Send(data);
                return true;
            }
            return false;
        }

        public AsyncResult PopMessage()
        {
            if (messageQueue.TryDequeue(out AsyncResult m))
            {
                return m;
            }
            return null;
        }
    }
}
