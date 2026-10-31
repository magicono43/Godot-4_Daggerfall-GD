extends RefCounted
## Deterministic collision motor; skill and slip policy can be added separately.
const Steps = preload("res://scripts/step_solver.gd")
const Corners = preload("res://scripts/climbing_corners.gd")
var corners := Corners.new()
var active := false
var attach_time := 0.0
var cooldown := 0.0
var wall_normal := Vector3.ZERO
var last_position := Vector3.ZERO
var tracked := false
var transition := "walking"
var entry_path: Array[Vector3] = []
var entry_start := Vector3.ZERO
var entry_index := 0

func reset() -> void:
	active = false
	attach_time = 0.0
	cooldown = 0.0
	wall_normal = Vector3.ZERO
	tracked = false
	transition = "reset"
	entry_path.clear()
	entry_index = 0
	corners.reset()

func climbable_wall(hit: Dictionary, vertical_limit: float = 0.15) -> bool:
	if hit.is_empty() or not hit.collider is StaticBody3D or absf(hit.normal.y) > vertical_limit:
		return false
	return not (hit.collider.has_method("interact") or hit.collider.is_in_group("slice_boundaries") or hit.collider.get_meta("section_role", "") == "prop" or not hit.collider.get_meta("climbable", true))

func ray_between(body: CharacterBody3D, start: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, body.collision_mask, [body.get_rid()])
	return body.get_world_3d().direct_space_state.intersect_ray(query)

