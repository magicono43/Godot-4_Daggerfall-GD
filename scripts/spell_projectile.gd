extends Node3D
## Full swept contact every physics tick; one hit, followed by a finite impact.
const SPEED := 25.0
const RADIUS := 0.45
const MAX_TRAVEL := 100.0 # Bounded prototype lifetime; no global projectile persistence.
var system: Node3D
var element := "fire"
var damage := 10
var direction := Vector3.FORWARD
var impacted := false
var age := 0.0
var travelled := 0.0
var sprite: Sprite3D
var glow: OmniLight3D
var sweep: ShapeCast3D

func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	add_child(sprite)
	glow = OmniLight3D.new()
	glow.light_color = system.COLORS[element]
	glow.light_energy = 0.35 # Modest authored intensity; preserve dungeon/lantern calibration.
	glow.omni_range = 6.0
	add_child(glow)
	sweep = ShapeCast3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	sweep.shape = sphere
	sweep.collision_mask = 1
	sweep.max_results = 32
	sweep.enabled = false
	add_child(sweep)
	show_frame()

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	age += delta
	if impacted:
		var impact: Dictionary = system.payloads[element].impact
		if age >= impact.frames.size() / 15.0:
			system.retire(self)
		else:
			show_frame()
		return
	var distance := minf(SPEED * delta, MAX_TRAVEL - travelled)
	var movement := direction * distance
	sweep.target_position = movement
	sweep.force_shapecast_update()
	if sweep.is_colliding():
		var nearest := INF
		var target: Object
		var point := global_position
		var normal := -direction
		for i in sweep.get_collision_count():
			var contact := sweep.get_collision_point(i)
			var squared := contact.distance_squared_to(global_position)
			if squared < nearest:
				nearest = squared
				target = sweep.get_collider(i)
				point = contact
				normal = sweep.get_collision_normal(i)
		impact(target, point, normal)
	else:
		global_position += movement
		travelled += distance
		if travelled >= MAX_TRAVEL:
			system.retire(self)
		else:
			show_frame()

func impact(target: Object, point: Vector3, normal: Vector3) -> void:
	if impacted:
		return
	impacted = true
	age = 0.0
	# Offset the animation slightly from the contacted surface to avoid z fighting.
	global_position = point + normal * 0.03
	system.damage_enemy(target, damage)
	if is_instance_valid(system.actor.combat_audio):
		system.actor.combat_audio.play("impact_" + element, self, 1.0, point)
	show_frame()

func show_frame() -> void:
	var payload: Dictionary = system.payloads[element].impact if impacted else system.payloads[element].projectile
	var index: int = mini(int(age * 15.0), payload.frames.size()-1) if impacted else int(age * 5.0) % payload.frames.size()
	sprite.texture = payload.frames[index]
	sprite.pixel_size = payload.size_metres.x / float(sprite.texture.get_width())
