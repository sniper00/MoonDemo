// 命名空间
using System;
using System.Net.Sockets;
using UnityWebSocket;

namespace Moon
{
    public class WSConnection : IConnection
    {
        public Action<AsyncResult> HandleMessage { get; }
        WebSocket ws;
        public long ConnectionId { get; private set; }

        public WSConnection(long connectionId, Action<AsyncResult> handleMessage)
        {
            ConnectionId = connectionId;
            HandleMessage = handleMessage;
        }

        public void ConnectAsync(string addr, long session, long timeout)
        {
            ws = new WebSocket(string.Format("ws://{0}", addr));
            ws.OnOpen += (sender, e) =>
            {
                HandleMessage(new ConnectResult(ConnectionId, session, null, SocketError.Success));
            };
            ws.OnMessage += (sender, e) =>
            {
                var buffer = new Buffer();
                buffer.Write(e.RawData, 0, e.RawData.Length);

                HandleMessage(new AsyncResult(ConnectionId, 0, buffer));
            };
            ws.OnError += (sender, e) =>
            {
                if(ws.ReadyState == WebSocketState.Open){
                    HandleMessage(new AsyncResult(ConnectionId, 0, e.Message, SocketMessageType.Close));
                }else{
                    HandleMessage(new ConnectResult(ConnectionId, session, null, e.Message));
                }
            };
            ws.OnClose += (sender, e) =>
            {
                HandleMessage(new AsyncResult(ConnectionId, 0, string.Format("Closed: StatusCode: {0}, Reason: {1}", e.StatusCode, e.Reason), SocketMessageType.Close));
            };
            ws.ConnectAsync();
        }

        public void Send(Buffer data)
        {
            byte[] buffer = new byte[data.Count];
            Array.Copy(data.Data, data.Index, buffer, 0, data.Count);
            ws.SendAsync(buffer);
        }

        public bool Connected()
        {
            return ws.ReadyState == WebSocketState.Open;
        }

        public void Close()
        {
            ws.CloseAsync();
        }
    }
}