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
        public int ConnectionId { get; }
        public int SessionId { get; }
        public Buffer Data { get; }

        public SocketMessage(int connectionId, SocketMessageType messageType, Buffer data, int sessionId)
        {
            ConnectionId = connectionId;
            MessageType = messageType;
            Data = data;
            SessionId = sessionId;
        }

        public SocketMessage(int connectionId, SocketMessageType messageType, byte[] data, int sessionId)
        {
            ConnectionId = connectionId;
            MessageType = messageType;
            Data = new Buffer(data, 0, data.Length);
            SessionId = sessionId;
        }
    }

    public class Socket
    {
        Dictionary<int, BaseConnection> connections = new Dictionary<int, BaseConnection>();

        Queue<SocketMessage> messageQueue = new Queue<SocketMessage>();

        public Action<SocketMessage> HandleMessage { get; set; }

        int uuid = 1;

        int MakeUUID()
        {
            do
            {
                if (uuid == 0xFFFF)
                {
                    uuid = 1;
                }
                else
                {
                    uuid++;
                }
            } while (connections.ContainsKey(uuid));
            return uuid;
        }

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
                        return new CustomConnection();
                    }
                default:
                    return null;
            }
        }

        public SocketMessage Connect(string host, int port, SocketProtocolType protocolType)
        {
            int connectionID = MakeUUID();
            try
            {
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
                return new SocketMessage(0, SocketMessageType.Error,BaseConnection.GetErrorMessage(se),0);
            }
            catch (Exception e)
            {
                return new SocketMessage(0, SocketMessageType.Error, BaseConnection.GetErrorMessage(e),0);
            }
        }

        public void AsyncConnect(string host, int port, SocketProtocolType protocolType, int sessionid)
        {
            int connectionID = MakeUUID();
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
                        PushMessage(new SocketMessage(0, SocketMessageType.Connect, BaseConnection.GetErrorMessage(se),sessionid));
                    }
                    catch (Exception e)
                    {
                        PushMessage(new SocketMessage(0, SocketMessageType.Connect, BaseConnection.GetErrorMessage(e), sessionid));
                    }
                }, socket);
            }
            catch (SocketException se)
            {
                connections.Remove(connectionID);
                PushMessage(new SocketMessage(0, SocketMessageType.Connect, BaseConnection.GetErrorMessage(se), sessionid));
            }
            catch (Exception e)
            {
                connections.Remove(connectionID);
                PushMessage(new SocketMessage(0, SocketMessageType.Connect, BaseConnection.GetErrorMessage(e), sessionid));
            }
        }

        void PushMessage(SocketMessage m)
        {
            lock (messageQueue)
            {
                messageQueue.Enqueue(m);
            }
        }

        public void Close(int connectionID)
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

        public void Send(int connectionID, byte[] data)
        {
            Buffer buf = new Buffer();
            buf.Write(data, 0, data.Length);
            Send(connectionID, buf);
        }

        public bool Send(int connectionID, Buffer data)
        {
            if (connections.ContainsKey(connectionID))
            {
                connections[connectionID].Send(data);
                return true;
            }
            return false;
        }

        public bool Read(int connectionId, bool line, int count, int sessionid)
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
