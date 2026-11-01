extends SceneTree
const OUTPUT := "res://tests/decorations/"
var level: Node3D

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	for i in 60:
		await physics_frame
	if not level.ready_to_play:
		print(level.classic.error)
		quit(1)
		return
	level.player.set_physics_process(false)
	level.enemy.set_physics_process(false)
	var views := {
		"rear_cave": [[510, 0, 1450], [510, 0, 1760]],
		"cave_fire": [[590, 0, 1600], [646, -15, 1686]],
		"cave_bones": [[420, 0, 1460], [354, -10, 1546]],
		"chamber_prop_north": [[1190, 0, 600], [1289, -27, 528]],
		"chamber_prop_south": [[1190, 0, 680], [1291, -27, 752]]
	}
	for id in views:
		level.player.position = level.classic.to_world(views[id][0]) + Vector3.UP * 0.001
		var target: Vector3 = level.classic.to_world(views[id][1])
		level.player.look_at(Vector3(target.x, level.player.position.y, target.z))
		level.player.camera.look_at(target)
		await capture(id)
		if id == "cave_fire":
			await create_timer(0.12).timeout
			await capture("cave_fire_next_frame")
	print("DECORATION_CAPTURES: tests/decorations")
	quit()
