extends "res://scripts/main.gd"
## Opt-in authored fixture. Coordinates and steps are independent of original RDB.
const ORIGIN := Vector3(200, 0, 0)
const WATER_BOUNDS := AABB(Vector3(194, -4, -8), Vector3(12, 4, 16))
var underwater_overlay: ColorRect
var climb_walls: Array[StaticBody3D] = []

func box(size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("section_role", "geometry")
	body.set_meta("climbable", false)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	world_root.add_child(body)
	body.position = ORIGIN + at
	return body

func _ready() -> void:
	super._ready()
	if not ready_to_play:
		return
	persistence_context = "authored_swimming_pool_v1"
	persistence.slot_path = "res://saves/swimming_pool.json"
	player.teleport.section = section_path + ":" + persistence_context
	var stone := Color(0.42, 0.48, 0.52)
	box(Vector3(12, 0.5, 16), Vector3(0, -4.25, 0), stone)
	box(Vector3(12, 0.5, 6), Vector3(0, -0.25, 11), stone)
	# Climbable basin walls end at a wide dry rim so water pits have a real
	# mantle/exit, without enabling climbing on the shallow stair risers.
	for side in [-1, 1]:
		var wall := box(Vector3(0.5, 4, 22), Vector3(side * 6.25, -2, 3), stone)
		wall.set_meta("climbable", true)
		climb_walls.append(wall)
		var rim := box(Vector3(2, 0.5, 22), Vector3(side * 7, -0.25, 3), stone)
		# The rim shares the wall plane: its exposed lip must remain climbable.
		rim.set_meta("climbable", true)
	var end_wall := box(Vector3(12, 4, 0.5), Vector3(0, -2, -8.25), stone)
	end_wall.set_meta("climbable", true)
	climb_walls.append(end_wall)
	var end_rim := box(Vector3(16, 0.5, 2), Vector3(0, -0.25, -9), stone)
	end_rim.set_meta("climbable", true)
	box(Vector3(12, 2, 0.5), Vector3(0, 1, 14.25), stone)
	# Sixteen visible 25cm risers, 50cm treads. No hidden ramp.
	for i in 16:
		var height := (i + 1) * 0.25
		box(Vector3(4, height, 0.5), Vector3(0, -4 + height / 2, 0.25 + i * 0.5), Color(0.52, 0.56, 0.55) if i % 2 == 0 else stone)
	# Surface has no collision; only explicit bounds determine immersion.
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 16)
	surface.mesh = plane
	surface.position = ORIGIN
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.08, 0.42, 0.58, 0.48)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = material
	world_root.add_child(surface)
	var water := preload("res://scripts/water_volume.gd").new()
	if not water.configure(WATER_BOUNDS):
		push_error("Invalid authored pool bounds")
		return
	player.swimming.volumes.append(water)
	add_light(ORIGIN + Vector3(0, 4, 5), 2.0, 22.0)
	add_light(ORIGIN + Vector3(0, -1, -4), 1.0, 12.0)
	for child in presentation.hud.get_children():
		if child is Label and child.text == "PRIVATEER'S HOLD":
			child.text = "SWIMMING TEST POOL"
		elif child is Label and child.text.begins_with("EXPERIMENT 01"):
			child.text = "AUTHORED PROTOTYPE / Not original dungeon content"
	underwater_overlay = ColorRect.new()
	underwater_overlay.color = Color(0.04, 0.28, 0.42, 0.22)
	underwater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.hud.add_child(underwater_overlay)
	presentation.hud.move_child(underwater_overlay, 0)
	player.spawn = ORIGIN + Vector3(0, 0.08, 11)
	if not restoring:
		player.position = player.spawn
		player.rotation = Vector3.ZERO
		player.swimming.reset()

func _process(delta: float) -> void:
	super._process(delta)
	if not ready_to_play or not is_instance_valid(underwater_overlay):
		return
	status.text = "AUTHORED SWIMMING TEST POOL\nWASD swim | Page Up ascend | Page Down descend\nCtrl crouch | R reset | K/L separate pool save\nExit via centre steps, or hold W against a wall to climb onto the rim."
	underwater_overlay.position = Vector2.ZERO
	underwater_overlay.size = presentation.display_rect.size
	underwater_overlay.visible = player.swimming.submerged and not player.is_dead()
