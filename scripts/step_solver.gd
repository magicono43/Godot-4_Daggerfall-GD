extends RefCounted
## Full-capsule sweeps: no ramps or changes to original dungeon collision.
const CLEARANCE := 0.002
const MIN_RISE := 0.01

static func sweep(body: CharacterBody3D, at: Transform3D, motion: Vector3, result: PhysicsTestMotionResult3D) -> bool:
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.from = at
	parameters.motion = motion
	parameters.margin = body.safe_margin
	parameters.max_collisions = 4
	return PhysicsServer3D.body_test_motion(body.get_rid(), parameters, result)

static func walkable(body: CharacterBody3D, hit: PhysicsTestMotionResult3D) -> bool:
	return hit.get_collision_count() > 0 and hit.get_collision_normal().dot(Vector3.UP) >= cos(body.floor_max_angle)

static func tread_at_contact(body: CharacterBody3D, point: Vector3, normal: Vector3, collider: Object) -> Dictionary:
	var inward := -Vector3(normal.x, 0, normal.z).normalized() * 0.01
	var contact := point + inward
	var ray := PhysicsRayQueryParameters3D.create(contact + Vector3.UP * 0.02, contact + Vector3.DOWN * 0.04, body.collision_mask, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.collider != collider or hit.normal.y < cos(body.floor_max_angle):
		return {}
	return hit

static func up(body: CharacterBody3D, start: Transform3D, motion: Vector3, height: float, verify_tread_edge: bool = false) -> Dictionary:
	var hit := PhysicsTestMotionResult3D.new()
	# Caller has verified grounded capsule support. Its contact is at/above
	# the capsule's feet (apart from collision margin). A centre ray can hit
	# an older, lower tread behind that support and falsely reject slow steps.
	var support_height := start.origin.y - body.safe_margin
	# Narrow/sloped classic treads can support the capsule ahead of its centre.
	# Only already-walkable physical contacts may raise the reference floor.
	for i in body.get_slide_collision_count():
		var contact := body.get_slide_collision(i)
		if contact.get_normal().y >= cos(body.floor_max_angle):
			var tread := tread_at_contact(body, contact.get_position(), contact.get_normal(), contact.get_collider())
			if not tread.is_empty():
				support_height = maxf(support_height, tread.position.y)
	# Find available headroom first; a low ceiling can reduce the usable rise.
	var lift := height + CLEARANCE
	if sweep(body, start, Vector3.UP * lift, hit):
		lift = hit.get_travel().y - CLEARANCE
	if lift <= MIN_RISE:
		return {}
	var raised := start
	raised.origin.y += lift
	if sweep(body, raised, motion, hit):
		return {}
	raised.origin += motion
	if not sweep(body, raised, Vector3.DOWN * (lift + CLEARANCE), hit):
		return {}
	if not walkable(body, hit):
		# Optional slow NPC assistance: rounded feet may land on a tread edge.
		# Require a real walkable face there, just as down() does. Player callers
		# keep their accepted behavior unless they explicitly opt in.
		if not verify_tread_edge or hit.get_collision_normal().y <= 0.001 or tread_at_contact(body, hit.get_collision_point(), hit.get_collision_normal(), hit.get_collider()).is_empty():
			return {}
	var landing := raised.origin + hit.get_travel()
	var rise := landing.y - start.origin.y
	# Check the actual tread height, not just the capsule's rounded-foot rise;
	# otherwise repeated partial lifts could scale an oversized ledge.
	if rise < MIN_RISE or rise > height + body.safe_margin or hit.get_collision_point().y - support_height > height + body.safe_margin:
		return {}
	raised.origin = landing + Vector3.UP * CLEARANCE
	return {"transform": raised}

static func down(body: CharacterBody3D, height: float) -> Dictionary:
	var hit := PhysicsTestMotionResult3D.new()
	var start := body.global_transform
	var collided := sweep(body, start, Vector3.DOWN * (height + CLEARANCE), hit)
	if not collided:
		return {}
	if not walkable(body, hit):
		# A rounded capsule touching a tread edge has a steep separating normal
		# even though the tread is horizontal. Require both physical capsule
		# support and a walkable face at the contacted tread edge, within reach.
		if hit.get_collision_normal().y <= 0.001:
			return {}
		if tread_at_contact(body, hit.get_collision_point(), hit.get_collision_normal(), hit.get_collider()).is_empty():
			return {}
	var drop := -hit.get_travel().y
	if drop < 0 or drop > height:
		return {}
	start.origin += hit.get_travel() + Vector3.UP * CLEARANCE
	return {"transform": start}
