extends CharacterBody3D
## Greybox enemy; authored attack and approach policies are independent.
const Melee = preload("res://scripts/enemy_melee.gd")
var melee := Melee.new()
var navigation := preload("res://scripts/enemy_navigation.gd").new()
var sprite_payload: Dictionary = {}
var mobile: Sprite3D
var body_mesh: MeshInstance3D
const Health = preload("res://scripts/health.gd")
var health := Health.new()
var body_material: StandardMaterial3D
var hit_flash := 0.0
var player: CharacterBody3D
var home := Vector3.ZERO
var noticed := false
var combat_audio: Node
var sound_wait := 3.0
var sound_rng := RandomNumberGenerator.new()
var approach_enabled := true
signal encountered

func play_sound(event: String, gain: float = 1.0) -> void:
	if mobile and is_instance_valid(combat_audio):
		if event == "skeleton_attack" and sound_rng.randf() <= 0.5:
			return
		combat_audio.play(event, self, gain)

func _ready() -> void:
	sound_rng.randomize()
	sound_wait = float(sound_rng.randi_range(3, 9))
	collision_layer = 1
	collision_mask = 3
	floor_snap_length = 0.3
	if navigation.enabled:
		# Match the accepted capsule-contact classification used by the player.
		# Local obstacle/floor probes and capsule sweeps govern traversability.
		floor_max_angle = deg_to_rad(70.0)
		floor_constant_speed = true
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 0.8
	shape.shape = capsule
	shape.position.y = 0.4
	add_child(shape)
	if not sprite_payload.is_empty():
		var height: float = sprite_payload.records[15].size_metres.y
		capsule.height = height
		shape.position.y = height * 0.5
		mobile = preload("res://scripts/enemy_sprite.gd").new()
		mobile.configure(sprite_payload)
		add_child(mobile)
		home = position
		return
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.8
	body.mesh = mesh
	body_mesh = body
	body.position.y = 0.4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.16, 0.12)
	material.roughness = 0.9
	body.material_override = material
	body_material = material
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
	if mobile and is_instance_valid(combat_audio) and health.current > 0 and is_instance_valid(player) and player.controls_active and not player.is_dead():
		sound_wait -= delta
		if sound_wait <= 0 and global_position.distance_to(player.global_position) < combat_audio.enemy_range:
			sound_wait = float(sound_rng.randi_range(3, 9))
			var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8, player.global_position + Vector3.UP * 0.8, 3, [get_rid()])
			var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
			var gain := 1.0 if obstruction.is_empty() or obstruction.collider == player else 0.25
			play_sound("skeleton_move" if sound_rng.randf() > 0.8 else "skeleton_bark", gain)
	hit_flash = maxf(0.0, hit_flash - delta)
	if mobile:
		mobile.tick(delta)
	else:
		var charging: bool = melee.phase == "windup"
		body_material.albedo_color = Color(1, 0.8, 0.6) if hit_flash > 0 else (Color(1, 0.55, 0.08) if charging else Color(0.55, 0.16, 0.12))
		body_mesh.rotation.x = -0.3 * (1.0 - melee.remaining / melee.windup) if charging else 0.0
	melee.tick(self, delta)
	if health.current <= 0 or not player:
		return
	var offset := player.global_position - global_position
	var distance := offset.length()
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, player.global_position + Vector3.UP * float(player.capsule_collision.shape.height) * 0.5, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var visible_player: bool = not hit.is_empty() and hit.collider == player
	if distance < (20.0 if navigation.enabled else 9.0) and visible_player:
		if not noticed:
			noticed = true
			encountered.emit()
		if navigation.enabled:
			navigation.tick(self, delta, visible_player)
			return
		offset.y = 0
		if approach_enabled and melee.phase == "idle" and not player.is_dead() and offset.length() > 1.8 and position.distance_to(home) < 4:
			velocity.x = offset.normalized().x * 0.8
			velocity.z = offset.normalized().z * 0.8
		else:
			velocity.x = 0
			velocity.z = 0
		if offset.length() > 0.1 and melee.phase != "windup":
			look_at(global_position + offset, Vector3.UP)
	else:
		if navigation.enabled:
			navigation.tick(self, delta, false)
			return
		velocity.x = 0
		velocity.z = 0
	if not is_on_floor():
		velocity.y -= 16 * delta
	else:
		velocity.y = -0.2
	move_and_slide()

func receive_damage(amount: int) -> bool:
	if not health.apply_damage(amount):
		return false
	hit_flash = 0.15
	if health.current == 0:
		if is_instance_valid(combat_audio):
			combat_audio.stop_creature(self)
		play_sound("death")
		melee.cancel()
		navigation.clear()
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		if mobile:
			mobile.set_state("corpse")
		else:
			visible = false
	elif mobile:
		melee.cancel()
		mobile.set_state("hurt")
	return true
