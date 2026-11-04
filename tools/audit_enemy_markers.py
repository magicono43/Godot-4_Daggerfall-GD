"""Read-only linked-record enemy audit; no scene changes or reachability claims."""
import collections
import hashlib
import json
import struct

from audit_dungeon_layout import PROJECT, inventory
from inspect_data import bsa


def audit():
    layout = inventory()
    blocks = bsa('BLOCKS.BSA')
    result = {'location': layout['location'], 'map_sha256': layout['map_sha256'],
              'source_commit': '4e78e1412b17b60f4d5d6073825775aa5ae95139',
              'source_sha256': {name: hashlib.sha256((PROJECT / 'reference' / name).read_bytes()).hexdigest()
                                for name in ('RDBLayout.cs', 'BlocksFile.cs', 'DFBlock.cs', 'EnemyBasics.cs')},
              'blocks': []}
    for block in layout['blocks']:
        raw = blocks[block['name']]
        entry = {k: block[k] for k in ('name', 'x', 'z', 'starting', 'sha256')}
        entry.update(markers=[], other_editor_records={})
        others = collections.Counter()
        for obj in block['objects']:
            if obj.get('texture', [0])[0] != 199:
                continue
            record = obj['texture'][1]
            if record not in (15, 16):
                others[record] += 1
                continue
            q = obj['offset']
            resource, = struct.unpack_from('<I', raw, q + 21)
            texture, flags, magnitude, sound, next_offset, action = struct.unpack_from('<HHBBiB', raw, resource)
            x, y, z = obj['position_native']
            entry['markers'].append(dict(id=f"{block['name']}:{q}", record_offset=q,
                resource_offset=resource, texture=[texture >> 7, texture & 127],
                kind='fixed' if record == 16 else 'random', flags=flags,
                magnitude=magnitude, sound_index=sound, faction_or_mobile_id=magnitude + 256 * sound,
                mobile_id=magnitude if record == 16 else None,
                encounter_slot=flags if record == 15 else None,
                next_object_offset=next_offset, action=action,
                reaction='passive' if action == 99 else 'hostile',
                position_native=[x, y, z],
                position_grid_native=[x + block['x'] * 2048, y, z + block['z'] * 2048]))
        entry['other_editor_records'] = dict(sorted(others.items()))
        entry['counts'] = dict(collections.Counter(m['kind'] for m in entry['markers']))
        result['blocks'].append(entry)
    result['totals'] = dict(collections.Counter(m['kind'] for b in result['blocks'] for m in b['markers']))
    result['fixed_mobile_counts'] = dict(collections.Counter(m['mobile_id'] for b in result['blocks']
                                                           for m in b['markers'] if m['kind'] == 'fixed'))
    monster = bsa('MONSTER.BSA')['ENEMY000.CFG']
    result['rat_career'] = {'record': 'ENEMY000.CFG', 'sha256': hashlib.sha256(monster).hexdigest(),
                            'attributes': dict(zip(('strength', 'intelligence', 'willpower', 'agility',
                                                    'endurance', 'personality', 'speed', 'luck'),
                                                   struct.unpack_from('<8H', monster, 58)))}
    return result


if __name__ == '__main__':
    result = audit()
    target = PROJECT / 'tests/output/enemy_marker_audit.json'
    target.parent.mkdir(exist_ok=True)
    target.write_text(json.dumps(result, indent=2) + '\n')
    for block in result['blocks']:
        print(block['name'], (block['x'], block['z']), block['counts'])
        for marker in block['markers']:
            print(' ', marker['record_offset'], marker['kind'], 'mobile', marker['mobile_id'],
                  'slot', marker['encounter_slot'], 'flags', marker['flags'],
                  'sound', marker['sound_index'], 'action', marker['action'], marker['position_native'])
