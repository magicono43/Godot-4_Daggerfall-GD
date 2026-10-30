extends SceneTree
## Same geometry, lighting and camera for raw-versus-Classic material captures.
const OUTPUT := "res://tests/texture_fidelity/"
var level: Node3D
var raw: RefCounted

func _initialize() -> void:
	call_deferred("run")

func apply_materials(data: RefCounted) -> void:
	for item in level.classic.objects:
		var body: Node3D = level.world_root.get_node("Classic_%s_%d" % [item.model, item.offset])
		var mesh: ArrayMesh = body.get_child(0).mesh
		for surface in mesh.get_surface_count():
			var source := int(mesh.surface_get_material(surface).get_meta("source_texture"))
			mesh.surface_set_material(surface, data.material(source))

func capture(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Texture captures require a rendering display")
		quit(1)
		return
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for i in 60:
		await physics_frame
	if not level.ready_to_play:
		quit(1)
		return
	level.player.set_physics_process(false)
	level.enemy.set_physics_process(false)
	level.presentation.set_profile("dfu_reference")
	raw = preload("res://scripts/classic_data.gd").new()
	raw.arena_path = level.classic.arena_path
	assert(raw.load_slice(level.section_path))
	raw.dungeon_textures.table.assign([119, 120, 122, 123, 124, 168])
	raw.dungeon_textures.climate_base = 0
	var views := {
		"door_oblique": [Vector3(830, 0, -768), Vector3(900, 0, -735)],
		"cave_arch": [Vector3(512, 0, -1172), Vector3(512, 0, -960)],
	}
	for location in views:
		var feet: Vector3 = views[location][0] * 0.025 - level.classic.origin
		var target: Vector3 = views[location][1] * 0.025 - level.classic.origin
		level.player.position = feet + Vector3.UP * 0.001
		level.player.look_at(Vector3(target.x, level.player.position.y, target.z))
		level.player.camera.rotation = Vector3.ZERO
		apply_materials(raw)
		await capture(location + "_raw")
		apply_materials(level.classic)
		await capture(location + "_classic")
	print("TEXTURE_CAPTURES: 4 controlled views in tests/texture_fidelity")
	quit()
