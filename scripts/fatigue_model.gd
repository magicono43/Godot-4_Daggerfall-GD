extends RefCounted
## DFU raw fatigue uses 64 units per displayed point. Time advances at 12x.
const UNITS := 64
const TIME_SCALE := 12.0
const LOSSES := {"normal": 11, "running": 88, "climbing": 22}
const JUMP_COST := 11
const SWING_COST := 11
const MAX_RAW := 12800 # (100 Strength + 100 Endurance) * 64.
const MAX_SECONDS := 31557600000.0
var character: RefCounted
var current := 0
var game_seconds := 0.0

func setup(state: RefCounted) -> void:
	character = state
	current = maximum()

func maximum() -> int:
	return int(character.stat("strength") + character.stat("endurance")) * UNITS

func sync_capacity() -> void:
	current = clampi(current, 0, maximum())

func exhausted() -> bool:
	sync_capacity()
	return current == 0

func spend(amount: int) -> void:
	sync_capacity()
	current = maxi(0, current - maxi(0, amount))

func tick(delta: float, activity: String, athleticism := false, improved := false) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	sync_capacity()
	var previous_minute := int(floor(game_seconds / 60.0))
	game_seconds = minf(MAX_SECONDS, game_seconds + delta * TIME_SCALE)
	var minutes := int(floor(game_seconds / 60.0)) - previous_minute
	var multiplier := 0.8 if athleticism and improved else (0.9 if athleticism else 1.0)
	spend(minutes * int(float(LOSSES.get(activity, LOSSES.normal)) * multiplier))

func jump(athleticism := false, improved := false) -> void:
	var multiplier := 0.8 if athleticism and improved else (0.9 if athleticism else 1.0)
	spend(int(JUMP_COST * multiplier))

func fatigue_recovery() -> int:
	return maxi(int(maximum() / 8), 1)

func health_recovery(max_health: int) -> int:
	# Supported subset: no rapid-healing advantages. DFU integer Medical term.
	var endurance_bonus := int(floor(character.stat("endurance") / 10.0)) - 5
	var medical_term := int((int(character.stat("medical")) + 60) * max_health / 1000)
	return maxi(endurance_bonus + medical_term, 1)

func rest_hour(health: RefCounted) -> void:
	if health.current <= 0:
		return
	sync_capacity()
	current = mini(maximum(), current + fatigue_recovery())
	health.restore(health_recovery(health.maximum))
	game_seconds = minf(MAX_SECONDS, game_seconds + 3600.0)

func snapshot() -> Dictionary:
	sync_capacity()
	return {"current": current, "game_seconds": game_seconds}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 2:
		return false
	var value: Variant = data.get("current")
	var seconds: Variant = data.get("game_seconds")
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value == floor(float(value)) and value >= 0 and value <= MAX_RAW and typeof(seconds) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(seconds)) and seconds >= 0 and seconds <= MAX_SECONDS

func restore(data: Dictionary) -> void:
	current = int(data.current)
	game_seconds = float(data.game_seconds)
	sync_capacity()
