class_name ClassicData
extends RefCounted
## Minimal original-data vertical slice, intentionally independent of gameplay.
const Archive = preload("res://scripts/classic_archive.gd")
const DungeonTextures = preload("res://scripts/classic_dungeon_textures.gd")
const Section = preload("res://scripts/classic_section.gd")
const SCALE := 0.025
const DEFAULT_SECTION := "res://sections/privateers_hold_opening.json"
var origin := Vector3.ZERO
var section := Section.new()
var arena_path := "C:/Games/Daggerfall/arena2"
var error := ""
var provenance: Dictionary = {}
var objects: Array[Dictionary] = []
var billboards: Array[Dictionary] = []
var enemy_visuals: Dictionary = {}
var dagger_frames: Array[Dictionary] = []
var item_icons: Dictionary = {}
var meshes := Archive.new()
var material_cache: Dictionary = {}
var dungeon_textures := DungeonTextures.new()
var texture_archives: Dictionary = {}
var source_size_cache: Dictionary = {}
var palette: PackedByteArray
var texture_count := 0
var triangle_count := 0

static func decode_sound(bytes: PackedByteArray) -> AudioStreamWAV:
	if bytes.is_empty():
		return null
	# DAGGER.SND is unsigned 8-bit mono PCM; Godot expects signed PCM.
	var pcm := bytes.duplicate()
	for i in pcm.size():
		pcm[i] = pcm[i] ^ 128
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	stream.stereo = false
	stream.data = pcm
	return stream

