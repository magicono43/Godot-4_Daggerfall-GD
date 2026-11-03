"""Independent fire/shock hands, missile and impact RGBA audit; sources are read-only."""
import configparser, hashlib, json, struct
from pathlib import Path

project = Path(__file__).resolve().parents[1]
config = configparser.ConfigParser()
config.read(project / 'data_source.cfg')
arena = Path(config['classic']['arena2'].strip('"'))
palette = (arena / 'ART_PAL.COL').read_bytes()[8:776]

def pin(w, h, pixels):
    rgba = b''.join(palette[c*3:c*3+3] + bytes([255 if c else 0]) for c in pixels)
    return {'pixels':[w,h], 'rgba_sha256':hashlib.sha256(rgba).hexdigest()}

result = {'hands':{}, 'sprites':{}}
for element, file, archive in [('fire','FIRE00C6.CIF',375), ('shock','SHOK00C6.CIF',378)]:
    data = (arena/file).read_bytes(); offset=0; frames=[]
    while offset < len(data):
        _,_,w,h,compression,length = struct.unpack_from('<hhHHHH',data,offset)
        assert compression==2 and 0<w<=320 and 0<h<=200
        cursor=offset+12; end=cursor+length; pixels=bytearray()
        while len(pixels)<w*h:
            code=data[cursor];cursor+=1
            if code>127:
                pixels.extend([data[cursor]]*(code-127));cursor+=1
            else:
                pixels.extend(data[cursor:cursor+code+1]);cursor+=code+1
            assert cursor<=end and len(pixels)<=w*h
        assert cursor==end
        frames.append(pin(w,h,pixels));offset=end
    assert len(frames)==6 and offset==len(data)
    result['hands'][element]=frames
    data=(arena/f'TEXTURE.{archive}').read_bytes()
    for record in [0,1]:
        p=struct.unpack_from('<I',data,28+record*20)[0]
        w,h,compression=struct.unpack_from('<HHH',data,p+4)
        start=p+struct.unpack_from('<I',data,p+14)[0]
        count=struct.unpack_from('<H',data,p+20)[0]
        sx,sy=struct.unpack_from('<hh',data,p+24)
        assert compression in (0,0x900)
        frames=[]
        for frame in range(count):
            pixels=bytearray(w*h)
            if count==1:
                for y in range(h): pixels[y*w:(y+1)*w]=data[start+y*256:start+y*256+w]
            else:
                cursor=start+struct.unpack_from('<I',data,start+frame*4)[0]
                fw,fh=struct.unpack_from('<HH',data,cursor);cursor+=4
                assert fw<=w and fh<=h
                for y in range(fh):
                    x=0
                    while x<fw:
                        skip,n=data[cursor:cursor+2];cursor+=2
                        assert skip+n and x+skip+n<=fw
                        x+=skip;pixels[y*w+x:y*w+x+n]=data[cursor:cursor+n];cursor+=n;x+=n
            frames.append(pin(w,h,pixels))
        result['sprites'][f'{element}:{record}']={'archive':archive,'record':record,'metres':[(w+int(w*sx/256))*.025,(h+int(h*sy/256))*.025],'frames':frames}
(project/'tests/offensive_frames.json').write_text(json.dumps(result,indent=2)+'\n')
print('Pinned12 elemental hands and',sum(len(v['frames']) for v in result['sprites'].values()),'projectile/impact frames')