func probe(body: CharacterBody3D, direction: Vector3, height: float) -> Dictionary:
	var start := body.global_position + Vector3.UP * height
	var query := PhysicsRayQueryParameters3D.create(start, start + direction * (body.CAPSULE_RADIUS + (0.6 if active else 0.12)), body.collision_mask, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not climbable_wall(hit, 0.5 if active or height < 0.2 else 0.15):
		return {}
	return hit

func detach(body: CharacterBody3D, reason: String, eject: bool = false) -> void:
	active = false
	attach_time = 0.0
	cooldown = 0.4
	transition = reason
	corners.clear()
	entry_path.clear()
	body.velocity = wall_normal * 3.0 + Vector3.UP * 2.0 if eject else Vector3.ZERO
	body.flight_horizontal = Vector3(body.velocity.x, 0, body.velocity.z)
	body.stair_supported = false
	body.grounded_time = 0.0
	if eject:
		# Entry uses checked sweeps, so its last engine floor flag may still
		# describe the platform. Launch now to clear that stale support flag.
		var snap := body.floor_snap_length
		body.floor_snap_length = 0.0
		body.move_and_slide()
		body.floor_snap_length = snap

func start_ledge_descent(body: CharacterBody3D, input: Vector2) -> bool:
	if cooldown > 0 or not body.controls_active or input.y < 0.5 or absf(input.x) > 0.1 or not body.is_grounded() or body.velocity.y > 0.1 or Input.is_action_pressed("jump"):
		return false
	var back: Vector3 = body.global_basis.z
	back.y = 0.0
	back = back.normalized()
	var origin := body.global_position
	var support := ray_between(body, origin + Vector3.UP * 0.1, origin + Vector3.DOWN * 0.2)
	if support.is_empty() or support.normal.y < cos(body.floor_max_angle):
		return false
	# A real drop immediately behind the feet; ordinary treads and small
	# steps must still use the ground/step motor.
	var edge := origin + back * 0.15
	if not ray_between(body, edge + Vector3.UP * 0.1, edge + Vector3.DOWN * 0.65).is_empty():
		return false
	var wall := ray_between(body, origin + back * 0.8 + Vector3.DOWN * 0.3, origin - back * 0.2 + Vector3.DOWN * 0.3)
	if not climbable_wall(wall) or back.dot(wall.normal) < 0.8:
		return false
	var normal: Vector3 = Vector3(wall.normal.x, 0, wall.normal.z).normalized()
	var top_point: Vector3 = wall.position - normal * 0.06
	top_point.y = origin.y
	var top := ray_between(body, top_point + Vector3.UP * 0.12, top_point + Vector3.DOWN * 0.2)
	if top.is_empty() or top.normal.y < cos(body.floor_max_angle) or absf(top.position.y - support.position.y) > 0.12:
		return false
	# Clear the complete capsule past the lip before lowering it. Preserve
	# the tangential position and keep the wall within normal probe reach.
	var outward: Vector3 = origin + normal * (body.CAPSULE_RADIUS + 0.04 - (origin - wall.position).dot(normal))
	if outward.distance_to(origin) > 0.65:
		return false
	var start := body.global_transform
	var hit := PhysicsTestMotionResult3D.new()
	if Steps.sweep(body, start, outward - origin, hit):
		return false
	start.origin = outward
	var lower: Vector3 = outward + Vector3.DOWN * 0.3
	if Steps.sweep(body, start, lower - outward, hit):
		return false
	var contact := ray_between(body, lower + Vector3.UP * 0.15, lower + Vector3.UP * 0.15 - normal * (body.CAPSULE_RADIUS + 0.12))
	if not climbable_wall(contact) or contact.collider != wall.collider or contact.normal.dot(normal) < 0.95:
		return false
	active = true
	wall_normal = normal
	attach_time = 0.0
	entry_start = origin
	entry_path.assign([outward, lower])
	entry_index = 0
	body.velocity = Vector3.ZERO
	body.flight_horizontal = Vector3.ZERO
	body.stair_supported = false
	body.grounded_time = 0.0
	transition = "ledge descent"
	return true

func move_ledge_entry(body: CharacterBody3D, delta: float, input: Vector2, speed: float) -> void:
	# Entry is part of climbing: S follows the checked path, idle holds,
	# and W reverses it onto the platform. Recheck collision each tick.
	var endpoint := entry_path[1] + Vector3.UP * 0.15
	var contact := ray_between(body, endpoint, endpoint - wall_normal * (body.CAPSULE_RADIUS + 0.12))
	if not climbable_wall(contact) or contact.normal.dot(wall_normal) < 0.95:
		detach(body, "lost ledge wall")
		return
	if input.y == 0:
		body.velocity = Vector3.ZERO
		return
	var target := entry_path[entry_index] if input.y > 0 else (entry_start if entry_index == 0 else entry_path[entry_index - 1])
	var motion := body.global_position.direction_to(target) * minf(speed * delta, body.global_position.distance_to(target))
	var hit := PhysicsTestMotionResult3D.new()
	if Steps.sweep(body, body.global_transform, motion, hit):
		detach(body, "blocked ledge entry")
		return
	body.global_position += motion
	body.velocity = motion / delta
	if body.global_position.distance_to(target) > 0.001:
		return
	if input.y > 0 and entry_index == 0:
		entry_index = 1
	elif input.y < 0 and entry_index == 1:
		entry_index = 0
	else:
		var returned := input.y < 0
		entry_path.clear()
		if returned:
			detach(body, "returned to ledge")
		else:
			transition = "climbing"
		# Refresh floor flags without snapping back onto the old lip.
		var snap := body.floor_snap_length
		body.floor_snap_length = 0.0
		body.velocity = Vector3.DOWN * 0.1
		body.move_and_slide()
		body.floor_snap_length = snap

func mantle(body: CharacterBody3D, direction: Vector3) -> bool:
	# Verify the entire capsule up/across/down before committing a nearby top.
	var start := body.global_transform
	var hit := PhysicsTestMotionResult3D.new()
	if Steps.sweep(body, start, Vector3.UP * 0.55, hit):
		return false
	var raised := start
	raised.origin.y += 0.55
	var across: Vector3 = direction * (body.CAPSULE_RADIUS * 2.0 + 0.12)
	if Steps.sweep(body, raised, across, hit):
		return false
	raised.origin += across
	if not Steps.sweep(body, raised, Vector3.DOWN * 0.60, hit) or not Steps.walkable(body, hit):
		return false
	var rise := 0.55 + hit.get_travel().y
	if rise < -0.03 or rise > 0.5:
		return false
	raised.origin += hit.get_travel() + Vector3.UP * Steps.CLEARANCE
	body.global_transform = raised
	body.step_camera_offset -= rise
	detach(body, "ledge")
	body.velocity = Vector3.DOWN * 0.2
	body.move_and_slide()
	return true

func tick(body: CharacterBody3D, delta: float, input: Vector2, resolved: Dictionary) -> bool:
	if tracked and body.global_position.distance_to(last_position) > 1.0:
		reset()
	cooldown = maxf(0.0, cooldown - delta)
	if not active:
		start_ledge_descent(body, input)
	var direction: Vector3 = -wall_normal if active else -body.global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var chest := probe(body, direction, 1.0)
	var feet := probe(body, direction, 0.15)
	# A tall pedestal can block the capsule below a recessed/tapered shaft.
	# Require contact above the maximum normal step, not a low stair riser.
	if not active and chest.is_empty():
		chest = probe(body, direction, maxf(0.65, float(body.movement.profile.values.stepping.max_height_metres) + 0.1))
	var displacement := body.global_position - last_position
	var blocked := tracked and Vector2(displacement.x, displacement.z).length() < 0.01
	if active:
		if body.controls_active and Input.is_action_just_pressed("jump"):
			detach(body, "ejected", true)
		elif not entry_path.is_empty():
			move_ledge_entry(body, delta, input, float(resolved.climb_walk_speed))
		elif corners.active:
			corners.move(body, self, delta, input, resolved)
		elif input.y > 0 and body.is_on_floor():
			detach(body, "ground")
		elif input.y < 0 and mantle(body, direction):
			pass
		elif chest.is_empty() and feet.is_empty():
			detach(body, "lost wall")
		else:
			var contact: Dictionary = chest if not chest.is_empty() else feet
			wall_normal = Vector3(contact.normal.x, 0, contact.normal.z).normalized()
			if not corners.follow(body, self, contact, delta, input, resolved):
				var tangent := Vector3.UP.cross(wall_normal).normalized()
				var motion := Vector2(input.x, -input.y).limit_length()
				body.velocity = (tangent * motion.x + Vector3.UP * motion.y) * float(resolved.climb_walk_speed) - wall_normal * float(resolved.walk_speed)
				body.stair_supported = false
				body.move_and_slide()
				body.flight_horizontal = Vector3.ZERO
				if input.y > 0 and body.is_on_floor():
					detach(body, "ground")
		last_position = body.global_position
		tracked = true
		return true
	if cooldown <= 0 and body.controls_active and input.y < -0.5 and absf(input.x) < 0.1 and blocked and not chest.is_empty() and not feet.is_empty() and body.is_grounded() and not Input.is_action_pressed("jump") and direction.dot(-chest.normal) > 0.8:
		attach_time += delta
		if attach_time >= float(body.movement.profile.values.climbing.attach_delay_seconds):
			active = true
			wall_normal = chest.normal
			body.velocity = Vector3.ZERO
			body.flight_horizontal = Vector3.ZERO
			body.stair_supported = false
			body.step_camera_offset = 0.0
			transition = "climbing"
	else:
		attach_time = 0.0
	last_position = body.global_position
	tracked = true
	return active
