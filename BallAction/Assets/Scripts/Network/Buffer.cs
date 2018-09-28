using System;

namespace Moon
{
    public class Buffer
    {
        public byte[] Data { get; private set; }
        int wpos = 0;
        int totalcapacity = 0;
        readonly int headreserved = 0;

        public int Count { get { return wpos - Index; } }
        public int Index { get; private set; } = 0;

        public Buffer(int capacity = 248, int headreserved = 8)
        {
            wpos = Index = headreserved;
            totalcapacity = capacity + headreserved;
            totalcapacity = NextPowOf2(totalcapacity);
            this.headreserved = headreserved;
            Data = new byte[totalcapacity];
        }

        public void Write(short value)
        {
            CheckSize(sizeof(short));
            Data[wpos++] = (byte)(value & 0xFF);
            Data[wpos++] = (byte)((value >> 8) & 0xFF);
        }

        public void Write(ushort value)
        {
            Write((short)value);
        }

        public void Write(int value)
        {
            CheckSize(sizeof(int));
            Data[wpos++] = (byte)(value & 0xFF);
            Data[wpos++] = (byte)((value >> 8) & 0xFF);
            Data[wpos++] = (byte)((value >> 16) & 0xFF);
            Data[wpos++] = (byte)((value >> 24) & 0xFF);
        }

        public void Write(uint value)
        {
            Write((int)value);
        }

        public void Write(long value)
        {
            CheckSize(sizeof(long));
            Data[wpos++] = (byte)(value & 0xFF);
            Data[wpos++] = (byte)((value >> 8) & 0xFF);
            Data[wpos++] = (byte)((value >> 16) & 0xFF);
            Data[wpos++] = (byte)((value >> 24) & 0xFF);
            Data[wpos++] = (byte)((value >> 32) & 0xFF);
            Data[wpos++] = (byte)((value >> 40) & 0xFF);
            Data[wpos++] = (byte)((value >> 48) & 0xFF);
            Data[wpos++] = (byte)((value >> 56) & 0xFF);
        }

        public void Write(ulong value)
        {
            Write((long)value);
        }

        public void Write(byte[] value, int index, int len)
        {
            CheckSize(len);
            System.Buffer.BlockCopy(value, index, Data, wpos, len);
            wpos += len;
        }

        public void WriteFront(short value)
        {
            CheckFrontSize(sizeof(short));
            Index -= sizeof(short);
            Data[Index] = (byte)(value & 0xFF);
            Data[Index + 1] = (byte)((value >> 8) & 0xFF);
        }

        public void WriteFront(ushort value)
        {
            CheckFrontSize(sizeof(ushort));
            Index -= sizeof(ushort);
            Data[Index] = (byte)(value & 0xFF);
            Data[Index + 1] = (byte)((value >> 8) & 0xFF);
        }

        public short ReadInt16()
        {
            if (Count < sizeof(short))
            {
                throw new IndexOutOfRangeException("Buffer.ReadInt16");
            }
            int v1 = Data[Index++];
            int v2 = Data[Index++];

            var value = v1
                | (v2 << 8);
            return (short)value;
        }

        public ushort ReadUInt16()
        {
            return (ushort)ReadInt16();
        }

        public int ReadInt32()
        {
            if (Count < sizeof(int))
            {
                throw new IndexOutOfRangeException("Buffer.ReadInt32");
            }
            int v1 = Data[Index++];
            int v2 = Data[Index++];
            int v3 = Data[Index++];
            int v4 = Data[Index++];

            var value = v1
                | (v2 << 8)
                | (v3 << 16)
                | (v4 << 24);
            return value;
        }

        public uint ReadUInt32()
        {
            return (uint)ReadInt32();
        }

        public long ReadInt64()
        {
            if (Count < sizeof(long))
            {
                throw new IndexOutOfRangeException("Buffer.ReadInt64");
            }
            var low = (long)ReadInt32();
            var high = (long)ReadInt32();
            var value = low | (high << 32);
            return value;
        }

        public ulong ReadUInt64()
        {
            return (ulong)ReadInt64();
        }

        public void Read(byte[] buf, int index, int len)
        {
            if (Count < len)
            {
                throw new IndexOutOfRangeException("Buffer.Read");
            }
            System.Buffer.BlockCopy(Data, Index, buf, index, len);
            Index += len;
        }

        public int CanWriteSize()
        {
            return totalcapacity - wpos;
        }

        void CheckSize(int need)
        {
            if (CanWriteSize() < need)
            {
                Grow(need);
            }
        }

        void CheckFrontSize(long need)
        {
            if (Index < need)
            {
                throw new IndexOutOfRangeException("Buffer.CheckFrontSize");
            }
        }

        void Grow(int need)
        {
            if (CanWriteSize() + Index < need + headreserved)
            {
                int size = wpos + need;
                size = NextPowOf2(size);
                var newdata = new byte[size];
                System.Buffer.BlockCopy(Data, 0, newdata, 0, wpos);
                totalcapacity = size;
                Data = newdata;
            }
            else
            {
                int readable = Count;
                if (readable != 0)
                {
                    System.Buffer.BlockCopy(Data, Index, Data, headreserved, readable);
                }
                Index = headreserved;
                wpos = Index + readable;
            }
        }

        int NextPowOf2(int x)
        {
            if (0 == (x & (x - 1)))
            {
                return x;
            }
            x |= x >> 1;
            x |= x >> 2;
            x |= x >> 4;
            x |= x >> 8;
            x |= x >> 16;
            return x + 1;
        }
    };
}
