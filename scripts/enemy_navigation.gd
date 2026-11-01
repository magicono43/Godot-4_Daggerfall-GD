extends RefCounted
## Ground-enemy local steering based on pinned DFU EnemyMotor; no route graph.
## MIT source attribution: reference/LICENSE.txt and enemy_ai_sources.json.
const Steps = preload("res://scripts/step_solver.gd")
var enabled := false
var speed := 2.5
var memory_seconds := 10.0
var memory_left := 0.0
var last_seen := Vector3.ZERO
var state := "idle"
var last_direction := Vector3.ZERO
var saw_previous_tick := false
var search_steps := 0
var supported := false
var desired := Vector3.ZERO
var last_step := 0.0
var detour_goal := Vector3.ZERO
var detour_left := 0.0
var side_left := 0.0
var clockwise := true
var did_side_check := false
var quiet_time := 3.0
var stalled_time := 0.0
var rng := RandomNumberGenerator.new()
var obstacle_cast: ShapeCast3D

func _init() -> void:
	rng.randomize()

func observe(point: Vector3) -> void:
	last_seen = point
	memory_left = memory_seconds

func clear() -> void:
	memory_left = 0.0
	desired = Vector3.ZERO
	supported = false
	state = "idle"
	detour_left = 0.0
	side_left = 0.0
	did_side_check = false
	quiet_time = 3.0
	stalled_time = 0.0
	last_direction = Vector3.ZERO
	saw_previous_tick = false
	search_steps = 0

func probe(body: CharacterBody3D, direction: Vector3) -> Dictionary:
	if not is_instance_valid(obstacle_cast):
		obstacle_cast = ShapeCast3D.new()
		obstacle_cast.enabled = false
		obstacle_cast.collision_mask = 3
		body.add_child(obstacle_cast)
		obstacle_cast.add_exception(body)
	var height: float = body.get_child(0).shape.height
	var radius: float = body.get_child(0).shape.radius
	# DFU ObstacleCheck's lower-body capsule in this project's feet coordinates.
	var bottom := height * (0.5 - 0.1388)
	var span := minf(height, 1.65) * 0.5
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius * 0.5
	capsule.height = span + capsule.radius * 2.0
	obstacle_cast.shape = capsule
	obstacle_cast.position = Vector3.UP * (bottom + span * 0.5)
	obstacle_cast.target_position = body.global_basis.inverse() * direction * (radius / sqrt(2.0))
	obstacle_cast.force_shapecast_update()
	var door: Node = null
	var blocked := false
	for i in obstacle_cast.get_collision_count():
		var collider := obstacle_cast.get_collider(i) as Node
		if collider == body.player:
			continue
		if collider and collider.has_method("request_open"):
			door = collider
		else:
			blocked = true
	# One-metre local floor look-ahead, not knowledge of connected rooms. The
	# upward allowance accommodates Godot's feet origin on 0.4 m stair treads.
	var ahead := body.global_position + direction
	var query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * (height * 0.5 + 0.5), ahead + Vector3.DOWN * 1.5, 1, [body.get_rid()])
	var floor := body.get_world_3d().direct_space_state.intersect_ray(query)
	var fall: bool = not door and (floor.is_empty() or floor.normal.y < cos(body.floor_max_angle))
	return {"blocked": blocked, "fall": fall, "door": door}

func clear_direction(body: CharacterBody3D, direction: Vector3) -> bool:
	var result := probe(body, direction)
	return not result.blocked and not result.fall

func find_detour(body: CharacterBody3D, forward: Vector3) -> Vector3:
	if quiet_time > 2.0:
		side_left = 0.0
		did_side_check = false
	if side_left <= 0.0:
		if not did_side_check:
			var sign := 1.0 if rng.randi_range(0, 1) == 0 else -1.0
			if clear_direction(body, forward.rotated(Vector3.UP, sign * PI / 4.0)):
				clockwise = sign > 0
			elif clear_direction(body, forward.rotated(Vector3.UP, -sign * PI / 4.0)):
				clockwise = sign < 0
			else:
				var target := last_seen - body.global_position
				target.y = 0.0
				clockwise = target.normalized().signed_angle_to(forward, Vector3.UP) > 0
			did_side_check = true
		else:
			clockwise = not clockwise
			did_side_check = false
		side_left = 5.0
	quiet_time = 0.0
	for i in range(1, 9):
		var angle: float = i * PI / 4.0 * (1.0 if clockwise else -1.0)
		var candidate := forward.rotated(Vector3.UP, angle)
		if clear_direction(body, candidate):
			detour_goal = body.global_position + candidate * 2.0
			if detour_left <= 0.0:
				detour_left = 0.75
			stalled_time = 0.0
			return candidate
	# Unlike blindly committing the final blocked DFU candidate, stay still
	# when all eight probes fail; retrying can never authorize a wall crossing.
	detour_left = 0.0
	return Vector3.ZERO

