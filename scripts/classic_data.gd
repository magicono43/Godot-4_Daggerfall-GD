class_name ClassicData
extends RefCounted
## Minimal original-data vertical slice, intentionally independent of gameplay.
const Archive = preload("res://scripts/classic_archive.gd")
const SCALE := 0.025
const ORIGIN := Vector3(510, 0, -1672) * SCALE
const SELECTED := [17224, 11951, 11999, 12047, 11579, 12095, 32707]
var arena_path := "C:/Games/Daggerfall/arena2"
var error := ""
var provenance: Dictionary = {}
var objects: Array[Dictionary] = []
var meshes := Archive.new()
var material_cache: Dictionary = {}
var palette: PackedByteArray
var texture_count := 0
var triangle_count := 0

func load_slice() -> bool:
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
	var map := maps.record("MAPDITEM.017")
	if map.size() < 4:
		error = "Daggerfall region dungeon map missing"
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
		if location_name != "Privateer's Hold":
			continue
		var total := map.decode_u16(h + 122)
		for j in total:
			var bits := map.decode_u16(h + 131 + j * 4)
			if bits & 1024:
				block_name = "%s%07d.RDB" % ["NWLSBM"[bits >> 11], bits & 1023]
		provenance = {"location": location_name, "region": 17, "location_id": map.decode_u16(4 + i * 8 + 6), "block": block_name}
		break
	var rdb := blocks.record(block_name)
	if rdb.size() < 9532:
		error = "Starting RDB not found or truncated"
		return false
	var roots := rdb.decode_u32(12)
	for i in rdb.decode_u32(4) * rdb.decode_u32(8):
		var q := rdb.decode_s32(roots + i * 4)
		var visited: Dictionary = {}
		while q >= 0:
			if q + 25 > rdb.size() or visited.has(q):
				error = "Invalid RDB object chain"
				return false
			visited[q] = true
			var resource := rdb.decode_u32(q + 21)
			var pos := Vector3(rdb.decode_s32(q + 8), -rdb.decode_s32(q + 12), -rdb.decode_s32(q + 16)) * SCALE - ORIGIN
			if rdb[q + 20] == 1 and SELECTED.has(q):
				var index := rdb.decode_u16(resource + 12)
				var angles := Vector3(rdb.decode_s32(resource), rdb.decode_s32(resource + 4), -rdb.decode_s32(resource + 8)) * TAU / 2048.0
				var basis := Basis(Vector3.FORWARD, -angles.z) * Basis(Vector3.RIGHT, angles.x) * Basis(Vector3.UP, angles.y)
				objects.append({"offset": q, "model": cstring(rdb, 20 + index * 8, 5), "transform": Transform3D(basis, pos)})
			if rdb[q + 20] == 3:
				var tex := rdb.decode_u16(resource)
				if tex >> 7 == 199 and tex & 127 == 8:
					provenance["start"] = pos
			q = rdb.decode_s32(q)
	palette = FileAccess.get_file_as_bytes(arena_path.path_join("ART_PAL.COL"))
	if objects.size() != SELECTED.size() or not provenance.has("start"):
		error = "Expected slice records or start marker missing"
		return false
	return true

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
		var mat := material(texture)
		var size := Vector2(64, 64)
		if mat.albedo_texture:
			size = mat.albedo_texture.get_size()
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
	var image := read_texture(bitfield >> 7, bitfield & 127)
	if image:
		mat.albedo_texture = ImageTexture.create_from_image(image)
		mat.albedo_color = Color.WHITE
		texture_count += 1
	material_cache[bitfield] = mat
	return mat

func read_texture(archive: int, record: int) -> Image:
	if archive == 0 or archive == 1:
		var solid := Image.create(32, 32, false, Image.FORMAT_RGB8)
		var index := record + (128 if archive == 1 else 0)
		solid.fill(Color8(palette[8 + index * 3], palette[9 + index * 3], palette[10 + index * 3]))
		return solid
	var bytes := FileAccess.get_file_as_bytes(arena_path.path_join("TEXTURE.%03d" % archive))
	if bytes.size() < 26 or palette.size() < 776 or record >= bytes.decode_u16(0):
		return null
	var p := bytes.decode_u32(28 + record * 20)
	if p + 28 > bytes.size():
		return null
	var w := bytes.decode_u16(p + 4)
	var h := bytes.decode_u16(p + 6)
	var compression := bytes.decode_u16(p + 8)
	var data := p + bytes.decode_u32(p + 14)
	if w == 0 or h == 0 or w > 256 or h > 256:
		return null
	var indices := PackedByteArray()
	indices.resize(w * h)
	if (compression == 0 or compression == 0x0900) and bytes.decode_u16(p + 20) == 1:
		for y in h:
			if data + y * 256 + w > bytes.size():
				return null
			for x in w:
				indices[y * w + x] = bytes[data + y * 256 + x]
	elif compression == 0x1108 or compression == 0x0108:
		for y in h:
			var row := p + bytes.decode_s16(data + y * 4)
			var encoding := bytes.decode_u16(data + y * 4 + 2)
			var x := 0
			if encoding == 0x8000:
				row += 2
				while x < w:
					var run := bytes.decode_s16(row)
					row += 2
					if run == 0 or x + absi(run) > w:
						return null
					for j in absi(run):
						indices[y * w + x] = bytes[row] if run < 0 else bytes[row + j]
						x += 1
					row += 1 if run < 0 else run
			else:
				for j in w:
					indices[y * w + j] = bytes[row + j]
	else:
		return null
	var rgb := PackedByteArray()
	rgb.resize(w * h * 3)
	for i in indices.size():
		for c in 3:
			rgb[i * 3 + c] = palette[8 + indices[i] * 3 + c]
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, rgb)


