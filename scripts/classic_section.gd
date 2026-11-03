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

func record_key(entry: Dictionary, starting_block: String) -> String:
	return "%s:%d" % [entry.get("block", starting_block), int(entry.record_offset)]

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
	var block_names: Dictionary = {source.block: true}
	if source.has("blocks"):
		if not source.blocks is Array or source.blocks.is_empty() or source.blocks.size() > 64:
			return fail("source.blocks must contain 1..64 checked block placements")
		block_names.clear()
		var grid: Dictionary = {}
		for block in source.blocks:
			if not block is Dictionary or not block.get("name") is String or not RegEx.create_from_string("^[NWLSBM][0-9]{7}\\.RDB$").search(block.name):
				return fail("Invalid source block name")
			if block_names.has(block.name) or not number(block.get("x")) or not number(block.get("z")) or absf(block.x) > 127 or absf(block.z) > 127 or floorf(block.x) != block.x or floorf(block.z) != block.z:
				return fail("Duplicate block or invalid block grid coordinate")
			var cell := "%d:%d" % [block.x, block.z]
			if grid.has(cell):
				return fail("Duplicate source block grid cell")
			grid[cell] = true
			block_names[block.name] = true
		if not block_names.has(source.block):
			return fail("source.blocks must include the starting block")
	if not vector(value.get("origin_native")):
		return fail("origin_native requires three finite native coordinates")
	var spawn: Variant = value.get("spawn")
	if not spawn is Dictionary or not integer(spawn.get("record_offset")) or not vector(spawn.get("look_at_native")):
		return fail("spawn requires record_offset and look_at_native")
	if spawn.get("expected_archive") != 199 or not integer(spawn.get("expected_record"), 127) or int(spawn.expected_record) not in [8, 10]:
		return fail("spawn must select editor enter/start marker 199:8 or 199:10")
	if spawn.get("block", source.block) != source.block:
		return fail("spawn must remain in the flagged starting block")
	var ids: Dictionary = {}
	var offsets: Dictionary = {record_key(spawn, source.block): "spawn"}
	for group in ["models", "billboards"]:
		if not value.get(group) is Array or value[group].size() > 2048:
			return fail(group + " must be an array with at most 2048 entries")
		for entry in value[group]:
			if not entry is Dictionary or not valid_id(entry.get("id"), ids):
				return fail(group + " has invalid or duplicate id")
			if not block_names.has(entry.get("block", source.block)) or not integer(entry.get("record_offset")) or offsets.has(record_key(entry, source.block)):
				return fail("Invalid or duplicate record_offset for " + entry.id)
			offsets[record_key(entry, source.block)] = entry.id
			if group == "models":
				if not entry.get("expected_model") is String or not entry.expected_model.is_valid_int():
					return fail(entry.id + " requires expected_model string")
				if entry.get("role") not in ["geometry", "prop", "door", "exit"] or not entry.get("collision") is bool:
					return fail(entry.id + " requires role and collision boolean")
				if entry.role in ["door", "exit"] and not entry.collision:
					return fail(entry.id + " interactive door requires collision")
				if entry.has("expected_action"):
					var action: Variant = entry.expected_action
					if not action is Dictionary or action.size() != 7 or entry.role not in ["geometry", "prop"] or not entry.collision:
						return fail(entry.id + " action requires collidable geometry/prop and seven source fields")
					for field in ["axis", "duration", "magnitude", "flags", "trigger", "sound"]:
						if not integer(action.get(field), 65535):
							return fail(entry.id + " has invalid action field " + field)
					if int(action.flags) not in [1, 8, 30] or action.axis > 6 or int(action.trigger) not in [0, 2] or action.sound > 255 or not number(action.get("next")) or floorf(action.next) != action.next or action.next < -2 or action.next > 100000000:
						return fail(entry.id + " uses an unsupported action/trigger/link")
			else:
				if not integer(entry.get("expected_archive"), 511) or entry.expected_archive == 199 or not integer(entry.get("expected_record"), 127):
					return fail(entry.id + " requires a decorative texture; editor markers cannot be drawn")
				if not number(entry.get("fps")) or entry.fps <= 0 or entry.fps > 60:
					return fail(entry.id + " requires fps in (0,60]")
	var markers: Dictionary = {}
	if not value.get("treasure_markers", []) is Array or value.get("treasure_markers", []).size() > 64:
		return fail("treasure_markers must be an array of at most 64 entries")
	if not value.get("static_loot", []) is Array or value.get("static_loot", []).size() > 64:
		return fail("static_loot must be an array of at most 64 entries")
	for entry in value.get("treasure_markers", []) + value.get("static_loot", []):
		if not entry is Dictionary or not valid_id(entry.get("id"), ids):
			return fail("Invalid treasure marker id")
		if not block_names.has(entry.get("block", source.block)) or not integer(entry.get("record_offset")) or offsets.has(record_key(entry, source.block)) or entry.get("expected_archive") != 199 or entry.get("expected_record") != 19:
			return fail("Treasure marker requires unique record_offset and editor marker 199:19")
		offsets[record_key(entry, source.block)] = entry.id
		markers[entry.id] = true
	if value.models.is_empty():
		return fail("models cannot be empty")
	var prototype: Variant = value.get("prototype")
	if not prototype is Dictionary:
		return fail("prototype must separate authored additions from original objects")
	if prototype.has("player_test"):
		var setup: Variant = prototype.player_test
		if not setup is Dictionary or not integer(setup.get("maximum_health"), 10000) or setup.maximum_health < 1 or not setup.get("items") is Array or setup.items.size() > 32:
			return fail("player_test requires maximum_health 1..10000 and at most 32 items")
		if not preload("res://scripts/spell_catalog.gd").valid_known(setup.get("known_spells", [])):
			return fail("player_test has invalid/duplicate known spells")
		for item in setup.items:
			if not item is Dictionary or not item.get("definition") is String or not preload("res://scripts/item_catalog.gd").valid(item.definition):
				return fail("player_test has unknown item")
			if not integer(item.get("quantity"), 10000) or item.quantity < 1 or (item.quantity != 1 and not preload("res://scripts/item_catalog.gd").DEFINITIONS[item.definition].stackable):
				return fail("player_test has invalid item quantity")
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
			if group == "enemies" and entry.get("visual", "greybox") not in ["greybox", "skeleton", "bear"]:
				return fail(entry.id + " visual must be greybox, skeleton or bear")
			if group == "enemies" and entry.has("test_loot"):
				if entry.get("visual", "greybox") not in ["skeleton", "bear"] or not entry.test_loot is Array or entry.test_loot.size() > 32:
					return fail(entry.id + " test_loot requires supported creature and at most 32 entries")
				for item in entry.test_loot:
					if not item is Dictionary or not item.get("definition") is String or not preload("res://scripts/item_catalog.gd").valid(item.definition):
						return fail(entry.id + " test_loot has unknown item definition")
					if not integer(item.get("quantity"), 10000) or item.quantity < 1:
						return fail(entry.id + " test_loot requires quantity 1..10000")
					if item.quantity != 1 and not preload("res://scripts/item_catalog.gd").DEFINITIONS[item.definition].stackable:
						return fail(entry.id + " test_loot cannot stack this item")
			if group == "lights" and (not number(entry.get("energy")) or entry.energy < 0 or not number(entry.get("range_metres")) or entry.range_metres <= 0):
				return fail(entry.id + " requires non-negative energy and positive range_metres")
	if not prototype.get("treasure_piles", []) is Array or prototype.get("treasure_piles", []).size() > 64:
		return fail("prototype.treasure_piles must be an array of at most 64 entries")
	var assigned_markers: Dictionary = {}
	for entry in prototype.get("treasure_piles", []):
		if not entry is Dictionary or not valid_id(entry.get("id"), ids) or not entry.get("marker_id") is String:
			return fail("Treasure pile requires unique id and marker_id")
		if not markers.has(entry.marker_id) or assigned_markers.has(entry.marker_id):
			return fail("Treasure pile requires an unassigned selected marker")
		assigned_markers[entry.marker_id] = true
		if not entry.get("test_loot") is Array or entry.test_loot.is_empty() or entry.test_loot.size() > 32:
			return fail("Treasure pile test_loot requires 1..32 items")
		for item in entry.test_loot:
			if not item is Dictionary or not item.get("definition") is String or not preload("res://scripts/item_catalog.gd").valid(item.definition):
				return fail("Treasure pile has unknown item")
			if not integer(item.get("quantity"), 10000) or item.quantity < 1:
				return fail("Treasure pile requires quantity 1..10000")
			if item.quantity != 1 and not preload("res://scripts/item_catalog.gd").DEFINITIONS[item.definition].stackable:
				return fail("Treasure pile cannot stack this item")
	definition = value.duplicate(true)
	return true

func valid_id(value: Variant, ids: Dictionary) -> bool:
	if not value is String or not RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(value) or ids.has(value):
		return false
	ids[value] = true
	return true
