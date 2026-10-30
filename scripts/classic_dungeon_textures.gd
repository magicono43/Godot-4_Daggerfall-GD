extends RefCounted
## Classic dungeon texture selection. Kept separate from geometry and gameplay.
const SLOTS := [119, 120, 122, 123, 124, 168]
const CLIMATE_ARCHIVE_INDICES := [0, 0, 1, 4, 4, 0, 3, 3, 3, 0]
const TRAVEL_CLIMATE_INDICES := [0, 0, 0, 1, 2, 3, 4, 5, 5, 5]
const CLASSIC_ARCHIVES := [19, 119, 319, 419, 119]
var table: Array[int] = []
var climate_base := 300

func configure(dungeon_id: int, climate: int) -> void:
	# Classic treats ocean as swamp when choosing dungeon textures.
	if climate == 223:
		climate = 228
	assert(climate >= 224 and climate <= 232)
	var classic_index: int = TRAVEL_CLIMATE_INDICES[climate - 223]
	var base: int = CLASSIC_ARCHIVES[CLIMATE_ARCHIVE_INDICES[classic_index]]
	# Only the low 32 bits affect rand's 15-bit output. Explicit wrapping avoids
	# signed 64-bit overflow and reproduces DFRandom rather than Godot's RNG.
	var state := dungeon_id & 0xffffffff
	table.clear()
	for i in 5:
		state = (state * 1103515245 + 12345) & 0xffffffff
		var offset := ((state >> 16) & 0x7fff) % 5
		if offset == 2:
			offset = 4
		table.append(base + offset)
	table.append(68 + 100 * CLIMATE_ARCHIVE_INDICES[climate - 224])
	# Door archive 74 uses the location's climate base, independently of Classic's
	# randomised masonry slots. Temperate woodlands therefore use archive 374.
	if climate in [224, 225, 229]:
		climate_base = 0
	elif climate == 226:
		climate_base = 100
	elif climate in [227, 228]:
		climate_base = 400
	else:
		climate_base = 300

func resolve(archive: int) -> int:
	if archive == 74:
		return 74 + climate_base
	var slot := SLOTS.find(archive)
	return table[slot] if slot >= 0 else archive

func read_climate(path: String, map_pixel: Vector2i) -> int:
	# CLIMATE.PAK stores run-length encoded rows, 1001 pixels wide. DFU offsets
	# lookup X by one to align this map with the world height map.
	if not FileAccess.file_exists(path) or map_pixel.x < 0 or map_pixel.x >= 1000 or map_pixel.y < 0 or map_pixel.y >= 500:
		return -1
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 2000:
		return -1
	var p := bytes.decode_u32(map_pixel.y * 4)
	var x := 0
	while p + 3 <= bytes.size() and x < 1001:
		var count := bytes.decode_u16(p)
		if count == 0 or x + count > 1001:
			return -1
		x += count
		if map_pixel.x + 1 < x:
			return bytes[p + 2]
		p += 3
	return -1
