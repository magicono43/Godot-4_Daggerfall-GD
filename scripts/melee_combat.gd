extends RefCounted
const Door = preload("res://scripts/door.gd")
## Animation-driven targeting; source-derived rolls/damage live in combat_resolver.
var reach := 2.25
var radius := 0.25
var resolver: RefCounted = preload("res://scripts/combat_resolver.gd").new()
var frame_seconds := 3.0 * (115.0 - 50.0) / 980.0
var windup := frame_seconds * 2.0
var recovery := frame_seconds * 3.0
var attack_record := 1
var attack_weapon := "dagger"
var attack_uid := 0
var attack_item: Dictionary = {}
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
	if body.casting.active() or not body.inventory.has_weapon() or body.modal_open or sheathed or elapsed >= 0 or body.is_dead() or not body.controls_active or body.climbing.active:
		return false
	if body.fatigue.exhausted():
		feedback = "You are exhausted. T opens rest."
		feedback_time = 1.0
		return false
	body.fatigue.spend(body.fatigue.SWING_COST)
	attack_weapon = body.inventory.equipped_weapon()
	attack_uid = body.inventory.equipped_uid
	attack_item = body.inventory.find(attack_uid).duplicate(true)
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
	if not body.inventory.has_weapon() or body.modal_open or not body.controls_active or body.climbing.active:
		cancel()
		return
	if elapsed < 0:
		return
	if body.inventory.equipped_uid != attack_uid:
		cancel()
		return
	elapsed += delta
	if not struck and elapsed + 0.000001 >= windup:
		struck = true
		strike()
	if elapsed + 0.000001 >= windup + recovery:
		elapsed = -1.0
	pose()

func strike() -> void:
	var body: CharacterBody3D = cast.get_parent().get_parent()
	var outcome := "empty"
	cast.force_shapecast_update()
	feedback = "Out of reach"
	# ShapeCast's collision list need not be ordered. The nearest obstruction
	# owns the strike, so a wall/closed door cannot be bypassed by a target.
	var closest := INF
	var target: Object = null
	var impact := Vector3.ZERO
	for i in cast.get_collision_count():
		var distance := cast.global_position.distance_squared_to(cast.get_collision_point(i))
		if distance < closest:
			closest = distance
			target = cast.get_collider(i)
			impact = cast.get_collision_point(i)
	if is_instance_valid(target):
		feedback = "Blocked"
		outcome = "terrain"
		if target.has_method("receive_damage"):
			var result: Dictionary = resolver.weapon_attack(body, target, attack_item, attack_record)
			outcome = result.outcome
			feedback = {"miss": "Missed target", "ineffective": "Ineffective material", "no_damage": "No damage"}.get(outcome, "Missed target")
			if result.damage > 0 and target.receive_damage(int(result.damage)):
				feedback = "Hit: %d" % int(result.damage)
	if is_instance_valid(body.combat_audio):
		if feedback.begins_with("Hit"):
			body.combat_audio.play("impact", target as Node3D, 1.0, impact)
		elif outcome == "terrain":
			var event := "door" if target is Door else "wall"
			body.combat_audio.play(event, target as Node3D, 1.0, impact)
		elif outcome in ["miss", "no_damage", "ineffective"] and target.combat_stats.parry_sounds:
			body.combat_audio.play("parry", target as Node3D, 1.0, impact)
		else:
			body.combat_audio.play(preload("res://scripts/item_catalog.gd").WEAPONS[attack_weapon].miss)
	feedback_time = 0.8

func toggle_sheath() -> void:
	var body: CharacterBody3D = cast.get_parent().get_parent()
	if not body.inventory.has_weapon() or body.modal_open:
		return
	sheathed = not sheathed
	if not sheathed and is_instance_valid(body.combat_audio):
		body.combat_audio.play(preload("res://scripts/item_catalog.gd").WEAPONS[body.inventory.equipped_weapon()].draw)
	cancel()

func pose() -> void:
	if not is_instance_valid(weapon):
		return
	var frame := mini(int((elapsed + 0.000001) / frame_seconds), 4) if elapsed >= 0 else 0
	weapon.set_frame(attack_record if elapsed >= 0 else 0, frame, not sheathed)