func load_slice(section_path: String = DEFAULT_SECTION) -> bool:
	error = ""
	objects.clear()
	billboards.clear()
	enemy_visuals.clear()
	dagger_frames.clear()
	item_icons.clear()
	provenance.clear()
	material_cache.clear()
	texture_archives.clear()
	source_size_cache.clear()
	triangle_count = 0
	texture_count = 0
	if not section.load_file(section_path):
		error = section.error
		return false
	var definition: Dictionary = section.definition
	origin = native_vector(definition.origin_native) * SCALE
	var maps := Archive.new()
	var blocks := Archive.new()
	if not maps.open(arena_path.path_join("MAPS.BSA")):
		error = maps.error
		return false
	if not blocks.open(arena_path.path_join("BLOCKS.BSA")):
		error = blocks.error
		return false
	if not meshes.open(arena_path.path_join("ARCH3D.BSA")):
		error = meshes.error
		return false
	var map := maps.record("MAPDITEM.%03d" % int(definition.source.region))
	if map.size() < 4:
		error = "Section region dungeon map missing"
		return false
	var count := map.decode_u32(0)
	var block_name := ""
	for i in count:
		var p := 4 + count * 8 + map.decode_u32(4 + i * 8)
		if p + 4 >= map.size():
			continue
		var h := p + 4 + map.decode_u32(p) * 6
		if h + 129 >= map.size():
			continue
		var location_name := cstring(map, h + 71, 32)
		if location_name != definition.source.location:
			continue
		var total := map.decode_u16(h + 122)
		for j in total:
			var bits := map.decode_u16(h + 131 + j * 4)
			if bits & 1024:
				block_name = "%s%07d.RDB" % ["NWLSBM"[bits >> 11], bits & 1023]
		provenance = {"location": location_name, "region": int(definition.source.region), "location_id": map.decode_u16(4 + i * 8 + 6), "block": block_name, "section": definition.name}
		# Texture RNG is seeded by the dungeon header ID (50050), not the
		# exterior/location lookup ID (50049). They are different in this dungeon.
		var dungeon_id := map.decode_u16(h + 33)
		if provenance.location_id != definition.source.expected_exterior_id or dungeon_id != definition.source.expected_dungeon_id or block_name != definition.source.block:
			error = "Section source IDs/block differ from original location data"
			return false
		var map_x := floori(map.decode_s32(h + 7) / 32768.0)
		var map_y := 499 - floori(map.decode_s32(h + 15) / 32768.0)
		var climate := dungeon_textures.read_climate(arena_path.path_join("CLIMATE.PAK"), Vector2i(map_x, map_y))
		if climate < 223 or climate > 232:
			error = "Cannot resolve dungeon climate from CLIMATE.PAK"
			return false
		dungeon_textures.configure(dungeon_id, climate)
		provenance.merge({"dungeon_id": dungeon_id, "climate": climate, "map_pixel": Vector2i(map_x, map_y), "texture_mode": "classic", "texture_table": dungeon_textures.table.duplicate()})
		break
	var rdb := blocks.record(block_name)
	if rdb.size() < 9532:
		error = "Starting RDB not found or truncated"
		return false
	var roots := rdb.decode_u32(12)
	var selected: Dictionary = {}
	for entry in definition.models:
		selected[int(entry.record_offset)] = entry
	for entry in definition.billboards:
		selected[int(entry.record_offset)] = entry
	var matched: Dictionary = {}
	var spawn: Dictionary = definition.spawn
	for i in rdb.decode_u32(4) * rdb.decode_u32(8):
		var q := rdb.decode_s32(roots + i * 4)
		var visited: Dictionary = {}
		while q >= 0:
			if q + 25 > rdb.size() or visited.has(q):
				error = "Invalid RDB object chain"
				return false
			visited[q] = true
			var resource := rdb.decode_u32(q + 21)
			var pos := Vector3(rdb.decode_s32(q + 8), -rdb.decode_s32(q + 12), -rdb.decode_s32(q + 16)) * SCALE - origin
			if selected.has(q):
				var entry: Dictionary = selected[q]
				var expected_type := 1 if entry.has("expected_model") else 3
				if rdb[q + 20] != expected_type or resource + (23 if expected_type == 1 else 11) > rdb.size():
					error = "Section %s: record %d has wrong type or invalid resource" % [entry.id, q]
					return false
				matched[q] = true
			if rdb[q + 20] == 1 and selected.has(q):
				var entry: Dictionary = selected[q]
				var index := rdb.decode_u16(resource + 12)
				var model := cstring(rdb, 20 + index * 8, 5) if index < 750 else ""
				if model != entry.expected_model or not meshes.entries.has(model):
					error = "Section %s: record %d expected model %s, found %s" % [entry.id, q, entry.expected_model, model]
					return false
				var angles := Vector3(rdb.decode_s32(resource), rdb.decode_s32(resource + 4), -rdb.decode_s32(resource + 8)) * TAU / 2048.0
				var basis := Basis(Vector3.FORWARD, -angles.z) * Basis(Vector3.RIGHT, angles.x) * Basis(Vector3.UP, angles.y)
				objects.append({"offset": q, "model": model, "transform": Transform3D(basis, pos), "id": entry.id, "role": entry.role, "collision": entry.collision})
			if rdb[q + 20] == 3:
				if resource + 2 > rdb.size():
					error = "Invalid flat resource"
					return false
				var tex := rdb.decode_u16(resource)
				if q == int(spawn.record_offset):
					if tex >> 7 != int(spawn.expected_archive) or tex & 127 != int(spawn.expected_record):
						error = "Section spawn record does not match expected editor marker"
						return false
					provenance["start"] = pos
				if selected.has(q):
					var entry: Dictionary = selected[q]
					if tex >> 7 != int(entry.expected_archive) or tex & 127 != int(entry.expected_record):
						error = "Section %s: record %d expected texture %d:%d, found %d:%d" % [entry.id, q, entry.expected_archive, entry.expected_record, tex >> 7, tex & 127]
						return false
					billboards.append({"id": entry.id, "offset": q, "archive": tex >> 7, "record": tex & 127, "position": pos, "fps": float(entry.fps)})
			q = rdb.decode_s32(q)
	palette = FileAccess.get_file_as_bytes(arena_path.path_join("ART_PAL.COL"))
	if matched.size() != selected.size() or not provenance.has("start"):
		error = "Section exact spawn marker missing from source block"
		for offset in selected:
			if not matched.has(offset):
				error = "Section %s: record %d missing from source block" % [selected[offset].id, offset]
				break
		return false
	if palette.size() < 776:
		error = "Original ART_PAL.COL palette missing or truncated"
		return false
	for i in billboards.size():
		var payload := billboard_payload(billboards[i])
		if payload.is_empty():
			return false
		billboards[i] = payload
	for entry in definition.prototype.enemies:
		if entry.get("visual", "greybox") == "skeleton" and not enemy_visuals.has("skeleton"):
			var payload := skeleton_payload()
			if payload.is_empty():
				return false
			enemy_visuals.skeleton = payload
	# Inventory images use raw item archive mappings, never dungeon/climate swaps.
	for id in preload("res://scripts/item_catalog.gd").DEFINITIONS:
		var mapping: Array = preload("res://scripts/item_catalog.gd").DEFINITIONS[id].icon
		var image := read_texture(int(mapping[0]), int(mapping[1]), 0, true, true)
		if image == null:
			error = "Missing, truncated or unsupported original inventory image: " + id
			return false
		item_icons[id] = ImageTexture.create_from_image(image)
	dagger_frames = decode_dagger_cif(FileAccess.get_file_as_bytes(arena_path.path_join("WEAPON02.CIF")))
	if dagger_frames.is_empty():
		error = "Missing, truncated or unsupported original WEAPON02.CIF dagger data"
		return false
	return true

