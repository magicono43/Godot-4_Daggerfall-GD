"""Independent read-only measurement of raw ARCH3D points for calibration tests."""
import configparser
import json
import math
from pathlib import Path
import re
import struct

from inspect_data import bsa

PROJECT = Path(__file__).resolve().parents[1]
reference = PROJECT / 'reference'
scale = float(re.search(r'GlobalScale = ([\d.]+)f', (reference / 'MeshReader.cs').read_text()).group(1))
divisor = float(re.search(r'pointDivisor = ([\d.]+)f', (reference / 'Arch3dFile.cs').read_text()).group(1))
height_source = (reference / 'PlayerHeightChanger.cs').read_text()
height = float(re.search(r'controllerStandingHeight = ([\d.]+)f', height_source).group(1))
eye_inset = float(re.search(r'eyeHeight = ([\d.]+)f', height_source).group(1))
radius = float(re.search(r'm_Radius: ([\d.]+)', (reference / 'PlayerAdvanced.prefab').read_text()).group(1))
settings = configparser.ConfigParser()
settings.read(PROJECT / '--Bug_Fixing_Evidence--' / 'Scale_Inconsistency_Examples_10-29-2026' / 'Daggerfall Unity Images' / 'DFU_Video_Settings.txt')
fov = settings.getfloat('Video', 'FieldOfView')
models = bsa('ARCH3D.BSA')
measurements = {}
section = json.loads((PROJECT / 'sections' / 'privateers_hold_opening.json').read_text())
for model in dict.fromkeys(entry['expected_model'] for entry in section['models']):
    data = models[model]
    count = struct.unpack_from('<I', data, 4)[0]
    point_start = struct.unpack_from('<I', data, 48)[0]
    points = [struct.unpack_from('<iii', data, point_start + i * 12) for i in range(count)]
    converted = [(x * scale / divisor, -y * scale / divisor, -z * scale / divisor) for x, y, z in points]
    low = [min(p[c] for p in converted) for c in range(3)]
    high = [max(p[c] for p in converted) for c in range(3)]
    measurements[model] = {'min': low, 'size': [high[c] - low[c] for c in range(3)]}
report = {
    'reference': 'DFU master source snapshot plus supplied DFU_Video_Settings.txt; installed DFU binary/version not supplied',
    'native_metres_per_unit': scale,
    'arch3d_fixed_point_divisor': divisor,
    'player': {'height': height, 'radius': radius, 'eye_height': height - eye_inset},
    'camera': {'vertical_fov': fov, 'render_size': [640, 400], 'display_aspect': [4, 3],
               'horizontal_fov_before_presentation': math.degrees(2 * math.atan(math.tan(math.radians(fov / 2)) * 1.6)),
               'legacy_horizontal_fov': math.degrees(2 * math.atan(math.tan(math.radians(78 / 2)) * 1280 / 720))},
    'models': measurements,
}
output = PROJECT / 'tests' / 'scale_calibration'
output.mkdir(exist_ok=True)
(output / 'native_dimensions.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
