"""Read-only independent WEAPON02.CIF audit: native sizes and RGBA fingerprints."""
import configparser, hashlib, json, struct
from pathlib import Path
PROJECT = Path(__file__).resolve().parents[1]
cfg = configparser.ConfigParser(); cfg.read(PROJECT / 'data_source.cfg')
root = Path(cfg['classic']['arena2'].strip('"'))
data = (root / 'WEAPON02.CIF').read_bytes()
palette = (root / 'ART_PAL.COL').read_bytes()[8:776]
result = []
def pin(w, h, frames):
    hashes, zeros = [], []
    for pixels in frames:
        rgba = b''.join(palette[c*3:c*3+3] + bytes([255 if c else 0]) for c in pixels)
        hashes.append(hashlib.sha256(rgba).hexdigest()); zeros.append(pixels.count(0))
    result.append({'pixels': [w,h], 'rgba_sha256': hashes, 'transparent_pixels': zeros})
x,y,w,h,compression,length = struct.unpack_from('<hhhhHH',data)
assert compression == 0 and length == w*h
pin(w,h,[data[12:12+length]])
offset = 12+length
for record in range(1,7):
    w,h = struct.unpack_from('<HH',data,offset)
    starts = [v for v in struct.unpack_from('<31H',data,offset+12) if v]
    total = struct.unpack_from('<H',data,offset+74)[0]
    assert len(starts)==5
    frames=[]
    for i,start in enumerate(starts):
        cursor=offset+start; end=offset+(starts[i+1] if i<4 else total)
        pixels=bytearray()
        while len(pixels)<w*h:
            code=data[cursor]; cursor+=1
            if code>127:
                pixels.extend([data[cursor]]*(code-127)); cursor+=1
            else:
                pixels.extend(data[cursor:cursor+code+1]); cursor+=code+1
            assert cursor<=end and len(pixels)<=w*h
        frames.append(pixels)
    pin(w,h,frames);offset+=total
assert offset==len(data)
target=PROJECT/'tests'/'weapons';target.mkdir(exist_ok=True)
(target/'dagger_frames.json').write_text(json.dumps({'file':'WEAPON02.CIF','file_sha256':hashlib.sha256(data).hexdigest(),'records':result},indent=2)+'\n')
print('Pinned dagger:',len(result),'records,',sum(len(x['rgba_sha256']) for x in result),'frames')