func native_vector(value: Array) -> Vector3:
	return Vector3(value[0], -value[1], -value[2])

func to_world(value: Array) -> Vector3:
	return native_vector(value) * SCALE - origin

func cstring(bytes: PackedByteArray, start: int, length: int) -> String:
	var end := start
	while end < start + length and bytes[end] != 0:
		end += 1
	return bytes.slice(start, end).get_string_from_ascii()

func build_mesh(model: String) -> ArrayMesh:
	var bytes := meshes.record(model)
	var mesh := ArrayMesh.new()
	if bytes.size() < 64:
		return mesh
	var version := cstring(bytes, 0, 4)
	var points := bytes.decode_u32(48)
	var face := bytes.decode_u32(60)
	var groups: Dictionary = {}
	for i in bytes.decode_u32(8):
		var n := int(bytes[face])
		var texture := bytes.decode_u16(face + 2)
		var vertices: Array[Vector3] = []
		var uv: Array[Vector2] = []
		for j in n:
			var offset := bytes.decode_u32(face + 8 + j * 8)
			if version == "v2.5":
				offset *= 3
			var p := points + offset
			vertices.append(Vector3(bytes.decode_s32(p), -bytes.decode_s32(p + 4), -bytes.decode_s32(p + 8)) * SCALE / 256.0)
			uv.append(Vector2(bytes.decode_s16(face + 12 + j * 8), bytes.decode_s16(face + 14 + j * 8)) / 16.0)
		face += 8 + n * 8
		if n < 3:
			continue
		uv[1] += uv[0]
		uv[2] += uv[1]
		# Solve planar UVs using the first three corners; later native UVs are unused.
		var a := vertices[1] - vertices[0]
		var b := vertices[2] - vertices[0]
		var determinant := a.dot(a) * b.dot(b) - a.dot(b) * a.dot(b)
		for j in range(3, n):
			var v := vertices[j] - vertices[0]
			if absf(determinant) > 0.000001:
				var s := (v.dot(a) * b.dot(b) - v.dot(b) * a.dot(b)) / determinant
				var t := (v.dot(b) * a.dot(a) - v.dot(a) * a.dot(b)) / determinant
				uv[j] = uv[0] + s * (uv[1] - uv[0]) + t * (uv[2] - uv[0])
		if not groups.has(texture):
			groups[texture] = {"v": PackedVector3Array(), "uv": PackedVector2Array(), "n": PackedVector3Array()}
		var group: Dictionary = groups[texture]
		# DFU normalises native UVs using the ORIGINAL material dimensions,
		# then replaces materials. A swap must not change tiling or geometry.
		var size := source_texture_size(texture)
		for j in range(1, n - 1):
			# Godot clockwise front faces; two axis flips preserve native winding.
			var normal := (vertices[j + 1] - vertices[0]).cross(vertices[j] - vertices[0]).normalized()
			for k in [0, j, j + 1]:
				group.v.append(vertices[k])
				group.uv.append(uv[k] / size)
				group.n.append(normal)
			triangle_count += 1
	for texture in groups:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = groups[texture].v
		arrays[Mesh.ARRAY_TEX_UV] = groups[texture].uv
		arrays[Mesh.ARRAY_NORMAL] = groups[texture].n
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(texture))
	return mesh

