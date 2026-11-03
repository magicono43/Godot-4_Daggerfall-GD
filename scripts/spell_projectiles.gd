extends Node3D
## Scene-local, transient missiles/impacts. Geometry is separate from damage policy.
const Missile = preload("res://scripts/spell_projectile.gd")
const COLORS := {"fire":Color(0.604, 0.094, 0.031), "shock":Color(0.267, 0.486, 0.753)}
var actor: CharacterBody3D
var payloads: Dictionary = {}
var effects: Array[Node3D] = []
var hits := 0

func busy() -> bool:
	return not effects.is_empty()

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if actor.is_dead():
		clear()
		return
	if actor.modal_open or not actor.controls_active:
		return
	for effect in effects.duplicate():
		effect.tick(delta)

func launch(spell: Dictionary) -> Node3D:
	var missile := Node3D.new()
	missile.set_script(Missile)
	missile.system = self
	missile.element = spell.element
	missile.damage = int(spell.amount)
	missile.direction = -actor.camera.global_basis.z.normalized()
	effects.append(missile)
	add_child(missile)
	missile.global_position = actor.camera.global_position
	return missile

func touch_target() -> Dictionary:
	# Same source touch dimensions as DFU: 0.25m sweep radius and3m range.
	var cast := ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	cast.shape = sphere
	cast.collision_mask = 1
	cast.enabled = false
	cast.max_results = 32
	add_child(cast)
	cast.global_position = actor.camera.global_position
	cast.target_position = -actor.camera.global_basis.z.normalized() * 3.0
	cast.force_shapecast_update()
	var nearest := INF
	var target: Object
	var point := Vector3.ZERO
	for i in cast.get_collision_count():
		var contact := cast.get_collision_point(i)
		var distance := contact.distance_squared_to(cast.global_position)
		if distance < nearest:
			nearest = distance
			target = cast.get_collider(i)
			point = contact
	cast.free()
	if target is Node and target.is_in_group("prototype_enemies") and target.health.current > 0:
		return {"target":target, "point":point}
	return {}

func damage_enemy(target: Object, amount: int) -> void:
	# Explicit test policy: every landed enemy hit works, without saving throws,
	# resistance/absorption/reflection or melee hit/armor rolls.
	if is_instance_valid(target) and target is Node and target.is_in_group("prototype_enemies") and target.health.current > 0:
		if target.receive_damage(amount):
			hits += 1

func touch(spell: Dictionary) -> void:
	var hit := touch_target()
	if hit.is_empty():
		return
	damage_enemy(hit.target, int(spell.amount))
	if is_instance_valid(actor.combat_audio):
		actor.combat_audio.play("impact_" + str(spell.element), self, 1.0, hit.point)

func retire(effect: Node3D) -> void:
	effects.erase(effect)
	effect.hide()
	effect.queue_free()

func clear() -> void:
	for effect in effects.duplicate():
		retire(effect)
