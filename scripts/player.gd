extends CharacterBody3D
const SPEED := 4.0
var camera: Camera3D
var ray: RayCast3D
var spawn := Vector3.ZERO
var mouse_sensitivity := 0.0023
var interact_target: Node
var controls_active := true

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.fov = 78
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and controls_active:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -1.45, 1.45)
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
	var input := Input.get_vector("left", "right", "forward", "back") if controls_active else Vector2.ZERO
	var direction := global_basis * Vector3(input.x, 0, input.y)
	var speed := SPEED * (1.5 if Input.is_action_pressed("sprint") else 1.0)
	velocity.x = move_toward(velocity.x, direction.x * speed, 20 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 20 * delta)
	if not is_on_floor():
		velocity.y -= 16 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = 5.2
	else:
		velocity.y = -0.2
	move_and_slide()
	if position.y < -10:
		position = spawn
		velocity = Vector3.ZERO

