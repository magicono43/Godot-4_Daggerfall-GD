"""Read-only nearby RDB model listing; quarter-turn transformed native bounds."""
import math
import struct
from inspect_data import bsa

rdb = bsa('BLOCKS.BSA')['S0000999.RDB']
models = bsa('ARCH3D.BSA')
roots = struct.unpack_from('<I', rdb, 12)[0]
seen = set()
for i in range(struct.unpack_from('<I', rdb, 4)[0] * struct.unpack_from('<I', rdb, 8)[0]):
    q = struct.unpack_from('<i', rdb, roots + i * 4)[0]
    while q > 0 and q not in seen:
        seen.add(q)
        x, y, z = struct.unpack_from('<iii', rdb, q + 8)
        resource = struct.unpack_from('<I', rdb, q + 21)[0]
        if rdb[q + 20] == 1 and 300 <= x <= 1800 and -1000 <= z <= 1100 and -1000 <= y <= 200:
            index = struct.unpack_from('<H', rdb, resource + 12)[0]
            name = rdb[20 + index * 8:25 + index * 8].decode()
            angles = struct.unpack_from('<iii', rdb, resource)
            data = models[name]
            count = struct.unpack_from('<I', data, 4)[0]
            start = struct.unpack_from('<I', data, 48)[0]
            points = [struct.unpack_from('<iii', data, start + n * 12) for n in range(count)]
            a = angles[1] * math.tau / 2048
            transformed = [(x + (p[0]*math.cos(a)-p[2]*math.sin(a))/256, y+p[1]/256, z+(p[0]*math.sin(a)+p[2]*math.cos(a))/256) for p in points]
            low = [round(min(p[c] for p in transformed), 2) for c in range(3)]
            high = [round(max(p[c] for p in transformed), 2) for c in range(3)]
            print(q, name, (x,y,z), angles, 'bounds', low, high)
        q = struct.unpack_from('<i', rdb, q)[0]
