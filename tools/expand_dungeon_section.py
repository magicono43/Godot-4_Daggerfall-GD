"""Author explicit full-location selections from the independent source inventory.

No source files are modified. Existing IDs/order and prototype grants survive.
Border assemblies are retained exactly, including disconnected pieces.
"""
import json
from audit_dungeon_layout import PROJECT, inventory


def expand():
    path = PROJECT / 'sections/privateers_hold_opening.json'
    section = json.loads(path.read_text())
    source = inventory()
    section['name'] = "Privateer's Hold complete original structural placements"
    section['source']['blocks'] = [{k: b[k] for k in ('name', 'x', 'z')} for b in source['blocks']]
    existing = {(e.get('block', section['source']['block']), e['record_offset'])
                for group in ('models', 'billboards', 'treasure_markers', 'static_loot')
                for e in section.get(group, [])}
    section.setdefault('static_loot', [])
    for block in source['blocks']:
        for obj in block['objects']:
            if (block['name'], obj['offset']) in existing:
                continue
            entry = {'id': f"{block['name'][:8].lower()}_r{obj['offset']}",
                     'block': block['name'], 'record_offset': obj['offset']}
            if obj['kind'] == 1:
                role = 'door' if obj['description'] in ('DOR', 'DDR', 'NEW', 'CAV') and obj['model'] != '72100' else 'geometry'
                if obj['description'] == 'EXT':
                    role = 'exit'
                # DFU explicitly excludes non-action tapestries from collision.
                collision = not (42500 <= int(obj['model']) <= 42571 and not obj.get('action', {}).get('flags'))
                entry.update(expected_model=obj['model'], role=role, collision=collision)
                section['models'].append(entry)
            elif obj['kind'] == 3:
                archive, record = obj['texture']
                if archive == 199:
                    if record == 19:
                        entry.update(expected_archive=199, expected_record=19)
                        section['static_loot'].append(entry)
                    continue
                entry.update(expected_archive=archive, expected_record=record, fps=12)
                section['billboards'].append(entry)
    section['prototype']['boundaries'] = []
    path.write_text(json.dumps(section, indent=2) + '\n')
    print({k: len(section[k]) for k in ('models', 'billboards', 'static_loot')})


if __name__ == '__main__':
    expand()
