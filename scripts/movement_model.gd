extends RefCounted
## Pure parameter resolution. Future skill/effect systems supply live inputs here;
## the motor consumes a snapshot without knowing how a character earned them.
const Profile = preload("res://scripts/movement_profile.gd")
const SPEED_UNITS := 39.5
const WALK_BASE := 150.0
const CHANNELS := ["walk", "run", "jump", "gravity", "swim", "climb", "crouch"]
var profile := Profile.new()
var live_stats: Dictionary = {}
var live_effects: Dictionary = {}
var modifiers: Dictionary = {}

func set_live_stats(overrides: Dictionary) -> bool:
	for key in overrides:
		if not Profile.DEFAULTS.baseline.has(key) or not profile.valid_value("baseline", key, overrides[key]):
			return false
	live_stats = overrides.duplicate()
	return true

func set_live_effects(overrides: Dictionary) -> bool:
	for key in overrides:
		if not Profile.DEFAULTS.effects.has(key) or not overrides[key] is bool:
			return false
	live_effects = overrides.duplicate()
	return true

func set_modifier(id: String, factors: Dictionary) -> bool:
	if id.is_empty():
		return false
	for key in factors:
		var value: Variant = factors[key]
		if key not in CHANNELS or typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or value <= 0 or value > 10:
			return false
	modifiers[id] = factors.duplicate()
	return true

func remove_modifier(id: String) -> void:
	modifiers.erase(id)

func stat(key: String) -> float:
	return float(live_stats.get(key, profile.values.baseline[key]))

func effect(key: String) -> bool:
	return bool(live_effects.get(key, profile.values.effects[key]))

func factor(channel: String) -> float:
	var result := 1.0
	var ids: Array = modifiers.keys()
	ids.sort()
	for id in ids:
		result *= float(modifiers[id].get(channel, 1.0))
	return result

func resolve() -> Dictionary:
	var speed := stat("speed_attribute")
	var drag := 0.5 * (100.0 - maxf(speed, 30.0))
	var walk := (speed + WALK_BASE - drag) / SPEED_UNITS
	var run := (speed + WALK_BASE) / SPEED_UNITS * (1.35 + stat("running_skill") / 200.0)
	var bonus := 1.0 + stat("jumping_skill") * float(profile.values.jump.skill_bonus) / 100.0
	if effect("athleticism"):
		bonus += float(profile.values.jump.athleticism_bonus)
		if effect("improved_athleticism"):
			bonus += float(profile.values.jump.improved_athleticism_bonus)
	if effect("enhanced_jumping"):
		bonus += float(profile.values.jump.spell_bonus)
	walk *= float(profile.values.locomotion.walk_multiplier) * factor("walk")
	run *= float(profile.values.locomotion.run_multiplier) * factor("run")
	return {
		"walk_speed": walk,
		"run_speed": run,
		# DFU crouch base has no walk drag; Running still affects crouched run.
		"crouch_walk_speed": (speed + 50.0) / SPEED_UNITS * float(profile.values.locomotion.walk_multiplier) * factor("walk") * factor("crouch"),
		"crouch_run_speed": (speed + 50.0) / SPEED_UNITS * (1.35 + stat("running_skill") / 200.0) * float(profile.values.locomotion.run_multiplier) * factor("run") * factor("crouch"),
		"jump_velocity": float(profile.values.jump.base_velocity) * bonus * factor("jump"),
		"gravity": float(profile.values.physics.gravity) * factor("gravity"),
		"air_control": bool(profile.values.locomotion.air_control) or effect("enhanced_jumping"),
		# Swimming is a parameter hook. The separate climbing motor consumes
		# climb speed; skill-based success/slip policy is not implemented yet.
		"swim_walk_speed": walk * (stat("swimming_skill") / 200.0 + 0.25) * factor("swim"),
		"climb_walk_speed": walk / 3.0 * (2.0 if effect("enhanced_climbing") else 1.0) * factor("climb")
	}