func material(bitfield: int) -> StandardMaterial3D:
	if material_cache.has(bitfield):
		return material_cache[bitfield]
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = Color(0.55, 0.53, 0.48)
	var archive := dungeon_textures.resolve(bitfield >> 7)
	var record := bitfield & 127
	mat.set_meta("source_texture", bitfield)
	mat.set_meta("resolved_texture", (archive << 7) | record)
	var image := read_texture(archive, record)
	if image:
		mat.albedo_texture = ImageTexture.create_from_image(image)
		mat.albedo_color = Color.WHITE
		texture_count += 1
	material_cache[bitfield] = mat
	return mat

func texture_bytes(archive: int) -> PackedByteArray:
	if not texture_archives.has(archive):
		var path := arena_path.path_join("TEXTURE.%03d" % archive)
		texture_archives[archive] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	return texture_archives[archive]

func source_texture_size(bitfield: int) -> Vector2:
	if source_size_cache.has(bitfield):
		return source_size_cache[bitfield]
	var archive := bitfield >> 7
	var record := bitfield & 127
	var size := Vector2(32, 32) if archive in [0, 1] else Vector2(64, 64)
	if archive > 1:
		var bytes := texture_bytes(archive)
		if bytes.size() >= 26 and record < bytes.decode_u16(0) and 32 + record * 20 <= bytes.size():
			var p := bytes.decode_u32(28 + record * 20)
			if p + 8 <= bytes.size():
				size = Vector2(maxi(1, bytes.decode_u16(p + 4)), maxi(1, bytes.decode_u16(p + 6)))
	source_size_cache[bitfield] = size
	return size

func texture_info(archive: int, record: int) -> Dictionary:
	var bytes := texture_bytes(archive)
	if bytes.size() < 26 or record < 0 or record >= bytes.decode_u16(0) or 32 + record * 20 > bytes.size():
		return {}
	var p := bytes.decode_u32(28 + record * 20)
	if p + 28 > bytes.size():
		return {}
	var w := bytes.decode_u16(p + 4)
	var h := bytes.decode_u16(p + 6)
	var count := bytes.decode_u16(p + 20)
	if w == 0 or h == 0 or w > 256 or h > 256 or count == 0 or count > 256:
		return {}
	# DFU truncates the native pixel-scale adjustment before converting to metres.
	var width := w + int(w * bytes.decode_s16(p + 24) / 256.0)
	var height := h + int(h * bytes.decode_s16(p + 26) / 256.0)
	if width <= 0 or height <= 0:
		return {}
	return {"offset": p, "width": w, "height": h, "frames": count, "size_metres": Vector2(width, height) * SCALE}

func billboard_payload(entry: Dictionary) -> Dictionary:
	# Billboards use their own archive directly, never dungeon mesh texture swaps.
	var info := texture_info(entry.archive, entry.record)
	if info.is_empty():
		error = "Section %s: invalid billboard texture header" % entry.id
		return {}
	var frames: Array[Texture2D] = []
	for frame in int(info.frames):
		var image := read_texture(entry.archive, entry.record, frame, true)
		if not image:
			error = "Section %s: cannot decode billboard frame %d" % [entry.id, frame]
			return {}
		frames.append(ImageTexture.create_from_image(image))
	var payload := entry.duplicate()
	payload.merge({"frames": frames, "size_metres": info.size_metres})
	return payload

