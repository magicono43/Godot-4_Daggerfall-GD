extends RefCounted
## Feet stay anchored. Lower the eye before shrinking; grow only with clearance.
const Steps = preload("res://scripts/step_solver.gd")
const HEIGHT := 0.9
const EYE := HEIGHT - 0.09
var toggled := false
var requested := false
var blocked := false
var eye_height := 1.71
var active := false

func is_low(body: CharacterBody3D) -> bool:
	return float(body.capsule_collision.shape.height) < float(body.STANDING_HEIGHT) - 0.001

func set_height(body: CharacterBody3D, height: float) -> void:
	body.capsule_collision.shape.height = height
	body.capsule_collision.position.y = height / 2.0

func reset(body: CharacterBody3D) -> void:
	toggled = false
	requested = false
	blocked = false
	active = false
	eye_height = body.EYE_HEIGHT
	set_height(body, body.STANDING_HEIGHT)

func can_stand(body: CharacterBody3D) -> bool:
	if not is_low(body):
		return true
	# The union of this short capsule swept upward is exactly the standing
	# capsule volume. This tests shoulders as well as the centre of the head.
	var hit := PhysicsTestMotionResult3D.new()
	return not Steps.sweep(body, body.global_transform, Vector3.UP * (float(body.STANDING_HEIGHT) - float(body.capsule_collision.shape.height)), hit)

func tick(body: CharacterBody3D, want_crouch: bool) -> void:
	if body.climbing.active:
		want_crouch = false
	# A new airborne toggle waits for landing; a crouch already started on
	# the floor can finish during a jump without changing the foot position.
	if not body.is_grounded() and not is_low(body) and not requested:
		want_crouch = false
	requested = want_crouch
	blocked = false
	if requested:
		if eye_height <= EYE + 0.001:
			set_height(body, HEIGHT)
	elif is_low(body):
		if can_stand(body):
			set_height(body, body.STANDING_HEIGHT)
		else:
			blocked = true
	active = requested or is_low(body) or eye_height < float(body.EYE_HEIGHT) - 0.001

func update_camera(body: CharacterBody3D, delta: float) -> float:
	var target: float = EYE if requested or is_low(body) else body.EYE_HEIGHT
	var duration := float(body.movement.profile.values.crouching.transition_seconds)
	eye_height = move_toward(eye_height, target, (float(body.EYE_HEIGHT) - EYE) / duration * delta)
	var y: float = eye_height + body.step_camera_offset
	# Grounded stair smoothing can lag above the body on descent. A crouched
	# camera must stay below its capsule top when entering a low passage.
	if active:
		y = minf(y, float(body.capsule_collision.shape.height) - 0.09)
	return y
