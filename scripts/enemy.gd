extends CharacterBody3D
## Deliberately non-combat enemy: notices, approaches, and stops at a safe distance.
var player: CharacterBody3D
var home := Vector3.ZERO
var noticed := false
signal encountered

func _ready() -> void:
	collision_layer = 1
	collision_mask = 3
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 0.8
	shape.shape = capsule
	shape.position.y = 0.4
	add_child(shape)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.8
	body.mesh = mesh
	body.position.y = 0.4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.16, 0.12)
	material.roughness = 0.9
	body.material_override = material
	add_child(body)
	for x in [-0.12, 0.12]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.045
		sphere.height = 0.09
		eye.mesh = sphere
		eye.position = Vector3(x, 0.58, -0.29)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1, 0.72, 0.25)
		glow.emission_enabled = true
		glow.emission = glow.albedo_color
		eye.material_override = glow
		add_child(eye)
	home = position

func _physics_process(delta: float) -> void:
	if not player:
		return
	var offset := player.global_position - global_position
	var distance := offset.length()
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, player.global_position + Vector3.UP, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var visible_player: bool = not hit.is_empty() and hit.collider == player
	if distance < 9 and visible_player:
		if not noticed:
			noticed = true
			encountered.emit()
		offset.y = 0
		if offset.length() > 1.8 and position.distance_to(home) < 4:
			velocity.x = offset.normalized().x * 0.8
			velocity.z = offset.normalized().z * 0.8
		else:
			velocity.x = 0
			velocity.z = 0
		if offset.length() > 0.1:
			look_at(global_position + offset, Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0
	if not is_on_floor():
		velocity.y -= 16 * delta
	else:
		velocity.y = -0.2
	move_and_slide()
