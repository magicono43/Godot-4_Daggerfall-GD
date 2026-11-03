extends RefCounted
## Departure-to-landing feet displacement, matching pinned DFU AcrobatMotor.
const DAMAGE_THRESHOLD := 5.0
const HARD_THRESHOLD := 2.5
const HP_PER_METRE := 5.0
const DISCONTINUITY_METRES := 0.05
var active := false
var departure_height := 0.0
var tracked := false
var last_position := Vector3.ZERO
var last_landing: Dictionary = {}

static func resolve(distance: float) -> Dictionary:
	if not is_finite(distance) or distance < 0:
		return {}
	var kind := "damage" if distance > DAMAGE_THRESHOLD else ("hard" if distance > HARD_THRESHOLD else "soft")
	return {"distance": distance, "damage": maxi(0, int((distance - DAMAGE_THRESHOLD) * HP_PER_METRE)), "kind": kind}

func reset() -> void:
	active = false
	departure_height = 0.0
	tracked = false
	last_position = Vector3.ZERO
	last_landing.clear()

func begin(at: Vector3, supported: bool) -> void:
	if not at.is_finite():
		reset()
		return
	# Only the player motor moves the body during a tick. Outside displacement
	# is a teleport/fixture placement, not a distance travelled while falling.
	if tracked and at.distance_to(last_position) > DISCONTINUITY_METRES:
		reset()
	if not supported and not active:
		active = true
		departure_height = at.y

func suspend(at: Vector3) -> void:
	# Climbing owns position exclusively. A later release starts a new fall.
	active = false
	departure_height = at.y
	last_position = at
	tracked = true

func finish(before: Vector3, after: Vector3, supported: bool) -> Dictionary:
	if not before.is_finite() or not after.is_finite():
		reset()
		return {}
	last_position = after
	tracked = true
	if not active and not supported:
		active = true
		departure_height = before.y
	if active and supported:
		active = false
		last_landing = resolve(maxf(0.0, departure_height - after.y))
		return last_landing.duplicate()
	return {}
