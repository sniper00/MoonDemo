using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net.Sockets;
using System.Text;
using System.Threading;

namespace Moon
{
    public enum ReadMode
    {
        Unknown,
        Stream,
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

    public abstract class BaseConnection
    {
        public Action<SocketMessage> HandleMessage { get; set; }

        public System.Net.Sockets.Socket Socket { get; private set; }

        readonly ConcurrentQueue<Buffer> sendQueue = new ConcurrentQueue<Buffer>();

        SocketUserToken readToken = new SocketUserToken();

        public long ConnectionID { get; set; }= 0;

        int sending = 0;

        public BaseConnection()
        {
            Socket = new System.Net.Sockets.Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
        }

        public abstract void Start();

        public virtual void Read(bool line, int count, int sessionid)
        {
            throw new NotImplementedException();
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
                    var s = Socket;
                    Socket = null;
                    if (s.Connected)
                        s.Shutdown(SocketShutdown.Both);
                    s.Close();
                }
            }
            catch (Exception)
            {
                //ignore
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
            {
                so.Handler(so.BytesTransferred, new SocketException((int)SocketError.NotConnected));
                return;
            }

            try
            {
                Socket.BeginReceive(so.Buffer, so.Index + so.BytesTransferred, so.Count, SocketFlags.None, (ar) => {
                    SocketUserToken userToken = (SocketUserToken)ar.AsyncState;
                    try
                    {
                        if (null == Socket)
                        {
                            userToken.Handler(userToken.BytesTransferred, new LogicException("operation aborted"));
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
                            userToken.Handler(userToken.BytesTransferred, new LogicException("eof"));
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

            sendQueue.Enqueue(data);

            if(Interlocked.CompareExchange(ref sending, 1, 0) == 0)
            {
                DoSend();
            }
            return true;
        }

        void DoSend()
        {
            List<ArraySegment<byte>> buffers = null;

            if (sendQueue.Count == 0)
            {
                Interlocked.Exchange(ref sending, 0);
                return;
            }

            buffers = new List<ArraySegment<byte>>();
            while(sendQueue.TryDequeue(out Buffer buff))
            {
                buffers.Add(new ArraySegment<byte>(buff.Data, buff.Index, buff.Count));
            }

            try
            {
                Socket.BeginSend(buffers, SocketFlags.None, new AsyncCallback(SendCallBack), Socket);
            }
            catch (Exception e)
            {
                Error(e);
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

