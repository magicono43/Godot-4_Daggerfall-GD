extends RefCounted
## Transactional tuning: invalid reloads preserve the last usable configuration.
const DEFAULTS := {
	"baseline": {"speed_attribute": 50.0, "running_skill": 25.0, "jumping_skill": 25.0, "swimming_skill": 25.0, "climbing_skill": 25.0},
	"locomotion": {"response": "instant", "axis_response_per_second": 9.8, "walk_multiplier": 1.0, "run_multiplier": 1.0, "strafe_multiplier": 1.0, "backward_multiplier": 1.0, "limit_diagonal_speed": true, "ground_acceleration": 24.0, "ground_braking": 32.0, "air_control": false, "air_acceleration": 8.0, "air_braking": 8.0},
	"jump": {"base_velocity": 4.5, "skill_bonus": 0.5, "athleticism_bonus": 0.1, "improved_athleticism_bonus": 0.1, "spell_bonus": 0.6, "forward_boost_fraction": 0.05, "minimum_grounded_time": 0.1, "repeat_while_held": true},
	"physics": {"gravity": 20.0, "ground_stick_speed": 0.2, "floor_snap_metres": 0.35, "floor_max_angle_degrees": 70.0, "floor_constant_speed": false},
	"stepping": {"enabled": true, "max_height_metres": 0.5, "camera_smoothing_speed": 12.0, "camera_smoothing_rate": 18.0},
	"look": {"radians_per_pixel": 0.0023, "max_pitch_degrees": 83.0, "invert_y": false},
	"effects": {"athleticism": false, "improved_athleticism": false, "enhanced_jumping": false, "enhanced_climbing": false}
}
var values: Dictionary = DEFAULTS.duplicate(true)
var error := ""

func load_file(path: String = "res://movement.cfg") -> bool:
	var file := ConfigFile.new()
	var result := file.load(path)
	if result != OK:
		error = "Cannot read %s (error %d); previous/default movement retained" % [path, result]
		return false
	var candidate: Dictionary = DEFAULTS.duplicate(true)
	for section in file.get_sections():
		if not DEFAULTS.has(section):
			return fail("Unknown movement section: " + section)
		for key in file.get_section_keys(section):
			if not DEFAULTS[section].has(key):
				return fail("Unknown movement key: %s.%s" % [section, key])
			var value: Variant = file.get_value(section, key)
			if not valid_value(section, key, value):
				return fail("Invalid movement value: %s.%s" % [section, key])
			candidate[section][key] = value
	values = candidate
	error = ""
	return true

func fail(message: String) -> bool:
	error = message + "; previous/default movement retained"
	return false

func valid_value(section: String, key: String, value: Variant) -> bool:
	var example: Variant = DEFAULTS[section][key]
	if example is bool:
		return value is bool
	if example is String:
		return value is String and value in ["instant", "dfu_axes", "smooth"]
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return false
	if section == "baseline":
		return value >= 0 and value <= 200
	match key:
		"floor_max_angle_degrees":
			return value >= 1 and value < 89
		"max_pitch_degrees":
			return value >= 1 and value < 90
		"radians_per_pixel":
			return value > 0 and value <= 0.05
		"floor_snap_metres":
			return value >= 0 and value <= 1
		"max_height_metres":
			return value >= 0 and value <= 0.75
		"camera_smoothing_speed", "camera_smoothing_rate":
			return value > 0 and value <= 100
		"minimum_grounded_time":
			return value >= 0 and value <= 2
		"gravity":
			return value > 0 and value <= 100
		"base_velocity":
			return value > 0 and value <= 30
		"walk_multiplier", "run_multiplier", "strafe_multiplier", "backward_multiplier":
			return value > 0 and value <= 10
		"ground_acceleration", "ground_braking", "air_acceleration", "air_braking", "axis_response_per_second":
			return value > 0 and value <= 200
	return value >= 0 and value <= 20
