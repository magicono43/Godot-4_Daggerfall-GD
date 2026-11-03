"""Independent read-only casting CIF evidence. No source art is copied into the project."""
import configparser, hashlib, json, struct
from pathlib import Path

project = Path(__file__).resolve().parents[1]
config = configparser.ConfigParser()
config.read(project / 'data_source.cfg')
root = Path(config['classic']['arena2'].strip('"'))
data = (root / 'MJIC00C6.CIF').read_bytes()
palette = (root / 'ART_PAL.COL').read_bytes()[8:776]
records = []
offset = 0
while offset < len(data):
    x, y, w, h, compression, length = struct.unpack_from('<hhHHHH', data, offset)
    assert compression == 2 and 0 < w <= 320 and 0 < h <= 200
    end = offset + 12 + length
    cursor = offset + 12
    pixels = bytearray()
    while len(pixels) < w*h:
        code = data[cursor]; cursor += 1
        if code > 127:
            pixels.extend([data[cursor]] * (code-127)); cursor += 1
        else:
            pixels.extend(data[cursor:cursor+code+1]); cursor += code+1
        assert cursor <= end and len(pixels) <= w*h
    assert cursor == end
    rgba = b''.join(palette[c*3:c*3+3] + bytes([255 if c else 0]) for c in pixels)
    records.append({'pixels':[w,h], 'rgba_sha256':hashlib.sha256(rgba).hexdigest(), 'transparent_pixels':pixels.count(0)})
    offset = end
assert len(records) == 6 and offset == len(data)
target = project / 'tests' / 'magic_frames.json'
target.write_text(json.dumps({'file':'MJIC00C6.CIF', 'file_sha256':hashlib.sha256(data).hexdigest(), 'records':records}, indent=2)+'\n')
print('Pinned six original magic casting frames')
