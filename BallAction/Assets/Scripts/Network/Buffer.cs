using System;
using System.Text;

namespace Moon
{
    public class Buffer
    {
        int capacity = 0;
        readonly int headreserved = 0;

        public byte[] Data { get; private set; }

        /// <summary>
        /// read pos
        /// </summary>
        public int Index { get;  set; } = 0;

        public int WritePos { get; private set; } = 0;

        /// <summary>
        /// readable size
        /// </summary>
        public int Count { get { return WritePos - Index; } }

        public Buffer(int capacity = 248, int headreserved = 8)
        {
            WritePos = Index = headreserved;
            this.capacity = capacity + headreserved;
            this.capacity = NextPowOf2(this.capacity);
            this.headreserved = headreserved;
            Data = new byte[this.capacity];
        }

        public Buffer(byte[] data, int index, int count)
        {
            headreserved = index;
            Index = index;
            WritePos = index + count;
            capacity = count + headreserved;
            Data = data;
        }

        public void Write(short value)
        {
            Prepare(sizeof(short));
            Data[WritePos++] = (byte)(value & 0xFF);
            Data[WritePos++] = (byte)((value >> 8) & 0xFF);
        }

        public void Write(ushort value)
        {
            Write((short)value);
        }

        public void Write(int value)
        {
            Prepare(sizeof(int));
            Data[WritePos++] = (byte)(value & 0xFF);
            Data[WritePos++] = (byte)((value >> 8) & 0xFF);
            Data[WritePos++] = (byte)((value >> 16) & 0xFF);
            Data[WritePos++] = (byte)((value >> 24) & 0xFF);
        }

        public void Write(uint value)
        {
            Write((int)value);
        }

        public void Write(long value)
        {
            Prepare(sizeof(long));
            Data[WritePos++] = (byte)(value & 0xFF);
            Data[WritePos++] = (byte)((value >> 8) & 0xFF);
            Data[WritePos++] = (byte)((value >> 16) & 0xFF);
            Data[WritePos++] = (byte)((value >> 24) & 0xFF);
            Data[WritePos++] = (byte)((value >> 32) & 0xFF);
            Data[WritePos++] = (byte)((value >> 40) & 0xFF);
            Data[WritePos++] = (byte)((value >> 48) & 0xFF);
            Data[WritePos++] = (byte)((value >> 56) & 0xFF);
        }

        public void Write(ulong value)
        {
            Write((long)value);
        }

        public void Write(byte[] value, int index, int len)
        {
            Prepare(len);
            System.Buffer.BlockCopy(value, index, Data, WritePos, len);
            WritePos += len;
        }

        public void Write(string value)
        {
            var b = Encoding.Default.GetBytes(value);
            Prepare(b.Length);
            System.Buffer.BlockCopy(b, 0, Data, WritePos, b.Length);
            WritePos += b.Length;
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

        public int WriteAbleSize()
        {
            return capacity - WritePos;
        }

        public void Prepare(int need)
        {
            if (WriteAbleSize() < need)
            {
                Grow(need);
            }
        }

        public void Commit(int offset)
        {
            WritePos += offset;
            if (WritePos > capacity)
            {
                WritePos = capacity;
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
            if (WriteAbleSize() + Index < need + headreserved)
            {
                int size = WritePos + need;
                size = NextPowOf2(size);
                var newdata = new byte[size];
                System.Buffer.BlockCopy(Data, 0, newdata, 0, WritePos);
                capacity = size;
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
                WritePos = Index + readable;
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

        public string GetString()
        {
            return Encoding.Default.GetString(Data, Index, Count);
        }
    };
}
