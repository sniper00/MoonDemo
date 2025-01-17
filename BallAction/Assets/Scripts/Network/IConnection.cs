using System;
using System.Net;

namespace Moon
{
    public interface IConnection
    {
        void ConnectAsync(string addr, long session, long timeout);
        void Send(Buffer data);
        bool Connected();
        void Close();
    }
}

