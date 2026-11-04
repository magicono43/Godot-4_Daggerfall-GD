extends RefCounted
## Local capsule-tested flight. Source: pinned EnemyMotor's flying destination,
## no gravity, and obstacle detours; this is not a global path planner.
var enabled := false
var speed := 2.5 # Existing enemy tuning; not a newly claimed classic speed formula.
var memory_seconds := 10.0
var memory_left := 0.0
var last_seen := Vector3.ZERO
var state := "hovering"
var desired := Vector3.ZERO
var detour_goal := Vector3.ZERO
var detour_left := 0.0
var last_step := 0.0
var doors: Array[AnimatableBody3D] = []

func clear() -> void:
	memory_left = 0.0
	desired = Vector3.ZERO
	detour_left = 0.0
	state = "hovering"

func observe(point: Vector3) -> void:
	last_seen = point
	memory_left = memory_seconds

func clear_direction(body: CharacterBody3D, direction: Vector3, distance: float = 1.0) -> bool:
	return clear_segment(body, body.global_position, body.global_position + direction * distance)

func clear_segment(body: CharacterBody3D, start: Vector3, end: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body.get_child(0).shape
	query.transform = body.global_transform * body.get_child(0).transform
	query.transform.origin += start - body.global_position
	query.motion = end - start
	query.margin = 0.015
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid(), body.player.get_rid()]
	return body.get_world_3d().direct_space_state.cast_motion(query)[0] > 0.999

func doorway_goal(body: CharacterBody3D) -> Vector3:
	var best := Vector3.INF
	var nearest := 4.0
	for door in doors:
		if not door.opened or door.busy or door.global_position.distance_to(body.global_position) > 6.0:
			continue
		var bounds: AABB = door.get_child(0).mesh.get_aabb()
		# Use the closed leaf's frame even though its collision has swung aside.
		var frame := Transform3D(door.get_parent().global_basis * door.closed_basis, door.global_position)
		var centre := frame * bounds.get_center()
		var normal := frame.basis.z.normalized()
		var side := normal.dot(body.global_position - centre)
		if side * normal.dot(last_seen - centre) >= 0.0:
			continue
		var distance := centre.distance_to(body.global_position)
		if distance >= nearest:
			continue
		var near := centre + normal * signf(side) * 0.65
		var far := centre - normal * signf(side) * 0.65
		if not clear_segment(body, near, far):
			continue
		if clear_segment(body, body.global_position, far):
			best = far
		elif clear_segment(body, body.global_position, near):
			best = near
		else:
			continue
		nearest = distance
	return best

func steering(body: CharacterBody3D, delta: float) -> Vector3:
	detour_left = maxf(0.0, detour_left - delta)
	if body.global_position.distance_to(detour_goal) < 0.3:
		detour_left = 0.0
	var goal := detour_goal if detour_left > 0 else last_seen
	var portal := doorway_goal(body)
	if portal.is_finite():
		goal = portal
		detour_goal = portal
		detour_left = 0.75
	if not portal.is_finite() and goal.y < body.global_position.y:
		# Keep a low target's requested centre above the local floor before
		# obstacle selection, so the floor is not mistaken for a side detour.
		var floor_ray := PhysicsRayQueryParameters3D.create(body.global_position, body.global_position + Vector3.DOWN * 16.0, 1, [body.get_rid(), body.player.get_rid()])
		var support := body.get_world_3d().direct_space_state.intersect_ray(floor_ray)
		if not support.is_empty() and support.normal.y > 0.5:
			goal.y = maxf(goal.y, support.position.y + float(body.get_child(0).shape.height) * 0.5 + 0.15)
	var offset := goal - body.global_position
	if offset.length() < 0.2:
		return Vector3.ZERO
	var forward := offset.normalized()
	if not clear_direction(body, forward, minf(1.0, offset.length())):
		# Prefer progress toward the remembered goal. Commit briefly to a tested
		# side/up/down detour so repeated probes do not alternate at a corner.
		var best := Vector3.ZERO
		var score := -INF
		for pitch in [0.0, 0.65, -0.65]:
			for angle in [45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0, 0.0]:
				var candidate := forward.rotated(Vector3.UP, deg_to_rad(angle))
				candidate.y += pitch
				candidate = candidate.normalized()
				if clear_direction(body, candidate) and candidate.dot(forward) > score:
					best = candidate
					score = candidate.dot(forward)
		if best.is_zero_approx():
			state = "blocked"
			return Vector3.ZERO
		forward = best
		detour_goal = body.global_position + best * 1.5
		detour_left = 0.75
		state = "detour"
	else:
		state = "detour" if detour_left > 0 else "pursuing"
	# EnemyMotor protects flyers from descending too near the floor. Actual
	# wall/ceiling/floor collision is always handled by the full actor capsule.
	if not portal.is_finite() and forward.y < 0:
		var half_height: float = body.get_child(0).shape.height * 0.5
		var ray := PhysicsRayQueryParameters3D.create(body.global_position, body.global_position + Vector3.DOWN * (half_height + 0.15), 1, [body.get_rid(), body.player.get_rid()])
		var floor := body.get_world_3d().direct_space_state.intersect_ray(ray)
		if not floor.is_empty() and floor.normal.y > 0.5:
			forward.y = 0.0
	var flat := Vector3(forward.x, 0, forward.z)
	if not flat.is_zero_approx():
		var yaw := (-body.global_basis.z).signed_angle_to(flat.normalized(), Vector3.UP)
		body.rotate_y(clampf(yaw, -deg_to_rad(20.0) / 0.0549254 * delta, deg_to_rad(20.0) / 0.0549254 * delta))
	return forward * speed

func move(body: CharacterBody3D, motion: Vector3, _delta: float) -> void:
	body.velocity = motion
	body.move_and_slide()

func tick(body: CharacterBody3D, delta: float, visible_player: bool) -> void:
	if not body.player.controls_active or body.player.is_dead():
		clear()
		move(body, Vector3.ZERO, delta)
		return
	memory_left = maxf(0.0, memory_left - delta)
	if visible_player and body.global_position.distance_to(body.player.global_position) < 20.0:
		observe(body.player.global_position + Vector3.UP * float(body.player.capsule_collision.shape.height) * 0.5)
	desired = Vector3.ZERO
	if body.melee.phase != "idle" or body.mobile.state == "hurt":
		state = "attacking"
	elif body.melee.enabled and body.melee.can_reach(body):
		state = "in range"
	elif memory_left <= 0.0:
		state = "hovering"
	elif body.global_position.distance_to(body.home) > 60.0:
		state = "leashed"
	else:
		desired = steering(body, delta)
	move(body, desired, delta)
	if body.mobile.state in ["idle", "move"]:
		body.mobile.set_state("move" if not desired.is_zero_approx() else "idle")
