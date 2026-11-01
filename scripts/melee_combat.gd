extends RefCounted
## DFU targeting dimensions; deterministic prototype timing/damage, not RPG formulas.
var reach := 2.25
var radius := 0.25
var damage := 10
var windup := 0.18
var recovery := 0.32
var elapsed := -1.0
var struck := false
var feedback := ""
var feedback_time := 0.0
var cast: ShapeCast3D
var weapon: MeshInstance3D

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
	weapon = MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.07, 0.6, 0.07)
	weapon.mesh = blade
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.7, 0.75)
	weapon.material_override = material
	weapon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(weapon)
	pose()

func request_attack(body: CharacterBody3D) -> bool:
	if elapsed >= 0 or not body.controls_active or body.climbing.active:
		return false
	elapsed = 0.0
	struck = false
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
	if not struck and elapsed >= windup:
		struck = true
		strike()
	if elapsed >= windup + recovery:
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

func pose() -> void:
	if not is_instance_valid(weapon):
		return
	var swing := sin(clampf(elapsed / (windup + recovery), 0.0, 1.0) * PI) if elapsed >= 0 else 0.0
	weapon.position = Vector3(0.28 - swing * 0.45, -0.28 + swing * 0.1, -0.55)
	weapon.rotation.z = -0.25 + swing * 1.7
