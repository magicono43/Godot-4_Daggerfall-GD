"""Read-only listing of original opening-block decoration candidates."""
import struct
from inspect_data import ROOT, bsa

data = bsa('BLOCKS.BSA')['S0000999.RDB']
for offset in [16459, 16495, 17044, 32552, 32623]:
    x, y, z = struct.unpack_from('<iii', data, offset + 8)
    kind = data[offset + 20]
    resource = struct.unpack_from('<I', data, offset + 21)[0]
    print(offset, (x, y, z), 'type', kind)
    if kind == 3:
        texture = struct.unpack_from('<H', data, resource)[0]
        archive, record = texture >> 7, texture & 127
        image = (ROOT / f'TEXTURE.{archive:03}').read_bytes()
        p = struct.unpack_from('<I', image, 28 + record * 20)[0]
        print('  texture', archive, record, 'header', struct.unpack_from('<5hII5h', image, p))
    else:
        index = struct.unpack_from('<H', data, resource + 12)[0]
        print('  model', data[20 + index * 8:28 + index * 8])
