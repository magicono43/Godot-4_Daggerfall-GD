"""Independent raw-record/ARCH3D audit of the selected original staircase."""
import json
from pathlib import Path
import struct
from inspect_data import bsa

project = Path(__file__).resolve().parents[1]
section = json.loads((project / 'sections/privateers_hold_opening.json').read_text())
entry = next(e for e in section['models'] if e['id'] == 'first_staircase')
rdb = bsa('BLOCKS.BSA')[section['source']['block']]
offset = entry['record_offset']
resource = struct.unpack_from('<I', rdb, offset + 21)[0]
index = struct.unpack_from('<H', rdb, resource + 12)[0]
model = rdb[20 + index * 8:25 + index * 8].decode()
assert model == entry['expected_model'] == '58008'
data = bsa('ARCH3D.BSA')[model]
point_start = struct.unpack_from('<I', data, 48)[0]
face = struct.unpack_from('<I', data, 60)[0]
risers = []
for i in range(struct.unpack_from('<I', data, 8)[0]):
    count = data[face]
    positions = []
    for j in range(count):
        pointer = struct.unpack_from('<I', data, face + 8 + j * 8)[0]
        positions.append(tuple(v / 256 for v in struct.unpack_from('<iii', data, point_start + pointer)))
    face += 8 + count * 8
    span = [max(v[c] for v in positions) - min(v[c] for v in positions) for c in range(3)]
    if span[2] == 0 and span[0] >= 48 and 5 <= span[1] <= 14:
        risers.append(span[1] * 0.025)
report = {
    'block': section['source']['block'], 'record_offset': offset, 'model': model,
    'position_native': struct.unpack_from('<iii', rdb, offset + 8),
    'rotation_native': struct.unpack_from('<iii', rdb, resource),
    'rise_metres': 256 * 0.025,
    'vertical_risers_metres': risers,
    'note': 'The original staircase has sloped treads as well as vertical risers; native collision is retained.'
}
(project / 'tests/stair_geometry.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
