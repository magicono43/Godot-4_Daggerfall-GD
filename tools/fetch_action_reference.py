"""Cache missing action references at the existing project revision."""
import hashlib
import json
from pathlib import Path
import urllib.request

root = Path(__file__).resolve().parents[1] / 'reference'
revision = json.loads((root / 'movement_sources.json').read_text())['commit']
paths = ['Assets/Scripts/API/DFBlock.cs', 'Assets/Scripts/Internal/DaggerfallAction.cs']
report = {'repository': 'https://github.com/Interkarma/daggerfall-unity',
          'commit': revision, 'license': 'LICENSE.txt', 'files': {}}
for path in paths:
    data = urllib.request.urlopen(f'https://raw.githubusercontent.com/Interkarma/daggerfall-unity/{revision}/{path}').read()
    (root / Path(path).name).write_bytes(data)
    report['files'][path] = hashlib.sha256(data).hexdigest()
for name in ['RDBLayout.cs', 'BlocksFile.cs', 'DaggerfallAudioSource.cs']:
    report.setdefault('cached_dependencies', {})[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
(root / 'action_sources.json').write_text(json.dumps(report, indent=2) + '\n')
print('Pinned action references:', revision)
