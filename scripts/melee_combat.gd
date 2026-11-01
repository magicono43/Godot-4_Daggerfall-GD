extends RefCounted
## DFU targeting dimensions; deterministic prototype timing/damage, not RPG formulas.
var reach := 2.25
var radius := 0.25
var damage := 10
var frame_seconds := 3.0 * (115.0 - 50.0) / 980.0
var windup := frame_seconds * 2.0
var recovery := frame_seconds * 3.0
var attack_record := 1
var sheathed := false
var rng := RandomNumberGenerator.new()
var elapsed := -1.0
var struck := false
var feedback := ""
var feedback_time := 0.0
var cast: ShapeCast3D
var weapon: TextureRect

func _init() -> void:
	rng.randomize()

func setup(camera: Camera3D) -> void:
	cast = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	cast.shape = sphere
	cast.target_position = Vector3(0, 0, -reach)
	cast.collision_mask = 1
	cast.enabled = false
	camera.add_child(cast)
	cast.add_exception(camera.get_parent())
	var layer := CanvasLayer.new()
	camera.add_child(layer)
	weapon = preload("res://scripts/weapon_view.gd").new()
	layer.add_child(weapon)
	weapon.configure(camera.get_parent().weapon_payload, camera.get_parent())
	pose()

func request_attack(body: CharacterBody3D) -> bool:
	if sheathed or elapsed >= 0 or body.is_dead() or not body.controls_active or body.climbing.active:
		return false
	# Snapshot live Speed for this attack; movement resolution remains separate.
	frame_seconds = 3.0 * (115.0 - clampf(body.movement.stat("speed_attribute"), 1.0, 100.0)) / 980.0
	windup = frame_seconds * 2.0
	recovery = frame_seconds * 3.0
	attack_record = rng.randi_range(1, 6)
	elapsed = 0.0
	struck = false
	pose()
	return true

func cancel() -> void:
	elapsed = -1.0
	struck = false
	pose()

func tick(body: CharacterBody3D, delta: float) -> void:
	feedback_time = maxf(0.0, feedback_time - delta)
	if not body.controls_active or body.climbing.active:
		cancel()
		return
	if elapsed < 0:
		return
	elapsed += delta
	if not struck and elapsed + 0.000001 >= windup:
		struck = true
		strike()
	if elapsed + 0.000001 >= windup + recovery:
		elapsed = -1.0
	pose()

func strike() -> void:
	cast.force_shapecast_update()
	feedback = "Miss"
	# ShapeCast's collision list need not be ordered. The nearest obstruction
	# owns the strike, so a wall/closed door cannot be bypassed by a target.
	var closest := INF
	var target: Object = null
	for i in cast.get_collision_count():
		var distance := cast.global_position.distance_squared_to(cast.get_collision_point(i))
		if distance < closest:
			closest = distance
			target = cast.get_collider(i)
	if is_instance_valid(target):
		feedback = "Blocked"
		if target.has_method("receive_damage") and target.receive_damage(damage):
			feedback = "Hit: %d" % damage
	feedback_time = 0.8

func toggle_sheath() -> void:
	sheathed = not sheathed
	cancel()

func pose() -> void:
	if not is_instance_valid(weapon):
		return
	var frame := mini(int((elapsed + 0.000001) / frame_seconds), 4) if elapsed >= 0 else 0
	weapon.set_frame(attack_record if elapsed >= 0 else 0, frame, not sheathed)
