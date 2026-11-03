extends RefCounted
## Resource/knowledge ownership. Casting and effect visuals live elsewhere.
const Catalog = preload("res://scripts/spell_catalog.gd")
const DEFAULTS := {"intelligence":50, "mysticism":50, "alteration":50, "destruction":50, "restoration":50, "illusion":50}
var character: RefCounted
var known: Array = []
var selected := ""
var last_cast := ""
var current := 0
var multiplier := 3.0 # Explicit authored test advantage, not a chosen career.
var no_regen := false
var error := ""

func load_profile(path: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK or not config.has_section("player"):
		error = "Cannot read magic.cfg; retained previous values."
		return {}
	var candidate := DEFAULTS.duplicate()
	for key in config.get_section_keys("player"):
		var value: Variant = config.get_value("player", key)
		if not DEFAULTS.has(key) or typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value != floor(float(value)) or value < 0 or value > 100:
			error = "Invalid magic.cfg; retained previous values."
			return {}
		candidate[key] = value
	var factor: Variant = config.get_value("resource", "multiplier", 3.0)
	var blocked: Variant = config.get_value("resource", "no_regen", false)
	if typeof(factor) not in [TYPE_INT, TYPE_FLOAT] or float(factor) not in [0.5, 1.0, 1.5, 1.75, 2.0, 3.0] or not blocked is bool:
		error = "Invalid magic resource settings; retained previous values."
		return {}
	return {"base":candidate, "multiplier":float(factor), "no_regen":blocked}

func setup(state: RefCounted, grants: Array) -> void:
	character = state
	known = grants.duplicate()
	selected = "" if known.is_empty() else str(known[0])
	current = maximum()

func maximum() -> int:
	return int(floor(character.stat("intelligence") * multiplier))

func sync_capacity() -> void:
	current = clampi(current, 0, maximum())

func recovery() -> int:
	return 0 if no_regen else maxi(int(maximum() / 8), 1)

func rest_hour() -> void:
	sync_capacity()
	current = mini(maximum(), current + recovery())

func select(id: String) -> bool:
	if id not in known:
		return false
	selected = id
	return true

func snapshot() -> Dictionary:
	sync_capacity()
	return {"known":known.duplicate(), "selected":selected, "last_cast":last_cast, "current":current}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 4 or not Catalog.valid_known(data.get("known")):
		return false
	for key in ["selected", "last_cast"]:
		if not data.get(key) is String or (data[key] != "" and data[key] not in data.known):
			return false
	if not data.known.is_empty() and data.selected.is_empty():
		return false
	var value: Variant = data.get("current")
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value == floor(float(value)) and value >= 0 and value <= 300

func restore(data: Dictionary) -> void:
	known = data.known.duplicate()
	selected = data.selected
	last_cast = data.last_cast
	current = int(data.current)
	sync_capacity()
