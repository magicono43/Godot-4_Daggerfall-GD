extends SceneTree
## Controlled before/after camera captures; never edits the supplied evidence.
var level: Node3D
const OUTPUT := "res://tests/scale_calibration/"

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Capture requires a rendering display")
		quit(1)
		return
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	for i in 60:
		await physics_frame
	if not level.ready_to_play:
		quit(1)
		return
	level.player.set_physics_process(false)
	level.enemy.set_physics_process(false)
	var positions := {
		"cave": [Vector3(510, 0, -1672), Vector3(512, 0, -1152)],
		"arch": [Vector3(512, 0, -1195), Vector3(512, 0, -960)],
		"corridor": [Vector3(720, 0, -768), Vector3(900, 0, -768)],
		"door": [Vector3(858, 0, -768), Vector3(900, 0, -768)],
	}
	for location in positions:
		var feet: Vector3 = positions[location][0] * 0.025 - level.classic.origin
		var target: Vector3 = positions[location][1] * 0.025 - level.classic.origin
		level.player.position = feet + Vector3.UP * 0.001
		level.player.look_at(Vector3(target.x, level.player.position.y, target.z))
		level.player.camera.rotation = Vector3.ZERO
		# Reproduce the old view's camera parameters at the identical world position.
		level.presentation.set_profile("widescreen")
		# The old scene filled 1280x720. Preserve that aspect inside this 1280x800
		# capture canvas, rather than accidentally comparing a 16:10 legacy camera.
		level.presentation.viewport.size = Vector2i(1280, 720)
		level.presentation.display.position = Vector2(0, 40)
		level.presentation.display.size = Vector2(1280, 720)
		level.presentation.hud.position = Vector2(0, 40)
		level.presentation.hud.size = Vector2(1280, 720)
		level.player.camera.position.y = 1.55
		level.player.camera.fov = 78
		await capture(location + "_legacy_camera")
		level.presentation.set_profile("dfu_reference")
		level.player.camera.position.y = level.player.EYE_HEIGHT
		level.player.camera.fov = 75
		await capture(location + "_dfu_reference")
	print("SCALE_CAPTURES: 8 controlled views in tests/scale_calibration")
	quit()
