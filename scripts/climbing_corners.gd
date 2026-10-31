extends RefCounted
## Geometry-driven wall following. Camera/body yaw is never changed.
const Steps = preload("res://scripts/step_solver.gd")
var active := false
var state: Dictionary = {}
var inside_turns := 0
var outside_turns := 0

func clear() -> void:
	active = false
	state.clear()

func reset() -> void:
	clear()
	inside_turns = 0
	outside_turns = 0

func intersection(first: Dictionary, second: Dictionary, y: float) -> Vector3:
	var a: Vector3 = Vector3(first.normal.x, 0, first.normal.z).normalized()
	var b: Vector3 = Vector3(second.normal.x, 0, second.normal.z).normalized()
	var d0 := a.dot(first.position)
	var d1 := b.dot(second.position)
	var determinant := a.x * b.z - a.z * b.x
	return Vector3((d0 * b.z - a.z * d1) / determinant, y, (a.x * d1 - d0 * b.x) / determinant)

func connected(body: CharacterBody3D, motor: RefCounted, pivot: Vector3, first: Vector3, second: Vector3, sign_x: float, height: float) -> bool:
	# Both faces must actually reach the same edge. A nearby disconnected wall
	# must not turn into a corner just because its infinite plane intersects.
	for pair in [[first, -Vector3.UP.cross(first) * sign_x], [second, Vector3.UP.cross(second) * sign_x]]:
		var normal: Vector3 = pair[0]
		var point: Vector3 = pivot + Vector3.UP * height + pair[1] * 0.035 + normal * 0.15
		var hit: Dictionary = motor.ray_between(body, point, point - normal * 0.3)
		if not motor.climbable_wall(hit) or hit.normal.dot(normal) < 0.95:
			return false
	return true

func follow(body: CharacterBody3D, motor: RefCounted, contact: Dictionary, delta: float, input: Vector2, resolved: Dictionary) -> bool:
	if absf(input.x) < 0.01 or absf(contact.normal.y) > 0.15:
		return false
	var sign_x := signf(input.x)
	var normal: Vector3 = motor.wall_normal
	var along := Vector3.UP.cross(normal) * sign_x
	var height := clampf(float(contact.position.y) - body.global_position.y, 0.15, 1.0)
	var origin := body.global_position + Vector3.UP * height
	var inside: Dictionary = motor.ray_between(body, origin, origin + along * (body.CAPSULE_RADIUS + 0.08))
	if motor.climbable_wall(inside) and inside.normal.dot(along) < -0.7 and absf(inside.normal.dot(normal)) < 0.8:
		var pivot := intersection(contact, inside, body.global_position.y)
		var next: Vector3 = Vector3(inside.normal.x, 0, inside.normal.z).normalized()
		if not connected(body, motor, pivot, normal, next, sign_x, height):
			return false
		# At an inside corner, both walls already support the capsule. Change
		# tangent without relocating it; normal collision handles the approach.
		motor.wall_normal = Vector3(inside.normal.x, 0, inside.normal.z).normalized()
		inside_turns += 1
		return false
	var look_ahead := 0.12 + float(resolved.climb_walk_speed) * delta
	var ahead: Dictionary = motor.ray_between(body, origin + along * look_ahead, origin + along * look_ahead - normal * (body.CAPSULE_RADIUS + 0.12))
	if not ahead.is_empty():
		return false
	var beyond: Vector3 = origin + along * (body.CAPSULE_RADIUS + 0.45) - normal * (body.CAPSULE_RADIUS + 0.15)
	var adjacent: Dictionary = motor.ray_between(body, beyond, beyond - along * (body.CAPSULE_RADIUS + 0.65))
	if not motor.climbable_wall(adjacent) or adjacent.normal.dot(along) < 0.5:
		return false
	var next: Vector3 = Vector3(adjacent.normal.x, 0, adjacent.normal.z).normalized()
	var angle := normal.signed_angle_to(next, Vector3.UP) * sign_x
	if angle < deg_to_rad(15) or angle > deg_to_rad(110):
		return false
	var pivot := intersection(contact, adjacent, body.global_position.y)
	var to_edge := pivot - body.global_position
	if absf(to_edge.dot(along)) > look_ahead + 0.06 or to_edge.length() > body.CAPSULE_RADIUS + 0.35:
		return false
	if not connected(body, motor, pivot, normal, next, sign_x, height):
		return false
	state = {"pivot": pivot, "first": normal, "last": next, "sign": sign_x, "angle": angle, "progress": 0.0, "approach": true, "height": height}
	active = true
	move(body, motor, delta, input, resolved)
	return true

