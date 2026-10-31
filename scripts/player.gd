extends CharacterBody3D
const Movement = preload("res://scripts/movement_model.gd")
const Steps = preload("res://scripts/step_solver.gd")
var movement := Movement.new()
const Climbing = preload("res://scripts/climbing_motor.gd")
var climbing := Climbing.new()
const Crouching = preload("res://scripts/crouch_motor.gd")
var crouch := Crouching.new()
var capsule_collision: CollisionShape3D
var grounded_time := 0.0
var is_running := false
var show_movement_debug := false
var input_axes := Vector2.ZERO
var step_camera_offset := 0.0
var last_step := 0.0
var stair_supported := false
var flight_horizontal := Vector3.ZERO
# DFU PlayerHeightChanger + PlayerAdvanced prefab, measured above the feet.
const STANDING_HEIGHT := 1.8
const CAPSULE_RADIUS := 0.35
const EYE_HEIGHT := STANDING_HEIGHT - 0.09
var vertical_fov := 75.0
var camera: Camera3D
var ray: RayCast3D
var spawn := Vector3.ZERO
var interact_target: Node
var controls_active := true

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	reload_movement()
	var shape := CollisionShape3D.new()
	capsule_collision = shape
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = STANDING_HEIGHT
	shape.shape = capsule
	shape.position.y = STANDING_HEIGHT / 2.0
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = EYE_HEIGHT
	# Unity Camera.fieldOfView and Godot KEEP_HEIGHT both specify vertical FOV.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = vertical_fov
	camera.near = 0.06
	add_child(camera)
	camera.current = true
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.6)
	ray.collision_mask = 1
	camera.add_child(ray)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.79, 0.53)
	lantern.light_energy = 1.15
	lantern.omni_range = 10.0
	camera.add_child(lantern)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func reload_movement() -> bool:
	var loaded := movement.profile.load_file()
	if not loaded:
		push_warning(movement.profile.error)
	var values: Dictionary = movement.profile.values.physics
	floor_snap_length = values.floor_snap_metres
	floor_max_angle = deg_to_rad(values.floor_max_angle_degrees)
	floor_constant_speed = values.floor_constant_speed
	if loaded:
		input_axes = Vector2.ZERO
	return loaded

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and controls_active:
		var look: Dictionary = movement.profile.values.look
		var limit := deg_to_rad(float(look.max_pitch_degrees))
		var sensitivity := float(look.radians_per_pixel)
		rotate_y(-event.relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity * (-1.0 if look.invert_y else 1.0), -limit, limit)
	if event.is_action_pressed("reload_movement"):
		reload_movement()
	if event.is_action_pressed("movement_debug"):
		show_movement_debug = not show_movement_debug
	if event.is_action_pressed("release_mouse"):
		controls_active = not controls_active
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if controls_active else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and not controls_active:
		controls_active = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("interact") and interact_target and controls_active:
		interact_target.interact()
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	interact_target = null
	if ray.is_colliding():
		var collider := ray.get_collider() as Node
		if collider and collider.has_method("interact"):
			interact_target = collider
	var grounded := is_grounded()
	grounded_time = grounded_time + delta if grounded else 0.0
	var tuning: Dictionary = movement.profile.values.locomotion
	var jump: Dictionary = movement.profile.values.jump
	var resolved := movement.resolve()
	var input := Vector2(Input.get_axis("left", "right"), Input.get_axis("forward", "back")) if controls_active else Vector2.ZERO
	var jump_pressed := Input.is_action_pressed("jump") if jump.repeat_while_held else Input.is_action_just_pressed("jump")
	if controls_active and not climbing.active and InputMap.has_action("crouch") and Input.is_action_just_pressed("crouch"):
		crouch.toggled = not crouch.toggled
	crouch.tick(self, crouch.toggled)
	if crouch.active and not climbing.active:
		climbing.attach_time = 0.0
		climbing.tracked = false
	if (climbing.active or not crouch.active) and climbing.tick(self, delta, input, resolved):
		return
	stair_supported = false
	if tuning.response == "dfu_axes":
		var rate := float(tuning.axis_response_per_second) * delta
		input_axes.x = move_toward(input_axes.x, input.x, rate)
		input_axes.y = move_toward(input_axes.y, input.y, rate)
		input = input_axes
		if tuning.limit_diagonal_speed and input.x != 0 and input.y != 0:
			input *= 0.70710678
	elif tuning.limit_diagonal_speed and input.length_squared() > 1.0:
		input = input.normalized()
	# Direction penalties are applied after normalisation, so adding strafe
	# cannot bypass a backward-speed multiplier.
	input.x *= float(tuning.strafe_multiplier)
	if input.y > 0:
		input.y *= float(tuning.backward_multiplier)
	if grounded:
		is_running = controls_active and Input.is_action_pressed("sprint")
	var speed := float(resolved.run_speed if is_running else resolved.walk_speed)
	if crouch.active:
		speed = float(resolved.crouch_run_speed if is_running else resolved.crouch_walk_speed)
	var desired := global_basis * Vector3(input.x, 0, input.y) * speed
	# Unity's controller.Move does not overwrite DFU's moveDirection. Godot's
	# move_and_slide does, so retain free-flight momentum apart from wall slides.
	var horizontal := flight_horizontal if not grounded else Vector3(velocity.x, 0, velocity.z)
	if grounded or resolved.air_control:
		if tuning.response in ["instant", "dfu_axes"]:
			horizontal = desired
		else:
			var braking := desired.is_zero_approx() or horizontal.dot(desired) < 0
			var rate: float = tuning.ground_braking if braking else tuning.ground_acceleration
			if not grounded:
				rate = tuning.air_braking if braking else tuning.air_acceleration
			horizontal = horizontal.move_toward(desired, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if grounded and controls_active and jump_pressed and grounded_time >= float(jump.minimum_grounded_time):
		velocity.y = resolved.jump_velocity
		if horizontal.length_squared() > 0.0001:
			velocity += -global_basis.z * float(jump.base_velocity) * float(jump.forward_boost_fraction)
		grounded_time = 0.0
		velocity.y -= float(resolved.gravity) * delta
	elif grounded:
		velocity.y = -float(movement.profile.values.physics.ground_stick_speed)
	else:
		velocity.y -= float(resolved.gravity) * delta
	flight_horizontal = Vector3(velocity.x, 0, velocity.z)
	var before := global_transform
	var requested := velocity
	move_and_slide()
	last_step = 0.0
	var stepping: Dictionary = movement.profile.values.stepping
	if grounded and requested.y <= 0 and stepping.enabled and stepping.max_height_metres > 0:
		var motion := Vector3(requested.x, 0, requested.z) * delta
		var traveled := global_position - before.origin
		var result: Dictionary = {}
		if motion.length() > 0.0001 and traveled.dot(motion.normalized()) < motion.length() - 0.001:
			result = Steps.up(self, before, motion, float(stepping.max_height_metres))
		if result.is_empty() and not is_on_floor():
			result = Steps.down(self, float(stepping.max_height_metres))
		if not result.is_empty():
			stair_supported = true
			last_step = result.transform.origin.y - global_position.y
			global_transform = result.transform
			# Refresh floor contact without applying horizontal movement twice.
			velocity = Vector3(0, -float(movement.profile.values.physics.ground_stick_speed), 0)
			move_and_slide()
			velocity.x = requested.x
			velocity.z = requested.z
	if stepping.enabled and grounded and is_grounded() and requested.y <= 0:
		# Cancel the whole grounded height change, including native capsule
		# sliding and floor snap. Render updates then follow it continuously.
		step_camera_offset -= global_position.y - before.origin.y
	if position.y < -10:
		climbing.reset()
		position = spawn
		crouch.reset(self)
		velocity = Vector3.ZERO
		grounded_time = 0.0
		step_camera_offset = 0.0
		camera.position.y = EYE_HEIGHT
		stair_supported = false
		flight_horizontal = Vector3.ZERO

func _process(delta: float) -> void:
	var stepping: Dictionary = movement.profile.values.stepping
	var filtered := step_camera_offset * exp(-float(stepping.camera_smoothing_rate) * delta)
	step_camera_offset = move_toward(step_camera_offset, filtered, float(stepping.camera_smoothing_speed) * delta)
	camera.position.y = crouch.update_camera(self, delta)

func is_grounded() -> bool:
	# Godot can classify the rounded capsule/tread-edge contact as a wall.
	# The step solver additionally verifies a nearby walkable tread below it.
	return not climbing.active and (is_on_floor() or stair_supported)

func movement_debug_text() -> String:
	var resolved := movement.resolve()
	var result := "Movement | Speed %.0f  Running %.0f  Jumping %.0f\nWalk %.3f  Run %.3f m/s  |  Jump %.3f m/s  Gravity %.2f m/s²\nActual horizontal %.3f m/s  |  %s  |  %s response\nF3 reload movement.cfg  |  F4 hide diagnostics" % [movement.stat("speed_attribute"), movement.stat("running_skill"), movement.stat("jumping_skill"), resolved.walk_speed, resolved.run_speed, resolved.jump_velocity, resolved.gravity, Vector2(velocity.x, velocity.z).length(), "grounded" if is_grounded() else "airborne", movement.profile.values.locomotion.response]
	result += "\nClimb: %s | attach %.2f s | %.3f m/s" % ["attached" if climbing.active else climbing.transition, climbing.attach_time, resolved.climb_walk_speed]
	result += "\nPosture: %s | capsule %.2f m | crouch %.3f / %.3f m/s" % ["stand blocked" if crouch.blocked else ("crouching" if crouch.active else "standing"), capsule_collision.shape.height, resolved.crouch_walk_speed, resolved.crouch_run_speed]
	if not movement.profile.error.is_empty():
		result += "\n" + movement.profile.error
	return result

