using System;
using System.Collections.Generic;
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
        Recv,
        Close,
        Error
    }

    public enum SocketProtocolType
    {
        Socket,
        Text,
    }

    public class SocketMessage
    {
        public SocketMessageType MessageType { get; }
        public string ConnectionId { get; }
        public int SessionId { get; }
        public Buffer Data { get; }

        public SocketMessage(string connectionId, SocketMessageType messageType, Buffer data, int sessionId)
        {
            ConnectionId = connectionId;
            MessageType = messageType;
            Data = data;
            SessionId = sessionId;
        }

        public SocketMessage(string connectionId, SocketMessageType messageType, byte[] data, int sessionId)
        {
            ConnectionId = connectionId;
            MessageType = messageType;
            Data = new Buffer(data, 0, data.Length);
            SessionId = sessionId;
        }
    }

    public class Socket
    {
        Dictionary<string, BaseConnection> connections = new Dictionary<string, BaseConnection>();

        Queue<SocketMessage> messageQueue = new Queue<SocketMessage>();

        public Action<SocketMessage> HandleMessage { get; set; }

        BaseConnection MakeConnection(SocketProtocolType protocolType)
        {
            switch(protocolType)
            {
                case SocketProtocolType.Socket:
                    {
                        return new MoonConnection();
                    }
                case SocketProtocolType.Text:
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
                var connectionID = Guid.NewGuid().ToString();
                var connection = MakeConnection(protocolType);
                connection.HandleMessage = PushMessage;
                connection.Socket.Connect(host, port);
                connection.ConnectionID = connectionID;
                connections.Add(connectionID, connection);

                connection.Start();

                return new SocketMessage(connectionID, SocketMessageType.Connect, (Buffer)null, 0);
            }
            catch (SocketException se)
            {
                return new SocketMessage("", SocketMessageType.Error,BaseConnection.GetErrorMessage(se),0);
            }
            catch (Exception e)
            {
                return new SocketMessage("", SocketMessageType.Error, BaseConnection.GetErrorMessage(e),0);
            }
        }

        public void AsyncConnect(string host, int port, SocketProtocolType protocolType, int sessionid)
        {
            var connectionID = Guid.NewGuid().ToString();
            try
            {
                var connection = MakeConnection(protocolType);
                connection.HandleMessage = PushMessage;
                connection.ConnectionID = connectionID;
                var socket = connection.Socket;
                socket.BeginConnect(host, port, (ar) =>
                {
                    try
                    {
                        connections.Add(connectionID, connection);
                        var s = (System.Net.Sockets.Socket)ar.AsyncState;
                        s.EndConnect(ar);
                        PushMessage(new SocketMessage(connectionID, SocketMessageType.Connect, (Buffer)null, sessionid));
                        connection.Start();
                    }
                    catch (SocketException se)
                    {
                        PushMessage(new SocketMessage("", SocketMessageType.Connect, BaseConnection.GetErrorMessage(se),sessionid));
                    }
                    catch (Exception e)
                    {
                        PushMessage(new SocketMessage("", SocketMessageType.Connect, BaseConnection.GetErrorMessage(e), sessionid));
                    }
                }, socket);
            }
            catch (SocketException se)
            {
                connections.Remove(connectionID);
                PushMessage(new SocketMessage("", SocketMessageType.Connect, BaseConnection.GetErrorMessage(se), sessionid));
            }
            catch (Exception e)
            {
                connections.Remove(connectionID);
                PushMessage(new SocketMessage("", SocketMessageType.Connect, BaseConnection.GetErrorMessage(e), sessionid));
            }
        }

        void PushMessage(SocketMessage m)
        {
            lock (messageQueue)
            {
                messageQueue.Enqueue(m);
            }
        }

        public void Close(string connectionID)
        {
            if (connections.ContainsKey(connectionID))
            {
                connections[connectionID].Close();
            }
        }

        public void CloseAll()
        {
            foreach (var s in connections)
            {
                s.Value.Close();
            }
        }

        public void Send(string connectionID, byte[] data)
        {
            Buffer buf = new Buffer();
            buf.Write(data, 0, data.Length);
            Send(connectionID, buf);
        }

        public bool Send(string connectionID, Buffer data)
        {
            if (connections.ContainsKey(connectionID))
            {
                connections[connectionID].Send(data);
                return true;
            }
            return false;
        }

        public bool Read(string connectionId, bool line, int count, int sessionid)
        {
            if (connections.ContainsKey(connectionId))
            {
                connections[connectionId].Read(line,count,sessionid);
                return true;
            }
            return false;
        }

        public void Update()
        {
            lock (messageQueue)
            {
                while (messageQueue.Count != 0)
                {
                    var m = messageQueue.Dequeue();
                    HandleMessage(m);
                }
            }
        }
    }
}
