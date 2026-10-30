"""Pin decoded material identities/pixels for the supplied Classic dungeon fixture.

Expected archive swaps are from DFU's Classic table at dungeon seed 50050;
they deliberately do not call or parse the GDScript texture implementation.
"""
import hashlib
import json
from pathlib import Path
import struct

from inspect_data import ROOT, bsa

PROJECT = Path(__file__).resolve().parents[1]
EXPECTED_SWAPS = {119: 23, 120: 22, 122: 19, 123: 22, 124: 20, 168: 368, 74: 374}
section = json.loads((PROJECT / 'sections' / 'privateers_hold_opening.json').read_text())
MODELS = list(dict.fromkeys(entry['expected_model'] for entry in section['models']))
palette = (ROOT / 'ART_PAL.COL').read_bytes()[8:776]

def decode(archive, record):
    if archive in (0, 1):
        colour = record + 128 * archive
        return (32, 32), palette[colour * 3:colour * 3 + 3] * 1024
    data = (ROOT / f'TEXTURE.{archive:03}').read_bytes()
    header = struct.unpack_from('<I', data, 28 + record * 20)[0]
    width, height, compression = struct.unpack_from('<HHH', data, header + 4)
    start = header + struct.unpack_from('<I', data, header + 14)[0]
    assert struct.unpack_from('<H', data, header + 20)[0] == 1
    pixels = bytearray()
    if compression in (0, 0x900):
        for row in range(height):
            pixels.extend(data[start + row * 256:start + row * 256 + width])
    else:
        assert compression in (0x108, 0x1108)
        for row in range(height):
            offset, encoding = struct.unpack_from('<hH', data, start + row * 4)
            pos = header + offset
            if encoding != 0x8000:
                pixels.extend(data[pos:pos + width])
                continue
            row_width = struct.unpack_from('<H', data, pos)[0]
            pos += 2
            values = bytearray()
            while len(values) < row_width:
                count = struct.unpack_from('<h', data, pos)[0]
                pos += 2
                assert count
                if count < 0:
                    values.extend([data[pos]] * -count)
                    pos += 1
                else:
                    values.extend(data[pos:pos + count])
                    pos += count
            assert len(values) == width
            pixels.extend(values)
    assert len(pixels) == width * height
    return (width, height), b''.join(palette[c * 3:c * 3 + 3] for c in pixels)

models = bsa('ARCH3D.BSA')
sources = set()
for model in MODELS:
    data = models[model]
    face = struct.unpack_from('<I', data, 60)[0]
    for _ in range(struct.unpack_from('<I', data, 8)[0]):
        sources.add(struct.unpack_from('<H', data, face + 2)[0])
        face += 8 + data[face] * 8
fixture = []
for source in sorted(sources):
    archive, record = source >> 7, source & 127
    target = EXPECTED_SWAPS.get(archive, archive)
    source_size, _ = decode(archive, record)
    target_size, pixels = decode(target, record)
    fixture.append({'source': source, 'resolved': (target << 7) | record,
                    'source_size': source_size, 'target_size': target_size,
                    'rgb_sha256': hashlib.sha256(pixels).hexdigest()})
folder = PROJECT / 'tests' / 'texture_fidelity'
folder.mkdir(exist_ok=True)
(folder / 'classic_materials.json').write_text(json.dumps(fixture, indent=2) + '\n')
print(f'{len(fixture)} original material slots pinned to Classic archives and RGB hashes')
for case in fixture:
    print(f"{case['source'] >> 7}:{case['source'] & 127} -> {case['resolved'] >> 7}:{case['resolved'] & 127}")
