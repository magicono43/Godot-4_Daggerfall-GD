"""Independent ordinal DAGGER.SND audit; writes hashes only, never audio assets."""
import configparser
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
config = configparser.ConfigParser()
config.read(ROOT / "data_source.cfg", encoding="utf-8-sig")
arena = Path(config.get("classic", "arena2").strip('"'))
data = (arena / "DAGGER.SND").read_bytes()
count, kind = struct.unpack_from("<HH", data)
assert kind == 512
directory = len(data) - count * 8
offset = 4
records = []
for index in range(count):
    key, size = struct.unpack_from("<II", data, directory + index * 8)
    assert offset + size <= directory
    raw = data[offset:offset + size]
    signed = bytes(value ^ 128 for value in raw)
    records.append(dict(index=index, id=key, size=size,
                        pcm_sha256=hashlib.sha256(signed).hexdigest()))
    offset += size
assert offset == directory
selected = [7, 15, 106, 108, 109, 110, 111, 112, 160, 161, 162, 300, 376, 377, 433]
fixture = dict(count=count, unique_ids=len({r["id"] for r in records}),
               records=[records[i] for i in selected])
(ROOT / "tests" / "audio_samples.json").write_text(
    json.dumps(fixture, indent=2) + "\n", encoding="utf-8")
print(f"Audited {count} ordinal records; wrote {len(selected)} sample identities/hashes.")
