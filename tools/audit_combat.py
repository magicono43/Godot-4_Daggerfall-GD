"""Independent original MONSTER.BSA career and pinned combat source evidence."""
import configparser
import hashlib
import json
import struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
cfg = configparser.ConfigParser()
cfg.read(ROOT / 'data_source.cfg', encoding='utf-8-sig')
arena = Path(cfg['classic']['arena2'].strip('"'))
data = (arena / 'MONSTER.BSA').read_bytes()
count, kind = struct.unpack_from('<HH', data)
assert kind == 256
start = 4
career = None
bear_career = None
for i in range(count):
    pos = len(data) - count * 18 + i * 18
    name = data[pos:pos+14].split(b'\0')[0].decode('ascii')
    size = struct.unpack_from('<I', data, pos+14)[0]
    if name in ('ENEMY015.CFG', 'ENEMY004.CFG'):
        raw = data[start:start+size]
        attrs = struct.unpack_from('<8H', raw, 58)
        record = dict(record=name, size=size, sha256=hashlib.sha256(raw).hexdigest(), attributes=dict(zip(['strength','intelligence','willpower','agility','endurance','personality','speed','luck'], attrs)))
        if name == 'ENEMY015.CFG': career = record
        else: bear_career = record
    start += size
assert career and bear_career
out = dict(skeleton=career, bear=bear_career, level=9, skills=75, armor_to_hit=10, min_damage=5, max_damage=15)
(ROOT / 'tests/combat_source.json').write_text(json.dumps(out, indent=2)+'\n')
paths = ['FormulaHelper.cs','WeaponManager.cs','EnemyAttack.cs','EnemyBasics.cs','EnemyEntity.cs','PlayerEntity.cs','DaggerfallStats.cs','DaggerfallSkills.cs','DaggerfallEntity.cs','DaggerfallUnityItem.cs','ItemEquipTable.cs','Dice100.cs','PaperDoll.cs','ItemBuilder.cs','ItemHelper.cs','ItemTemplates.txt','WeaponBasics.cs','EnemySounds.cs','SoundClips.cs','MonsterFile.cs','ClassFile.cs','DFCareer.cs']
manifest = dict(repository='https://github.com/Interkarma/daggerfall-unity', commit='4e78e1412b17b60f4d5d6073825775aa5ae95139', files={p:hashlib.sha256((ROOT/'reference'/p).read_bytes()).hexdigest() for p in paths}, notes=['Subset: steel/other supported material modifiers, seven weighted hit regions, skeleton career from external MONSTER.BSA; no career advantages, progression, shields or durability.', 'PaperDoll displays (100-armor_to_hit)/5, a protection number where higher is better; raw defensive armor_to_hit is lower-is-better.', 'Skeleton parry bank uses Parry1+Random.Range(0,9), ordinal 428 through 436.'])
(ROOT/'reference/combat_resolution_sources.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(out))

