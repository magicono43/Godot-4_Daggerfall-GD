extends RefCounted
## DFU Shield: finite damage pool, timed expiry, duration stacking with capped top-up.
const MAX_SECONDS := 86400.0
const MAX_POOL := 10000
var capacity := 0
var current := 0
var remaining := 0.0

func active() -> bool:
	return current > 0 and remaining > 0

func cast(magnitude: int, seconds: float) -> void:
	if active():
		current = mini(capacity, current + magnitude)
		remaining = minf(MAX_SECONDS, remaining + seconds)
	else:
		capacity = magnitude
		current = magnitude
		remaining = seconds

func absorb(amount: int) -> int:
	if amount <= 0 or not active():
		return amount
	var absorbed := mini(current, amount)
	current -= absorbed
	if current == 0:
		clear()
	return amount - absorbed

func advance(seconds: float) -> void:
	if active():
		remaining = maxf(0, remaining - maxf(0, seconds))
		if remaining == 0:
			clear()

func clear() -> void:
	capacity = 0
	current = 0
	remaining = 0

func snapshot() -> Dictionary:
	return {"capacity":capacity, "current":current, "seconds":remaining}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 3:
		return false
	for key in ["capacity", "current"]:
		var value: Variant = data.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value != floor(float(value)) or value < 0 or value > MAX_POOL:
			return false
	var seconds: Variant = data.get("seconds")
	if typeof(seconds) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(seconds)) or seconds < 0 or seconds > MAX_SECONDS:
		return false
	return (data.current == 0 and data.capacity == 0 and seconds == 0) or (data.current > 0 and data.capacity >= data.current and seconds > 0)

func restore(data: Dictionary) -> void:
	capacity = int(data.capacity)
	current = int(data.current)
	remaining = float(data.seconds)
