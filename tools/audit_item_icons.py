"""Independent read-only inventory texture decoder and source/RGBA fingerprint audit."""
import configparser
import hashlib
import json
import struct
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
cfg = configparser.ConfigParser()
cfg.read(PROJECT / "data_source.cfg")
root = Path(cfg["classic"]["arena2"].strip('"'))
palette_file = (root / "ART_PAL.COL").read_bytes()
palette = palette_file[8:776]
# Pinned ItemTemplates and ItemHelper inventory rules; independent of GDScript catalog.
selection = {"dagger": (113, 234, 5), "gold": (276, 216, 1), "twigs": (8, 254, 9)}
result = {"palette_sha256": hashlib.sha256(palette_file).hexdigest(), "icons": {}}
for name, (template, archive, record) in selection.items():
    data = (root / f"TEXTURE.{archive:03}").read_bytes()
    assert record < struct.unpack_from("<H", data)[0]
    pos = struct.unpack_from("<I", data, 28 + record * 20)[0]
    width, height, compression = struct.unpack_from("<HHH", data, pos + 4)
    start = pos + struct.unpack_from("<I", data, pos + 14)[0]
    assert struct.unpack_from("<H", data, pos + 20)[0] == 1
    pixels = bytearray()
    if compression in (0x0000, 0x0900, 0x0101):
        for row in range(height):
            pixels.extend(data[start + row * 256:start + row * 256 + width])
    else:
        assert compression in (0x1108, 0x0108)
        for y in range(height):
            offset, encoding = struct.unpack_from("<hH", data, start + y * 4)
            cursor = pos + offset
            row = bytearray()
            if encoding == 0x8000:
                assert struct.unpack_from("<H", data, cursor)[0] == width
                cursor += 2
                while len(row) < width:
                    run = struct.unpack_from("<h", data, cursor)[0]
                    cursor += 2
                    assert run
                    if run < 0:
                        row.extend(bytes([data[cursor]]) * -run)
                        cursor += 1
                    else:
                        row.extend(data[cursor:cursor + run])
                        cursor += run
            else:
                assert encoding == 0
                row.extend(data[cursor:cursor + width])
            assert len(row) == width
            pixels.extend(row)
    assert len(pixels) == width * height
    masks = pixels.count(255)
    pixels = pixels.replace(b"\xff", b"\x00")
    rgba = b"".join(palette[index * 3:index * 3 + 3] + bytes([255 if index else 0]) for index in pixels)
    result["icons"][name] = {"template": template, "archive": archive, "record": record,
        "pixels": [width, height], "compression": compression,
        "file_sha256": hashlib.sha256(data).hexdigest(), "rgba_sha256": hashlib.sha256(rgba).hexdigest(),
        "transparent_pixels": pixels.count(0), "removed_mask_pixels": masks}
target = PROJECT / "tests" / "items"
target.mkdir(exist_ok=True)
(target / "icon_frames.json").write_text(json.dumps(result, indent=2) + "\n")
print("Pinned original item icons:", {name: info["pixels"] for name, info in result["icons"].items()})
