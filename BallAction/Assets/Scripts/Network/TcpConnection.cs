using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Threading;

using MessageHeaderType = System.UInt16;

namespace Moon
{
    public enum ReadMode
    {
        AtLeast,
        Exactly
    }

    public class TcpConnection : IConnection
    {
        class UserTokenConnect
        {
            public long Sesson { get; set; }
            public Action<EndPoint, SocketError> Handler { set; get; }

            public Timer Timer { get; set; }
        }

        class UserTokenRead
        {
            public Buffer Buffer { set; get; }
            public ReadMode Mode { set; get; }
            public int ModeCount { set; get; }
            public Action<int, SocketError> Handler { set; get; }
        }

        class UserTokenWrite
        {
            public Buffer Buffer { set; get; }
            public Action<int, SocketError> Handler { get; set; }
        }

        public Action<AsyncResult> HandleMessage { get; }

        private readonly Socket _socket;
        private SocketAsyncEventArgs _rsaea;
        private SocketAsyncEventArgs _wsaea;
        private readonly ConcurrentQueue<Buffer> _sendQueue = new ConcurrentQueue<Buffer>();
        private readonly Buffer _readCache = new Buffer(512);
        private Buffer _readData;

        private long _isSending = 0;

        public long ConnectionId { get;} = 0;

        public TcpConnection(long connectionId, Action<AsyncResult> handleMessage)
        {
            _socket = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
            ConnectionId = connectionId;
            HandleMessage = handleMessage;
        }

        public bool Connected()
        {
            return _socket.Connected;
        }

        public void ConnectAsync(string addr, long session, long timeout)
        {
            bool hasDone = false;

            Timer timer = null;
            if (timeout > 0)
            {
                timer = new Timer((state) =>
                {
                    if(hasDone)
                    {
                        return;
                    }
                    hasDone = true;

                    HandleMessage(new ConnectResult(ConnectionId, session, null, SocketError.TimedOut));
                }, null, timeout, 0);
            }

            AsyncConnect(addr, (endPoint, error) =>
            {
                if(hasDone)
                {
                    return;
                }
                hasDone = true;
                HandleMessage(new ConnectResult(ConnectionId, session, endPoint, error));
            }, session);
        }

        void AsyncConnect(string addr, Action<EndPoint, SocketError> handler, long session)
        {
            string[] parts = addr.Split(':');
            var socketEventArgs = new SocketAsyncEventArgs
            {
                UserToken = new UserTokenConnect()
                {
                    Handler = handler,
                    Sesson = session
                },
                RemoteEndPoint = new DnsEndPoint(parts[0], int.Parse(parts[1]))
            };

            socketEventArgs.Completed += IoCompleted;

            if (!_socket.ConnectAsync(socketEventArgs))
            {
                ProcessConnect(socketEventArgs);
            }
        }

        public void Close()
        {
            _socket.Close();
        }

        public void Send(Buffer data)
        {
            var len = (short)data.Count;
            len = IPAddress.HostToNetworkOrder(len);
            data.WriteFront(len);
            _sendQueue.Enqueue(data);
            StartSend();
        }

        void StartSend()
        {
            if(Interlocked.CompareExchange(ref _isSending, 1, 0) == 1)
            {
                return;
            }

            if (_sendQueue.TryDequeue(out Buffer data))
            {
                AsyncSend(data, (count, error) =>
                {
                    Interlocked.Exchange(ref _isSending, 0);
                    if (error != SocketError.Success)
                    {
                        HandleMessage(new AsyncResult(ConnectionId, error));
                        return;
                    }
                    StartSend();
                });
            }else{
                Interlocked.Exchange(ref _isSending, 0);
            }
        }

        void IoCompleted(object sender, SocketAsyncEventArgs e)
        {
            switch (e.LastOperation)
            {
                case SocketAsyncOperation.Connect:
                    ProcessConnect(e);
                    break;
                case SocketAsyncOperation.Receive:
                    ProcessReceive();
                    break;
                case SocketAsyncOperation.Send:
                    ProcessSend();
                    break;
                default:
                    throw new InvalidOperationException("Unexpected SocketAsyncOperation.");
            }
        }

        void ProcessConnect(SocketAsyncEventArgs e)
        {
            var connectUserToken = e.UserToken as UserTokenConnect;
            if(e.SocketError != SocketError.Success)
            {
                connectUserToken.Handler(null, e.SocketError);
                return;
            }
            connectUserToken.Handler(e.RemoteEndPoint, e.SocketError);

            _rsaea = new SocketAsyncEventArgs()
            {
                UserToken = new UserTokenRead()
            };
            _rsaea.Completed += IoCompleted;

            _wsaea = new SocketAsyncEventArgs()
            {
                UserToken = new UserTokenWrite()
            };
            _wsaea.Completed += IoCompleted;

            ReadHeader();
        }

