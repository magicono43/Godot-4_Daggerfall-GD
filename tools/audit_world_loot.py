"""Read-only independent treasure marker and original pile sprite evidence."""
import hashlib, json, struct
from pathlib import Path
from inspect_data import ROOT, bsa
project = Path(__file__).resolve().parents[1]
section = json.loads((project / "sections/privateers_hold_opening.json").read_text())
rdb = bsa("BLOCKS.BSA")[section["source"]["block"]]
markers = {}
for entry in section["treasure_markers"]:
    offset = entry["record_offset"]
    assert rdb[offset + 20] == 3
    resource = struct.unpack_from("<I", rdb, offset + 21)[0]
    packed = struct.unpack_from("<H", rdb, resource)[0]
    assert (packed >> 7, packed & 127) == (199, 19)
    markers[entry["id"]] = {"offset": offset, "native": struct.unpack_from("<iii", rdb, offset + 8)}
data = (ROOT / "TEXTURE.216").read_bytes()
pos = struct.unpack_from("<I", data, 28)[0]
w,h,compression = struct.unpack_from("<HHH", data, pos + 4)
start = pos + struct.unpack_from("<I", data, pos + 14)[0]
assert compression in (0, 0x900) and struct.unpack_from("<H", data, pos+20)[0] == 1
pixels = b"".join(data[start+y*256:start+y*256+w] for y in range(h))
palette = (ROOT / "ART_PAL.COL").read_bytes()[8:776]
rgba = b"".join(palette[c*3:c*3+3] + bytes([255 if c else 0]) for c in pixels)
fixture = {"block_sha256": hashlib.sha256(rdb).hexdigest(), "markers": markers,
    "sprite": {"archive":216,"record":0,"pixels":[w,h],"rgba_sha256":hashlib.sha256(rgba).hexdigest()}}
(project / "tests/items/world_loot.json").write_text(json.dumps(fixture,indent=2)+"\n")
print(fixture)
