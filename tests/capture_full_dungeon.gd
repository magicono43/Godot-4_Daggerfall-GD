extends SceneTree
## Controlled visual comparisons, separate from continuous traversal assertions.
var level: Node3D
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func pose(name: String, at: Vector3, target: Vector3) -> void:
	player.position = at
	player.look_at(Vector3(target.x, at.y, target.z))
	player.camera.look_at(target)
	for profile in ["dfu_reference", "widescreen"]:
		level.presentation.set_profile(profile)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/full_dungeon_views/" + name + "_" + profile + ".png")

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	for i in 10:
		await physics_frame
	if not level.ready_to_play:
		print(level.classic.error)
		quit(1)
		return
	player = level.player
	player.set_physics_process(false)
	player.movement.profile.values.look.radians_per_pixel = 0
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	for door in level.doors:
		door.request_open(player)
	for i in 45:
		await physics_frame
	DirAccess.make_dir_recursive_absolute("res://tests/full_dungeon_views")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dungeon_floor_audit.json"))
	for block in fixture.routes:
		var points: Array = fixture.routes[block]
		var end: Array = points[-1]
		var behind: Array = points[maxi(0, points.size() - 12)]
		await pose(block, Vector3(end[0],end[1],end[2]), Vector3(behind[0],behind[1]+1.71,behind[2]))
	var index := 0
	for route in fixture.upper_routes.values():
		var end: Array = route[-1]
		var behind: Array = route[maxi(0, route.size() - 12)]
		await pose("upper_" + str(index), Vector3(end[0],end[1],end[2]), Vector3(behind[0],behind[1]+1.71,behind[2]))
		index += 1
	for body in level.model_nodes.values():
		if body.get_meta("section_role") == "exit":
			var mesh: MeshInstance3D = body.get_child(0)
			var centre: Vector3 = body.transform * mesh.mesh.get_aabb().get_center()
			var normal: Vector3 = body.basis * Vector3.RIGHT
			await pose("exit_front", body.position + normal * 2.5, centre)
			await pose("exit_back", body.position - normal * 2.5, centre)
	for entry in level.classic.section.definition.static_loot:
		var pile: AnimatedSprite3D = level.billboard_nodes[entry.id]
		await pose("pile_" + entry.id, pile.position + Vector3(1.5,0,2), pile.position)
	print("FULL_DUNGEON_VIEWS captured both presentation modes")
	quit()
