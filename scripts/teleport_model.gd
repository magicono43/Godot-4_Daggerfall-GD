extends RefCounted
## One persistent section-local anchor; paid prompt/action state belongs to the UI.
var anchor: Dictionary = {}
var section := ""

func set_anchor(actor: CharacterBody3D) -> void:
	anchor = {"section":section, "position":[actor.position.x, actor.position.y, actor.position.z], "yaw":actor.rotation.y, "pitch":actor.camera.rotation.x, "crouched":actor.crouch.is_low(actor)}

func valid(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.is_empty():
		return true
	if data.size() != 5 or data.get("section") != section or not data.get("position") is Array or data.position.size() != 3 or not data.get("crouched") is bool:
		return false
	for value in data.position:
		if not finite_number(value, 100000):
			return false
	return finite_number(data.get("yaw"), 10000) and finite_number(data.get("pitch"), PI/2)

func finite_number(value: Variant, bound: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and absf(float(value)) <= bound

func snapshot() -> Dictionary:
	return anchor.duplicate(true)

func restore(data: Dictionary) -> void:
	anchor = data.duplicate(true)

func arrive(actor: CharacterBody3D) -> String:
	if anchor.is_empty():
		return "There is no existing anchor"
	if not valid(anchor):
		return "The anchor is invalid for this section."
	var destination := Vector3(anchor.position[0], anchor.position[1], anchor.position[2])
	var low: bool = anchor.crouched
	var capsule := CapsuleShape3D.new()
	var height: float = actor.crouch.HEIGHT if low else actor.STANDING_HEIGHT
	capsule.height = height - 0.03
	capsule.radius = actor.CAPSULE_RADIUS - 0.015
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, actor.get_parent().to_global(destination) + Vector3.UP * height/2)
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	if not actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return "The anchor is blocked."
	actor.combat.cancel()
	actor.casting.cancel()
	actor.climbing.reset()
	actor.falling.reset()
	actor.fall_feedback_time = 0
	actor.crouch.reset(actor)
	if low:
		actor.crouch.set_height(actor, actor.crouch.HEIGHT)
		actor.crouch.toggled = true
		actor.crouch.requested = true
		actor.crouch.active = true
		actor.crouch.eye_height = actor.crouch.EYE
	actor.position = destination
	actor.rotation.y = float(anchor.yaw)
	actor.camera.rotation.x = float(anchor.pitch)
	actor.camera.position.y = actor.crouch.eye_height
	actor.velocity = Vector3.ZERO
	actor.flight_horizontal = Vector3.ZERO
	actor.input_axes = Vector2.ZERO
	actor.grounded_time = 0
	actor.step_camera_offset = 0
	actor.stair_supported = false
	actor.interact_target = null
	# Refresh engine floor flags at the new position without applying old snap/motion.
	var snap: float = actor.floor_snap_length
	actor.floor_snap_length = 0
	actor.move_and_slide()
	actor.floor_snap_length = snap
	actor.combat.pose()
	anchor.clear()
	return ""
