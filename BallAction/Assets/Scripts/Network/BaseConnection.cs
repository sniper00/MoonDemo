using System;
using System.Collections.Generic;
using System.Net.Sockets;
using System.Text;

namespace Moon
{
    public enum ReadMode
    {
        Unknown,
        Some,
        FixCount
    }

    class SocketUserToken
    {
        public byte[] Buffer { set; get; }
        public int Index { set; get; }
        public int Count { set; get; }
        public int BytesTransferred { set; get; }
        public ReadMode Mode { set; get; }
        public Action<int, Exception> Handler { get; set; }

        public void Clear()
        {
            Buffer = null;
            Index = 0;
            Count = 0;
            BytesTransferred = 0;
            Mode = ReadMode.Unknown;
            Handler = null;
        }
    }

    public class BaseConnection
    {
        public Action<SocketMessage> HandleMessage { get; set; }

        public System.Net.Sockets.Socket Socket { get; private set; }

        Queue<Buffer> sendQueue = new Queue<Buffer>();

        SocketUserToken readToken = new SocketUserToken();

        public string ConnectionID { get; set; }="";

        bool sending = false;

        public BaseConnection()
        {
            Socket = new System.Net.Sockets.Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
        }

        public virtual void Start()
        {

        }

        public virtual void Read(bool line, int count, int sessionid)
        {

        }

        public bool Connected()
        {
            if (Socket != null)
            {
                return Socket.Connected;
            }
            return false;
        }

        public void Close()
        {
            try
            {
                if (Socket != null)
                {
                    if (Socket.Connected)
                    {
                        Socket.Shutdown(SocketShutdown.Both);
                        Socket.Close();
                        Socket = null;
                    }
                }
            }
            catch (SocketException)
            {

            }
            catch (Exception)
            {

            }
        }

        public static byte[] GetErrorMessage(Exception e)
        {
            SocketException se = e as SocketException;
            if(null!=se)
            {
                var s = string.Format("{0}:{1}.(NativeErrorCode: {2})", se.SocketErrorCode, se.Message, se.NativeErrorCode);
                return Encoding.Default.GetBytes(s);
            }

            return Encoding.Default.GetBytes(e.Message);
        }

        protected void Error(Exception e)
        {
            var m = new SocketMessage(ConnectionID, SocketMessageType.Close, GetErrorMessage(e), 0);
            HandleMessage(m);
        }

        public void AsyncRead(byte[] buffer, int index, int count, Action<int, Exception> handler, ReadMode mode = ReadMode.FixCount)
        {
            readToken.Clear();
            readToken.Buffer = buffer;
            readToken.Index = index;
            readToken.Count = count;
            readToken.Handler = handler;
            readToken.Mode = mode;
            BeginReceive(readToken);
        }

        void BeginReceive(SocketUserToken so)
        {
            if (!Connected())
                return;

            try
            {
                Socket.BeginReceive(so.Buffer, so.Index + so.BytesTransferred, so.Count, SocketFlags.None, (ar) => {
                    SocketUserToken userToken = (SocketUserToken)ar.AsyncState;
                    try
                    {
                        if(null == Socket)
                        {
                            return;
                        }
                        SocketError err;
                        int bytesTransferred = Socket.EndReceive(ar, out err);
                        if(err!= SocketError.Success)
                        {
                            so.Handler(so.BytesTransferred, new SocketException((int)err));
                            return;
                        }
                        
                        if (0 == bytesTransferred)
                        {
                            userToken.Handler(userToken.BytesTransferred, null);
                            return;
                        }

                        userToken.Count -= bytesTransferred;
                        userToken.BytesTransferred += bytesTransferred;
                        if (userToken.Mode == ReadMode.FixCount)
                        {
                            // Since we have not gotten enough bytes for the whole message,
                            // we need to do another receive op.
                            if (userToken.Count != 0)
                            {
                                BeginReceive(userToken);
                                return;
                            }
                        }
                        userToken.Handler(userToken.BytesTransferred, null);
                    }
                    catch (Exception e)
                    {
                        userToken.Handler(userToken.BytesTransferred, e);
                    }
                }, so);
            }
            catch(Exception e)
            {
                so.Handler(so.BytesTransferred, e);
            }
        }

        virtual public bool Send(Buffer data)
        {
            if (null == data || data.Count == 0)
            {
                return false;
            }

            if(!Connected())
            {
                return false;
            }

            lock (sendQueue)
            {
                sendQueue.Enqueue(data);
                if (!sending)
                {
                    DoSend();
                }
            }

            return true;
        }

        void DoSend()
        {
            lock(sendQueue)
            {
                List<ArraySegment<byte>> buffers = null;

                if (sendQueue.Count == 0)
                {
                    sending = false;
                    return;
                }

                buffers = new List<ArraySegment<byte>>();
                while(sendQueue.Count>0)
                {
                    var buff = sendQueue.Dequeue();
                    buffers.Add(new ArraySegment<byte>(buff.Data, buff.Index, buff.Count));
                }

                try
                {
                    sending = true;
                    Socket.BeginSend(buffers, SocketFlags.None, new AsyncCallback(SendCallBack), Socket);
                }
                catch (Exception e)
                {
                    Error(e);
                }
            }
        }

        void SendCallBack(IAsyncResult ar)
        {
            try
            {
                var s = (System.Net.Sockets.Socket)ar.AsyncState;
                SocketError err;
                s.EndSend(ar, out err);
                DoSend();
            }
            catch (Exception e)
            {
                Error(e);
            }
        }
    }
}