func steering(body: CharacterBody3D, delta: float, visible_player: bool) -> Vector3:
	var to_detour := detour_goal - body.global_position
	if detour_left > 0 and Vector2(to_detour.x, to_detour.z).length() <= 0.3:
		detour_left = 0.0
	var search_goal := last_seen + last_direction * search_steps
	var goal := detour_goal if detour_left > 0 else search_goal
	var offset := goal - body.global_position
	offset.y = 0.0
	if offset.length() <= 0.3:
		if not visible_player and not last_direction.is_zero_approx() and search_steps < 10:
			search_steps += 1
			offset = last_seen + last_direction * search_steps - body.global_position
			offset.y = 0.0
		else:
			state = "searching"
			return Vector3.ZERO
	var direction := offset.normalized()
	var result := probe(body, direction)
	if result.blocked or result.fall or stalled_time >= 0.25:
		direction = find_detour(body, direction)
		state = "detour" if not direction.is_zero_approx() else "blocked"
	else:
		state = "detour" if detour_left > 0 else ("pursuing" if visible_player else "last seen")
	if direction.is_zero_approx():
		return Vector3.ZERO
	var yaw := (-body.global_basis.z).signed_angle_to(direction, Vector3.UP)
	# DFU turns 20 degrees per classic tick. Smooth that rate at physics Hz;
	# enhanced movement can turn while advancing when the target is visible.
	body.rotate_y(clampf(yaw, -deg_to_rad(20.0) / 0.0549254 * delta, deg_to_rad(20.0) / 0.0549254 * delta))
	if not visible_player and absf(yaw) > deg_to_rad(5.625):
		state = "turning"
		return Vector3.ZERO
	var query := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP, body.global_position + Vector3.UP + direction * 1.2, 1, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("request_open"):
		hit.collider.request_open(body)
		state = "door"
		return Vector3.ZERO
	return direction * speed

func tick(body: CharacterBody3D, delta: float, visible_player: bool) -> void:
	if body.player.is_dead() or not body.player.controls_active:
		clear()
		move(body, Vector3.ZERO, delta)
		if body.mobile and body.mobile.state == "move":
			body.mobile.set_state("idle")
		return
	memory_left = maxf(0.0, memory_left - delta)
	detour_left = maxf(0.0, detour_left - delta)
	side_left = maxf(0.0, side_left - delta)
	quiet_time += delta
	if visible_player and body.global_position.distance_to(body.player.global_position) < 20.0:
		var change: Vector3 = body.player.global_position - last_seen
		change.y = 0.0
		last_direction = change.normalized() if saw_previous_tick and change.length() < 2.0 else Vector3.ZERO
		observe(body.player.global_position)
		search_steps = 0
		saw_previous_tick = true
	else:
		saw_previous_tick = false
	desired = Vector3.ZERO
	var busy: bool = body.melee.phase != "idle" or (body.mobile and body.mobile.state == "hurt")
	if busy:
		state = "attacking"
	elif memory_left <= 0.0:
		state = "idle"
		detour_left = 0.0
	elif body.melee.can_reach(body):
		state = "in range"
	elif body.global_position.distance_to(body.home) > 60.0:
		state = "leashed"
		detour_left = 0.0
	else:
		desired = steering(body, delta, visible_player)
	var before := body.global_position
	move(body, desired, delta)
	var traveled := body.global_position - before
	var moving := Vector2(traveled.x, traveled.z).length() > 0.001
	stalled_time = stalled_time + delta if not desired.is_zero_approx() and not moving else 0.0
	if body.mobile and body.mobile.state in ["idle", "move"]:
		var pose := "move" if moving else "idle"
		if body.mobile.state != pose:
			body.mobile.set_state(pose)

func move(body: CharacterBody3D, horizontal: Vector3, delta: float) -> void:
	var grounded := body.is_on_floor() or supported
	supported = false
	last_step = 0.0
	# Refuse an unsupported next foot position; steering never grants flying.
	if grounded and not horizontal.is_zero_approx():
		var ahead := body.global_transform
		ahead.origin += horizontal * delta
		var support := PhysicsTestMotionResult3D.new()
		var contact := Steps.sweep(body, ahead, Vector3.DOWN * 0.5, support)
		var walkable := contact and Steps.walkable(body, support)
		if contact and not walkable and support.get_collision_normal().y > 0.001:
			walkable = not Steps.tread_at_contact(body, support.get_collision_point(), support.get_collision_normal(), support.get_collider()).is_empty()
		if contact and not walkable and support.get_collision_normal().y > 0.05:
			# On descent the prospective rounded contact can be steeper than the
			# current floor contact. Accept continuity on that same solid only;
			# a separate look-ahead floor probe rejects genuine drops.
			for i in body.get_slide_collision_count():
				var floor := body.get_slide_collision(i)
				if floor.get_collider() == support.get_collider() and floor.get_normal().y >= cos(body.floor_max_angle):
					walkable = true
		if not walkable:
			var query := PhysicsRayQueryParameters3D.create(ahead.origin + Vector3.UP * 0.5, ahead.origin + Vector3.DOWN * 0.5, 1, [body.get_rid()])
			var face := body.get_world_3d().direct_space_state.intersect_ray(query)
			walkable = not face.is_empty() and face.normal.y >= cos(body.floor_max_angle)
		if not walkable:
			horizontal = Vector3.ZERO
	body.velocity.x = horizontal.x
	body.velocity.z = horizontal.z
	body.velocity.y = -2.0 if grounded else body.velocity.y - 16.0 * delta
	var before := body.global_transform
	body.move_and_slide()
	if grounded:
		var motion := horizontal * delta
		var traveled := body.global_position - before.origin
		var step: Dictionary = {}
		if motion.length() > 0.0001 and traveled.dot(motion.normalized()) < motion.length() - 0.001:
			step = Steps.up(body, before, motion, 0.5, true)
		if step.is_empty() and not body.is_on_floor():
			step = Steps.down(body, 0.5)
		if not step.is_empty():
			last_step = step.transform.origin.y - body.global_position.y
			body.global_transform = step.transform
			supported = true
			body.velocity = Vector3(0, -2, 0)
			body.move_and_slide()
