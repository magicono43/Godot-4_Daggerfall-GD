"""Independent original-flat positions, dimensions and RGBA frame fingerprints."""
import hashlib
import json
import struct
from pathlib import Path
from inspect_data import ROOT, bsa

PROJECT = Path(__file__).resolve().parents[1]
section = json.loads((PROJECT / 'sections' / 'privateers_hold_opening.json').read_text())
block = bsa('BLOCKS.BSA')[section['source']['block']]
palette = (ROOT / 'ART_PAL.COL').read_bytes()[8:776]
fixture = {}
for entry in section['billboards']:
    offset = entry['record_offset']
    assert block[offset + 20] == 3
    position = struct.unpack_from('<iii', block, offset + 8)
    resource = struct.unpack_from('<I', block, offset + 21)[0]
    texture = struct.unpack_from('<H', block, resource)[0]
    archive, record = texture >> 7, texture & 127
    assert (archive, record) == (entry['expected_archive'], entry['expected_record'])
    data = (ROOT / f'TEXTURE.{archive:03}').read_bytes()
    p = struct.unpack_from('<I', data, 28 + record * 20)[0]
    w, h, compression = struct.unpack_from('<HHH', data, p + 4)
    start = p + struct.unpack_from('<I', data, p + 14)[0]
    frames = struct.unpack_from('<H', data, p + 20)[0]
    sx, sy = struct.unpack_from('<hh', data, p + 24)
    assert compression in (0, 0x900), 'These selected flats use single-frame or animated uncompressed records'
    hashes = []
    transparent_counts = []
    for frame in range(frames):
        indices = bytearray(w * h)
        if frames == 1:
            for row in range(h):
                indices[row * w:(row + 1) * w] = data[start + row * 256:start + row * 256 + w]
        else:
            cursor = start + struct.unpack_from('<I', data, start + frame * 4)[0]
            fw, fh = struct.unpack_from('<HH', data, cursor)
            cursor += 4
            assert fw <= w and fh <= h
            for row in range(fh):
                x = 0
                while x < fw:
                    skip, count = data[cursor:cursor + 2]
                    cursor += 2
                    assert skip + count and x + skip + count <= fw
                    x += skip
                    indices[row * w + x:row * w + x + count] = data[cursor:cursor + count]
                    cursor += count
                    x += count
        rgba = b''.join(palette[c * 3:c * 3 + 3] + bytes([255 if c else 0]) for c in indices)
        hashes.append(hashlib.sha256(rgba).hexdigest())
        transparent_counts.append(indices.count(0))
    fixture[entry['id']] = {
        'native_position': position, 'archive': archive, 'record': record,
        'pixel_size': [w, h],
        'size_metres': [(w + int(w * sx / 256)) * 0.025, (h + int(h * sy / 256)) * 0.025],
        'rgba_sha256': hashes, 'transparent_pixels': transparent_counts
    }
target = PROJECT / 'tests' / 'decorations'
target.mkdir(exist_ok=True)
(target / 'billboard_frames.json').write_text(json.dumps(fixture, indent=2) + '\n')
print('Pinned static + animated flat frames:', {key: len(value['rgba_sha256']) for key, value in fixture.items()})