        void ProcessReceive()
        {
            var userToken = _rsaea.UserToken as UserTokenRead;
            if (_rsaea.SocketError != SocketError.Success)
            {
                userToken.Handler(_rsaea.BytesTransferred, _rsaea.SocketError);
                return;
            }

            // If no data was received, close the connection. This is a NORMAL
            // situation that shows when the client has finished sending data.
            if (_rsaea.BytesTransferred == 0)
            {
                userToken.Handler(_rsaea.BytesTransferred, SocketError.Shutdown);
                return;
            }

            userToken.Buffer.Commit(_rsaea.BytesTransferred);
            userToken.ModeCount -= _rsaea.BytesTransferred;

            if (userToken.ModeCount <= 0)
            {
                userToken.Handler(userToken.Buffer.Count, SocketError.Success);
            }
            else
            {
                AsyncRead(userToken.Buffer, userToken.Mode, userToken.ModeCount, userToken.Handler);
            }
        }

        void ProcessSend()
        {
            var userToken = _wsaea.UserToken as UserTokenWrite;
            if (_wsaea.SocketError != SocketError.Success)
            {
                //If we are in this else-statement, there was a socket error.
                userToken.Handler(0, _wsaea.SocketError);
                return;
            }

            userToken.Buffer.Consume(_wsaea.BytesTransferred);

            if (userToken.Buffer.Count > 0)
            {
                //If some of the bytes in the message have NOT been sent,
                //then we will need to post another send operation.
                //So let's loop back to StartAsyncSend().
                AsyncSend(userToken.Buffer, userToken.Handler);
                return;
            }

            userToken.Handler(userToken.Buffer.Count, SocketError.Success);
        }

        void AsyncRead(Buffer stream, ReadMode mode, int count, Action<int, SocketError> handler)
        {
            var userToken = _rsaea.UserToken as UserTokenRead;
            userToken.Buffer = stream;
            userToken.ModeCount = count;
            userToken.Mode = mode;
            userToken.Handler = handler;

            if (mode == ReadMode.AtLeast)
            {
                if(userToken.Buffer.WriteAbleSize() < count){
                    userToken.Buffer.Prepare(Math.Max(128, count));
                }
                count = userToken.Buffer.WriteAbleSize();
            }
            else
            {
                userToken.Buffer.Prepare(count);
            }

            _rsaea.SetBuffer(userToken.Buffer.Data, userToken.Buffer.WritePos, count);
            if (!_socket.ReceiveAsync(_rsaea))
            {
                ProcessReceive();
            }
        }

        void AsyncSend(Buffer buffer, Action<int, SocketError> handler)
        {
            var userToken = _wsaea.UserToken as UserTokenWrite;
            userToken.Buffer = buffer;
            userToken.Handler = handler;
            _wsaea.SetBuffer(buffer.Data, buffer.Index, buffer.Count);
            if (!_socket.SendAsync(_wsaea))
            {
                ProcessSend();
            }
        }

        void ReadHeader()
        {
            var userToken = _rsaea.UserToken as UserTokenRead;
            if (_readCache.Count >= sizeof(MessageHeaderType))
            {
                HandleHeader();
                return;
            }
            AsyncRead(_readCache, ReadMode.AtLeast, sizeof(MessageHeaderType), (count, error) =>
            {
                if (error != SocketError.Success)
                {
                    HandleMessage(new AsyncResult(ConnectionId, error));
                    return;
                }
                HandleHeader();
            });
        }

        void HandleHeader()
        {
            var header = _readCache.ReadUInt16();
            var size = (ushort)(((header & 0xFF) << 8) | (header >> 8));
            var fin = size != MessageHeaderType.MaxValue;
            ReadBody(size, fin);
        }

        void ReadBody(int count, bool fin)
        {
            if (null == _readData)
            {
                _readData = new Buffer(fin ? count : 5 * count);
            }

            // Calculate the difference between the cache size and the expected size
            var diff = _readCache.Count - count;
            var consumeSize = diff >= 0 ? count : _readCache.Count;
            _readData.Write(_readCache.Data, _readCache.Index, consumeSize);
            _readCache.Consume(consumeSize);
            if (diff >= 0)
            {
                HandleBody(fin);
                return;
            }
            _readCache.Clear();

            AsyncRead(_readData, ReadMode.Exactly, -diff, (c, error) =>
            {
                if (error != SocketError.Success)
                {
                    HandleMessage(new AsyncResult(ConnectionId, error));
                    return;
                }
                HandleBody(fin);
            });

        }

        void HandleBody(bool fin)
        {
            if (fin)
            {
                HandleMessage(new AsyncResult(ConnectionId, 0, _readData));
                _readData = null;
            }
            ReadHeader();
        }
    }
}