func read_texture(archive: int, record: int, frame: int = 0, transparent: bool = false, remove_inventory_mask: bool = false) -> Image:
	if archive == 0 or archive == 1:
		var solid := Image.create(32, 32, false, Image.FORMAT_RGB8)
		var index := record + (128 if archive == 1 else 0)
		solid.fill(Color8(palette[8 + index * 3], palette[9 + index * 3], palette[10 + index * 3]))
		return solid
	var info := texture_info(archive, record)
	if info.is_empty() or palette.size() < 776 or frame < 0 or frame >= int(info.frames):
		return null
	var bytes := texture_bytes(archive)
	var p := int(info.offset)
	var w := int(info.width)
	var h := int(info.height)
	var compression := bytes.decode_u16(p + 8)
	var data := p + bytes.decode_u32(p + 14)
	if data > bytes.size():
		return null
	var indices := PackedByteArray()
	indices.resize(w * h)
	# DFU TextureFile.ReadImage treats the Twigs 0x0101 flag as raw rows.
	if (compression == 0 or compression == 0x0900 or compression == 0x0101) and int(info.frames) == 1:
		for y in h:
			if data + y * 256 + w > bytes.size():
				return null
			for x in w:
				indices[y * w + x] = bytes[data + y * 256 + x]
	elif compression == 0 or compression == 0x0900:
		if data + int(info.frames) * 4 > bytes.size():
			return null
		var cursor := data + bytes.decode_u32(data + frame * 4)
		if cursor + 4 > bytes.size():
			return null
		var fw := bytes.decode_u16(cursor)
		var fh := bytes.decode_u16(cursor + 2)
		cursor += 4
		if fw == 0 or fh == 0 or fw > w or fh > h:
			return null
		# Animated records alternate transparent and literal runs per row.
		for y in fh:
			var x := 0
			while x < fw:
				if cursor + 2 > bytes.size():
					return null
				var skip := int(bytes[cursor])
				var count := int(bytes[cursor + 1])
				cursor += 2
				if skip + count == 0 or x + skip + count > fw or cursor + count > bytes.size():
					return null
				x += skip
				for j in count:
					indices[y * w + x] = bytes[cursor + j]
					x += 1
				cursor += count
	elif compression == 0x1108 or compression == 0x0108:
		data += h * frame * 4
		if data + h * 4 > bytes.size():
			return null
		for y in h:
			var row := p + bytes.decode_s16(data + y * 4)
			var encoding := bytes.decode_u16(data + y * 4 + 2)
			var x := 0
			if row < 0 or row + 2 > bytes.size():
				return null
			if encoding == 0x8000:
				if bytes.decode_u16(row) != w:
					return null
				row += 2
				while x < w:
					if row + 2 > bytes.size():
						return null
					var run := bytes.decode_s16(row)
					row += 2
					if run == 0 or x + absi(run) > w or row + (1 if run < 0 else run) > bytes.size():
						return null
					for j in absi(run):
						indices[y * w + x] = bytes[row] if run < 0 else bytes[row + j]
						x += 1
					row += 1 if run < 0 else run
			else:
				if row + w > bytes.size():
					return null
				for j in w:
					indices[y * w + j] = bytes[row + j]
	else:
		return null
	var channels := 4 if transparent else 3
	var rgb := PackedByteArray()
	rgb.resize(w * h * channels)
	for i in indices.size():
		# ItemHelper.GetInventoryImage removes 0xff masks before palette lookup.
		if remove_inventory_mask and indices[i] == 255:
			indices[i] = 0
		for c in 3:
			rgb[i * channels + c] = palette[8 + indices[i] * 3 + c]
		if transparent:
			rgb[i * 4 + 3] = 0 if indices[i] == 0 else 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8 if transparent else Image.FORMAT_RGB8, rgb)