func move(body: CharacterBody3D, motor: RefCounted, delta: float, input: Vector2, resolved: Dictionary) -> void:
	var pivot: Vector3 = state.pivot
	pivot.y = body.global_position.y
	if not connected(body, motor, pivot, state.first, state.last, state.sign, state.height):
		motor.detach(body, "lost corner wall")
		return
	var axes := Vector2(input.x, -input.y).limit_length()
	var speed := float(resolved.climb_walk_speed)
	var radius: float = body.CAPSULE_RADIUS + 0.015
	var target := body.global_position
	var next_progress := float(state.progress)
	if state.has("departure"):
		var departure: Dictionary = state.departure
		if axes.x * float(departure.sign) < 0:
			state.erase("departure")
			return
		var endpoint: Vector3 = departure.target
		endpoint.y = target.y
		target = target.move_toward(endpoint, absf(axes.x) * speed * delta)
	elif state.approach:
		if axes.x * float(state.sign) < 0:
			motor.wall_normal = state.first
			clear()
			return
		target = target.move_toward(pivot + Vector3(state.first) * radius, absf(axes.x) * speed * delta)
	else:
		next_progress = clampf(next_progress + axes.x * float(state.sign) * speed * delta / radius, 0, state.angle)
		target = pivot + Vector3(state.first).rotated(Vector3.UP, next_progress * float(state.sign)) * radius
	target.y += axes.y * speed * delta
	var hit := PhysicsTestMotionResult3D.new()
	var motion := target - body.global_position
	# A small chord with radius clearance stays outside the solid edge.
	if Steps.sweep(body, body.global_transform, motion, hit):
		if motion.y < 0 and Steps.walkable(body, hit):
			motor.detach(body, "ground")
			body.velocity = Vector3.DOWN * 0.2
			body.move_and_slide()
			return
		# A ceiling can block ascent without blocking lateral corner motion.
		if motion.y > 0 and hit.get_collision_normal().y < -0.5:
			target.y = body.global_position.y
			motion.y = 0
			if Steps.sweep(body, body.global_transform, motion, hit):
				body.velocity = Vector3.ZERO
				return
		else:
			body.velocity = Vector3.ZERO
			return
	body.global_position = target
	body.velocity = motion / delta
	body.flight_horizontal = Vector3.ZERO
	body.stair_supported = false
	if state.has("departure"):
		var endpoint: Vector3 = state.departure.target
		endpoint.y = body.global_position.y
		if body.global_position.distance_to(endpoint) < 0.001:
			motor.wall_normal = state.departure.normal
			if state.departure.complete:
				outside_turns += 1
			clear()
	elif state.approach:
		var radial := body.global_position - pivot
		radial.y = 0
		if radial.distance_to(Vector3(state.first) * radius) < 0.001:
			state.approach = false
	else:
		state.progress = next_progress
		motor.wall_normal = Vector3(state.first).rotated(Vector3.UP, next_progress * float(state.sign))
		if next_progress >= float(state.angle) - 0.001:
			motor.wall_normal = state.last
			var along := Vector3.UP.cross(Vector3(state.last)) * float(state.sign)
			state.departure = {"normal": state.last, "target": pivot + Vector3(state.last) * radius + along * 0.04, "sign": state.sign, "complete": true}
		elif next_progress <= 0.001 and axes.x * float(state.sign) < 0:
			motor.wall_normal = state.first
			var along := -Vector3.UP.cross(Vector3(state.first)) * float(state.sign)
			state.departure = {"normal": state.first, "target": pivot + Vector3(state.first) * radius + along * 0.04, "sign": -float(state.sign), "complete": false}
