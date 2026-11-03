"""Read-only Privateer's Hold source inventory; does not establish reachability."""
import collections
import hashlib
import json
import pathlib
import struct

from inspect_data import bsa

PROJECT = pathlib.Path(__file__).resolve().parents[1]


def inventory():
    maps = bsa('MAPS.BSA')
    blocks = bsa('BLOCKS.BSA')
    section = json.loads((PROJECT / 'sections/privateers_hold_opening.json').read_text())
    selected = {(v.get('block', section['source']['block']), v['record_offset'])
                for v in section['models']}
    data = maps['MAPDITEM.017']
    count, = struct.unpack_from('<I', data)
    result = {'blocks': [], 'selected_models': len(selected)}
    for i in range(count):
        offset, = struct.unpack_from('<I', data, 4 + i * 8)
        p = 4 + count * 8 + offset
        h = p + 4 + struct.unpack_from('<I', data, p)[0] * 6
        name = data[h + 71:h + 103].split(b'\0')[0].decode()
        if name != "Privateer's Hold":
            continue
        result['location'] = name
        result['map_sha256'] = hashlib.sha256(data).hexdigest()
        for j in range(struct.unpack_from('<H', data, h + 122)[0]):
            x, z, bits = struct.unpack_from('<bbH', data, h + 129 + j * 4)
            block = f'{"NWLSBM"[bits >> 11]}{bits & 1023:07}.RDB'
            raw = blocks[block]
            entry = {'name': block, 'x': x, 'z': z, 'starting': bool(bits & 1024),
                     'sha256': hashlib.sha256(raw).hexdigest(), 'objects': []}
            roots, = struct.unpack_from('<I', raw, 12)
            seen = set()
            for root in range(struct.unpack_from('<I', raw, 4)[0] * struct.unpack_from('<I', raw, 8)[0]):
                q, = struct.unpack_from('<i', raw, roots + root * 4)
                chain = set()
                while q >= 0:
                    assert q not in chain and q + 25 <= len(raw)
                    chain.add(q)
                    assert q not in seen, 'Object referenced by multiple roots'
                    seen.add(q)
                    resource, = struct.unpack_from('<I', raw, q + 21)
                    obj = {'offset': q, 'kind': raw[q + 20],
                           'position_native': struct.unpack_from('<iii', raw, q + 8)}
                    if obj['kind'] == 1:
                        idx, = struct.unpack_from('<H', raw, resource + 12)
                        obj.update(model=raw[20 + idx * 8:25 + idx * 8].decode().strip('\0'),
                                   description=raw[25 + idx * 8:28 + idx * 8].decode().strip('\0'),
                                   angles=struct.unpack_from('<iii', raw, resource),
                                   selected=(block, q) in selected)
                        action, = struct.unpack_from('<i', raw, resource + 19)
                        if action > 0:
                            obj['action'] = dict(zip(('axis', 'duration', 'magnitude', 'next', 'flags'),
                                                     struct.unpack_from('<BHH i B', raw, action)))
                            obj['action'].update(trigger=struct.unpack_from('<I', raw, resource + 14)[0],
                                                 sound=raw[resource + 18])
                    elif obj['kind'] == 3:
                        texture, = struct.unpack_from('<H', raw, resource)
                        obj['texture'] = [texture >> 7, texture & 127]
                    entry['objects'].append(obj)
                    q, = struct.unpack_from('<i', raw, q)
            entry['counts'] = dict(collections.Counter(o['kind'] for o in entry['objects']))
            result['blocks'].append(entry)
        break
    assert result.get('location') and result['blocks']
    return result


if __name__ == '__main__':
    print(json.dumps(inventory(), indent=2))
