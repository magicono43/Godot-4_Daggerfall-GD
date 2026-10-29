import struct, pathlib
ROOT=pathlib.Path(r'C:\Games\Daggerfall\arena2')
def bsa(name):
 d=(ROOT/name).read_bytes(); n,t=struct.unpack_from('<HH',d); size=18 if t==256 else 8; off=4; out={}
 for i in range(n):
  q=len(d)-n*size+i*size
  key=d[q:q+14].split(b'\0')[0].decode() if t==256 else str(struct.unpack_from('<I',d,q)[0])
  length=struct.unpack_from('<I',d,q+size-4)[0]; out[key]=d[off:off+length]; off+=length
 return out
if __name__=='__main__':
 maps=bsa('MAPS.BSA'); print(list(maps)[:12])
 for k,d in maps.items():
  pos=d.lower().find(b'privateer')
  if pos>=0: print(k,len(d),pos,d[max(0,pos-16):pos+100])
