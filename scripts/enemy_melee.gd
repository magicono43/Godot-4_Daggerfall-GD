extends RefCounted
## Stationary prototype attack policy. Timing/damage are not DFU RPG formulas.
var enabled := false
var reach := 1.8
var windup := 0.65
var recovery := 1.0
var damage := 10
var phase := "idle"
var remaining := 0.0
var direction := Vector3.ZERO
var last_result := ""

func cancel() -> void:
	phase = "idle"
	remaining = 0.0

func can_reach(body: CharacterBody3D) -> bool:
	var target: CharacterBody3D = body.player
	var offset := target.global_position - body.global_position
	# Feet-based height rejection prevents attacks through floors/upper landings.
	if absf(offset.y) > 1.2:
		return false
	offset.y = 0.0
	if offset.length() > reach:
		return false
	if phase == "windup" and offset.length() > 0.25 and direction.dot(offset.normalized()) < cos(deg_to_rad(60.0)):
		return false
	var centre: Vector3 = target.global_position + Vector3.UP * float(target.capsule_collision.shape.height) * 0.5
	var query := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP * 0.5, centre, 3, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target

func tick(body: CharacterBody3D, delta: float) -> void:
	if not enabled or body.health.current <= 0 or not is_instance_valid(body.player) or body.player.is_dead() or not body.player.controls_active:
		cancel()
		return
	if phase == "idle":
		if can_reach(body):
			direction = body.player.global_position - body.global_position
			direction.y = 0.0
			direction = direction.normalized()
			if not direction.is_zero_approx():
				body.look_at(body.global_position + direction, Vector3.UP)
			phase = "windup"
			remaining = windup
		return
	remaining -= delta
	if remaining > 0:
		return
	if phase == "windup":
		last_result = "miss"
		# Re-evaluate geometry at the strike, not when the attack was requested.
		if can_reach(body) and body.player.receive_damage(damage):
			last_result = "hit"
		phase = "recovery"
		remaining = recovery
	else:
		cancel()
