extends RefCounted
## Base character values persist; live overrides are transient.
const DEFAULTS := {"strength":50, "intelligence":50, "willpower":50, "agility":50, "endurance":50, "personality":50, "speed":50.0, "luck":50, "short_blade":25, "blunt_weapon":25, "hand_to_hand":25, "dodging":25, "critical_strike":25, "medical":25, "restoration":50, "illusion":50, "running":25.0, "jumping":25.0, "swimming":25.0, "climbing":25.0}
const MOVEMENT := {"speed_attribute":"speed", "running_skill":"running", "jumping_skill":"jumping", "swimming_skill":"swimming", "climbing_skill":"climbing"}
var base: Dictionary = DEFAULTS.duplicate()
var live: Dictionary = {}

func valid(data: Variant, complete := false) -> bool:
	if not data is Dictionary or (complete and data.size() != DEFAULTS.size()):
		return false
	for key in data:
		if not DEFAULTS.has(key) or typeof(data[key]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var n := float(data[key])
		var movement_value: bool = key in MOVEMENT.values()
		if not is_finite(n) or n < 0 or n > (200 if movement_value else 100) or (not movement_value and n != floor(n)):
			return false
	return true

func set_base(data: Dictionary) -> bool:
	if not valid(data, true):
		return false
	base = data.duplicate()
	return true

func set_live(data: Dictionary) -> bool:
	if not valid(data):
		return false
	live = data.duplicate()
	return true

func replace_live(keys: Array, data: Dictionary) -> bool:
	var candidate := live.duplicate()
	for key in keys:
		candidate.erase(key)
	candidate.merge(data, true)
	return set_live(candidate)

func stat(key: String) -> float:
	return float(live.get(key, base[key]))