func skeleton_payload() -> Dictionary:
	# DFU EnemyBasics: Skeletal Warrior ID 15, live archive 270, corpse 306:1.
	var records: Dictionary = {}
	for record in 20:
		var payload := billboard_payload({"id": "skeleton_%d" % record, "archive": 270, "record": record})
		if payload.is_empty():
			return {}
		var expected := 4 if record < 5 else (6 if record < 10 else 1)
		if payload.frames.size() != expected:
			error = "Skeleton 270:%d expected %d frames" % [record, expected]
			return {}
		records[record] = payload
	var corpse := billboard_payload({"id": "skeleton_corpse", "archive": 306, "record": 1})
	if corpse.is_empty():
		return {}
	return {"archive": 270, "records": records, "corpse": corpse}

func cif_rgba(indices: PackedByteArray, width: int, height: int) -> Texture2D:
	var rgba := PackedByteArray()
	rgba.resize(indices.size() * 4)
	for i in indices.size():
		var index := int(indices[i])
		for channel in 3:
			rgba[i * 4 + channel] = palette[8 + index * 3 + channel]
		rgba[i * 4 + 3] = 0 if index == 0 else 255
	return ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba))

func cif_rle(bytes: PackedByteArray, start: int, end: int, length: int) -> PackedByteArray:
	var pixels := PackedByteArray()
	var cursor := start
	while pixels.size() < length:
		if cursor >= end:
			return PackedByteArray()
		var code := int(bytes[cursor])
		cursor += 1
		var count := code - 127 if code > 127 else code + 1
		if pixels.size() + count > length or cursor + (1 if code > 127 else count) > end:
			return PackedByteArray()
		if code > 127:
			for i in count:
				pixels.append(bytes[cursor])
			cursor += 1
		else:
			pixels.append_array(bytes.slice(cursor, cursor + count))
			cursor += count
	return pixels

func decode_dagger_cif(bytes: PackedByteArray) -> Array[Dictionary]:
	# Specialized, checked CIF weapon records; not a general CIF/RCI importer.
	var result: Array[Dictionary] = []
	if bytes.size() < 12 or palette.size() < 776:
		return result
	var width := bytes.decode_u16(4)
	var height := bytes.decode_u16(6)
	var length := bytes.decode_u16(10)
	if width < 1 or width > 320 or height < 1 or height > 200 or bytes.decode_u16(8) != 0 or length != width * height or 12 + length > bytes.size():
		return result
	result.append({"width": width, "height": height, "frames": [cif_rgba(bytes.slice(12, 12 + length), width, height)]})
	var offset := 12 + length
	for record in range(1, 7):
		if offset + 76 > bytes.size():
			return []
		width = bytes.decode_u16(offset)
		height = bytes.decode_u16(offset + 2)
		var total := bytes.decode_u16(offset + 74)
		if width < 1 or width > 320 or height < 1 or height > 200 or total <= 76 or offset + total > bytes.size():
			return []
		var starts: Array[int] = []
		for i in 31:
			var frame_offset := bytes.decode_u16(offset + 12 + i * 2)
			if i < 5:
				if frame_offset < 76 or frame_offset >= total or (i > 0 and frame_offset <= starts[-1]):
					return []
				starts.append(frame_offset)
			elif frame_offset != 0:
				return []
		var frames: Array[Texture2D] = []
		for frame in 5:
			var end := offset + (starts[frame + 1] if frame < 4 else total)
			var pixels := cif_rle(bytes, offset + starts[frame], end, width * height)
			if pixels.is_empty():
				return []
			frames.append(cif_rgba(pixels, width, height))
		result.append({"width": width, "height": height, "frames": frames})
		offset += total
	if offset != bytes.size():
		return []
	return result
