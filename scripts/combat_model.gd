extends RefCounted
## Validated live combat inputs. Player inputs adapt shared character state; monster profiles stay independent.
const DEFAULTS := {"strength": 50, "agility": 50, "luck": 50, "short_blade": 25, "blunt_weapon": 25, "hand_to_hand": 25, "dodging": 25, "critical_strike": 25, "reflexes": 2}
var values: Dictionary = DEFAULTS.duplicate()
var character: RefCounted
var local_live_stats: Dictionary = {}
var live_stats: Dictionary:
	get:
		if character == null:
			return local_live_stats
		var result := {}
		if local_live_stats.has("reflexes"):
			result.reflexes = local_live_stats.reflexes
		for key in DEFAULTS:
			if character.live.has(key):
				result[key] = character.live[key]
		return result
var error := ""
var monster := false
var skeleton := false
var parry_sounds := false
var base_armor := 100
var minimum_material := -1
var attack_ranges: Array[Vector2i] = [Vector2i(1, 6)]

func valid(stats: Variant, complete: bool = false) -> bool:
	if not stats is Dictionary or (complete and stats.size() != DEFAULTS.size()):
		return false
	for key in stats:
		if not DEFAULTS.has(key) or not (stats[key] is int or stats[key] is float):
			return false
		var n := float(stats[key])
		if not is_finite(n) or n != floor(n) or n < 0 or n > (4 if key == "reflexes" else 100):
			return false
	return true

func load_file(path: String = "res://combat.cfg") -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK or not config.has_section("player"):
		error = "Cannot read combat.cfg; retained previous combat values."
		return false
	var candidate := DEFAULTS.duplicate()
	for key in config.get_section_keys("player"):
		candidate[key] = config.get_value("player", key)
	if not valid(candidate, true):
		error = "Invalid combat.cfg; retained previous combat values."
		return false
	values = candidate
	error = ""
	return true

func set_live_stats(stats: Dictionary) -> bool:
	if not valid(stats):
		return false
	if character != null:
		var mapped := stats.duplicate()
		mapped.erase("reflexes")
		var keys := DEFAULTS.keys()
		keys.erase("reflexes")
		if not character.replace_live(keys, mapped):
			return false
	local_live_stats = stats.duplicate() if character == null else ({"reflexes": stats.reflexes} if stats.has("reflexes") else {})
	return true

func stat(key: String) -> int:
	if character != null and key != "reflexes":
		return int(character.stat(key))
	return int(live_stats.get(key, values[key]))

func configure_skeleton(attributes: Dictionary) -> void:
	monster = true
	skeleton = true
	parry_sounds = true
	base_armor = 2 * 5
	attack_ranges = [Vector2i(5, 15)]
	# EnemyEntity: min(100, level*5+30), skeleton level 9.
	values = {"strength": int(attributes.strength), "agility": int(attributes.agility), "luck": int(attributes.luck), "short_blade": 75, "blunt_weapon": 75, "hand_to_hand": 75, "dodging": 75, "critical_strike": 75, "reflexes": 2}

func configure_bear(attributes: Dictionary) -> void:
	monster = true
	skeleton = false
	parry_sounds = false
	base_armor = 6 * 5
	attack_ranges = [Vector2i(1, 8), Vector2i(1, 8), Vector2i(1, 10)]
	# EnemyBasics level 4 -> EnemyEntity skills min(100, 4*5+30) = 50.
	values = {"strength": int(attributes.strength), "agility": int(attributes.agility), "luck": int(attributes.luck), "short_blade": 50, "blunt_weapon": 50, "hand_to_hand": 50, "dodging": 50, "critical_strike": 50, "reflexes": 2}

func armor(body: CharacterBody3D, region: int) -> int:
	# Slot order follows DFU's seven body regions. Armor affects only its region.
	var owned = body.get("inventory")
	var catalog = preload("res://scripts/item_catalog.gd")
	if owned == null or region < 0 or region >= catalog.ARMOR_SLOTS.size():
		return base_armor
	var uid: int = owned.armor_slots[catalog.ARMOR_SLOTS[region]]
	return base_armor - catalog.armor_protection(owned.find(uid)) * 5

func diagnostic(body: CharacterBody3D) -> String:
	return "Combat: STR %d AGI %d LUC %d | Short %d Blunt %d Dodge %d Crit %d\nChest protection %d | internal armor %d (lower is better)%s" % [stat("strength"), stat("agility"), stat("luck"), stat("short_blade"), stat("blunt_weapon"), stat("dodging"), stat("critical_strike"), int((100 - armor(body, 3)) / 5), armor(body, 3), "\n" + error if not error.is_empty() else ""]

