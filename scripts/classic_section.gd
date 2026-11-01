extends RefCounted
## Validates authored selection/behaviour only. Asset placement stays in ARENA2.
var definition: Dictionary = {}
var error := ""
var path := ""

func load_file(file_path: String) -> bool:
	path = file_path
	if not FileAccess.file_exists(path):
		return fail("Cannot find section file: " + path)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return fail("Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
	return validate(json.data)

func fail(message: String) -> bool:
	error = "Section %s: %s" % [path, message]
	return false

func vector(value: Variant, positive := false) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component in value:
		if not number(component) or absf(component) > 10000000 or (positive and component <= 0):
			return false
	return true

func number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func integer(value: Variant, maximum: int = 100000000) -> bool:
	return number(value) and value >= 0 and value <= maximum and floorf(value) == value

func validate(value: Variant) -> bool:
	error = ""
	definition.clear()
	if not value is Dictionary or value.get("schema_version") != 1:
		return fail("Expected schema_version 1 object")
	if not value.get("name") is String or value.name.is_empty():
		return fail("name must be a non-empty string")
	var source: Variant = value.get("source")
	if not source is Dictionary or not integer(source.get("region"), 61) or not source.get("location") is String:
		return fail("source requires region 0..61 and location")
	if not integer(source.get("expected_exterior_id"), 65535) or not integer(source.get("expected_dungeon_id"), 65535):
		return fail("source requires expected exterior and dungeon IDs")
	if not source.get("block") is String or not RegEx.create_from_string("^[NWLSBM][0-9]{7}\\.RDB$").search(source.block):
		return fail("source.block must be a classic RDB name")
	if not vector(value.get("origin_native")):
		return fail("origin_native requires three finite native coordinates")
	var spawn: Variant = value.get("spawn")
	if not spawn is Dictionary or not integer(spawn.get("record_offset")) or not vector(spawn.get("look_at_native")):
		return fail("spawn requires record_offset and look_at_native")
	if spawn.get("expected_archive") != 199 or not integer(spawn.get("expected_record"), 127) or int(spawn.expected_record) not in [8, 10]:
		return fail("spawn must select editor enter/start marker 199:8 or 199:10")
	var ids: Dictionary = {}
	var offsets: Dictionary = {int(spawn.record_offset): "spawn"}
	for group in ["models", "billboards"]:
		if not value.get(group) is Array or value[group].size() > 2048:
			return fail(group + " must be an array with at most 2048 entries")
		for entry in value[group]:
			if not entry is Dictionary or not valid_id(entry.get("id"), ids):
				return fail(group + " has invalid or duplicate id")
			if not integer(entry.get("record_offset")) or offsets.has(int(entry.record_offset)):
				return fail("Invalid or duplicate record_offset for " + entry.id)
			offsets[int(entry.record_offset)] = entry.id
			if group == "models":
				if not entry.get("expected_model") is String or not entry.expected_model.is_valid_int():
					return fail(entry.id + " requires expected_model string")
				if entry.get("role") not in ["geometry", "prop", "door"] or not entry.get("collision") is bool:
					return fail(entry.id + " requires role and collision boolean")
				if entry.role == "door" and not entry.collision:
					return fail(entry.id + " interactive door requires collision")
			else:
				if not integer(entry.get("expected_archive"), 511) or entry.expected_archive == 199 or not integer(entry.get("expected_record"), 127):
					return fail(entry.id + " requires a decorative texture; editor markers cannot be drawn")
				if not number(entry.get("fps")) or entry.fps <= 0 or entry.fps > 60:
					return fail(entry.id + " requires fps in (0,60]")
	if value.models.is_empty():
		return fail("models cannot be empty")
	var prototype: Variant = value.get("prototype")
	if not prototype is Dictionary:
		return fail("prototype must separate authored additions from original objects")
	if prototype.has("player_start"):
		var start: Variant = prototype.player_start
		if not start is Dictionary or not vector(start.get("position_native")) or not vector(start.get("look_at_native")):
			return fail("prototype.player_start requires position_native and look_at_native")
		if start.position_native[0] == start.look_at_native[0] and start.position_native[2] == start.look_at_native[2]:
			return fail("prototype.player_start look direction must have horizontal separation")
	for group in ["enemies", "boundaries", "lights"]:
		if not prototype.get(group) is Array or prototype[group].size() > 64:
			return fail("prototype." + group + " must be an array with at most 64 entries")
		for entry in prototype[group]:
			if not entry is Dictionary or not valid_id(entry.get("id"), ids) or not vector(entry.get("position_native")):
				return fail("Invalid id or position in prototype." + group)
			if group == "boundaries" and (not vector(entry.get("size_metres"), true) or not number(entry.get("yaw_degrees"))):
				return fail(entry.id + " requires size_metres and yaw_degrees")
			if group == "enemies" and not entry.get("approach_enabled", true) is bool:
				return fail(entry.id + " approach_enabled must be a boolean")
			if group == "enemies" and not entry.get("navigation_enabled", false) is bool:
				return fail(entry.id + " navigation_enabled must be a boolean")
			if group == "enemies" and not entry.get("attack_enabled", false) is bool:
				return fail(entry.id + " attack_enabled must be a boolean")
			if group == "enemies" and entry.get("visual", "greybox") not in ["greybox", "skeleton"]:
				return fail(entry.id + " visual must be greybox or skeleton")
			if group == "enemies" and entry.has("test_loot"):
				if entry.get("visual", "greybox") != "skeleton" or not entry.test_loot is Array or entry.test_loot.size() > 32:
					return fail(entry.id + " test_loot requires skeleton and at most 32 entries")
				for item in entry.test_loot:
					if not item is Dictionary or not item.get("definition") is String or not preload("res://scripts/item_catalog.gd").valid(item.definition):
						return fail(entry.id + " test_loot has unknown item definition")
					if not integer(item.get("quantity"), 10000) or item.quantity < 1:
						return fail(entry.id + " test_loot requires quantity 1..10000")
					if item.quantity != 1 and not preload("res://scripts/item_catalog.gd").DEFINITIONS[item.definition].stackable:
						return fail(entry.id + " test_loot cannot stack this item")
			if group == "lights" and (not number(entry.get("energy")) or entry.energy < 0 or not number(entry.get("range_metres")) or entry.range_metres <= 0):
				return fail(entry.id + " requires non-negative energy and positive range_metres")
	definition = value.duplicate(true)
	return true

func valid_id(value: Variant, ids: Dictionary) -> bool:
	if not value is String or not RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(value) or ids.has(value):
		return false
	ids[value] = true
	return true
