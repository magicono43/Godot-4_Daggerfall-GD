"""Save a commit-pinned, read-only DFU movement reference snapshot and hashes."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1] / 'reference'
REPO = 'https://github.com/Interkarma/daggerfall-unity'
paths = [
    'Assets/Scripts/Game/PlayerMotor.cs',
    'Assets/Scripts/Game/InputManager.cs',
    'Assets/Scripts/Game/Player/PlayerSpeedChanger.cs',
    'Assets/Scripts/Game/Player/AcrobatMotor.cs',
    'Assets/Scripts/Game/Player/FrictionMotor.cs',
    'Assets/Scripts/Game/Player/PlayerGroundMotor.cs',
    'Assets/Scripts/Game/Player/PlayerMoveScanner.cs',
    'Assets/Scripts/Game/Player/ClimbingMotor.cs',
    'Assets/Scripts/Game/LevitateMotor.cs',
]
manifest = ROOT / 'movement_sources.json'
existing = json.loads(manifest.read_text()) if manifest.exists() else {}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--revision', default=existing.get('commit', 'master'), help='Defaults to saved commit; use master to update deliberately.')
args = parser.parse_args()
commit = json.load(urllib.request.urlopen(f'https://api.github.com/repos/Interkarma/daggerfall-unity/commits/{args.revision}'))
report = {'repository': REPO, 'commit': commit['sha'], 'commit_date': commit['commit']['committer']['date'], 'files': {}}
for path in paths:
    data = urllib.request.urlopen(f'https://raw.githubusercontent.com/Interkarma/daggerfall-unity/{commit["sha"]}/{path}').read()
    (ROOT / Path(path).name).write_bytes(data)
    report['files'][path] = hashlib.sha256(data).hexdigest()
(ROOT / 'movement_sources.json').write_text(json.dumps(report, indent=2) + '\n')
print('DFU movement snapshot:', report['commit'])
