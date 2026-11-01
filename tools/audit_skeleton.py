"""Independent Skeleton source headers, RGBA hashes and native dimensions; ARENA2 is read-only."""
import configparser
import hashlib
import json
import struct
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
cfg = configparser.ConfigParser()
cfg.read(PROJECT / 'data_source.cfg')
root = Path(cfg['classic']['arena2'].strip('"'))
palette = (root / 'ART_PAL.COL').read_bytes()[8:776]
result = {}
for archive, records in [(270, range(20)), (306, [1])]:
    data = (root / f'TEXTURE.{archive:03}').read_bytes()
    for record in records:
        p = struct.unpack_from('<I', data, 28 + record * 20)[0]
        w, h, compression = struct.unpack_from('<HHH', data, p + 4)
        start = p + struct.unpack_from('<I', data, p + 14)[0]
        frames = struct.unpack_from('<H', data, p + 20)[0]
        sx, sy = struct.unpack_from('<hh', data, p + 24)
        assert compression in (0, 0x900)
        hashes, transparent = [], []
        for frame in range(frames):
            indices = bytearray(w * h)
            if frames == 1:
                for y in range(h):
                    indices[y*w:(y+1)*w] = data[start+y*256:start+y*256+w]
            else:
                cursor = start + struct.unpack_from('<I', data, start + frame * 4)[0]
                fw, fh = struct.unpack_from('<HH', data, cursor)
                cursor += 4
                assert fw <= w and fh <= h
                for y in range(fh):
                    x = 0
                    while x < fw:
                        skip, count = data[cursor:cursor+2]
                        cursor += 2
                        assert skip + count and x + skip + count <= fw
                        x += skip
                        indices[y*w+x:y*w+x+count] = data[cursor:cursor+count]
                        cursor += count
                        x += count
            rgba = b''.join(palette[c*3:c*3+3] + bytes([255 if c else 0]) for c in indices)
            hashes.append(hashlib.sha256(rgba).hexdigest())
            transparent.append(indices.count(0))
        result[f'{archive}:{record}'] = {
            'pixels': [w, h], 'frames': frames,
            'metres': [(w + int(w*sx/256)) * 0.025, (h + int(h*sy/256)) * 0.025],
            'rgba_sha256': hashes, 'transparent_pixels': transparent}
target = PROJECT / 'tests' / 'enemies'
target.mkdir(exist_ok=True)
(target / 'skeleton_frames.json').write_text(json.dumps(result, indent=2) + '\n')
print('Pinned Skeleton:', len(result), 'records,', sum(x['frames'] for x in result.values()), 'frames')
