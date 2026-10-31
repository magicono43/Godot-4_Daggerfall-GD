extends SceneTree
var level: Node3D
var player: CharacterBody3D
var results: Array[String] = []
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)
	print(results[-1])

func walk(native: Array, running: bool = false) -> bool:
	var target: Vector3 = level.classic.to_world(native)
	player.look_at(Vector3(target.x, player.position.y, target.z))
	player.camera.rotation.x = 0
	Input.action_press("forward")
	if running:
		Input.action_press("sprint")
	var unsupported := 0
	var longest_unsupported := 0
	for i in 1800:
		await frames(1)
		unsupported = 0 if player.is_grounded() else unsupported + 1
		longest_unsupported = maxi(longest_unsupported, unsupported)
		if Vector2(player.position.x - target.x, player.position.z - target.z).length() < 0.12:
			break
	Input.action_release("forward")
	Input.action_release("sprint")
	await frames(12)
	var arrived: bool = player.position.distance_to(target) < 0.35 and player.is_grounded() and longest_unsupported <= 3
	check(arrived, "Walk native route %s" % str(native))
	print("ROUTE_POSITION ", player.position, " target=", target, " unsupported=", longest_unsupported)
	return arrived

func open_door(id: String) -> bool:
	var door: AnimatableBody3D = level.model_nodes[id]
	var mesh: MeshInstance3D = door.get_child(0)
	var center := door.global_transform * mesh.mesh.get_aabb().get_center()
	player.camera.look_at(center)
	await frames(3)
	check(player.interact_target == door, id + " acquired by original interaction ray")
	var event := InputEventAction.new()
	var before := player.position
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	Input.action_release("interact")
	await frames(45)
	check(door.opened and not door.busy, id + " opens with attached collision")
	check(player.position.distance_to(before) < 0.02, id + " opens away without displacing the player")
	player.camera.rotation.x = 0
	return door.opened

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func capture(name: String, at: Vector3, target: Vector3) -> void:
	player.position = at
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.step_camera_offset = 0
	player.stair_supported = false
	player.look_at(Vector3(target.x, at.y, target.z))
	player.camera.look_at(target)
	player.set_physics_process(false)
	for i in 5:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/" + name + ".png")
	player.set_physics_process(true)

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.use_original_start = true
	root.add_child(level)
	current_scene = level
	await frames(60)
	if not level.ready_to_play:
		print(level.classic.error)
		quit(1)
		return
	player = level.player
	player.movement.profile.values = preload("res://scripts/movement_profile.gd").DEFAULTS.duplicate(true)
	print("EXPANSION_COUNTS ", level.model_nodes.size(), " triangles=", level.classic.triangle_count, " materials=", level.classic.texture_count)
	# Rounded bends must be traversed between their portals, not through the
	# model origin, which can lie in the solid outside corner of the wall.
	var route := [[512,0,1200],[512,0,1000],[512,0,800],[750,0,768],[850,0,768],"first_door",[960,0,768],[1080,0,768],[1080,0,640],[720,-256,640],[640,-256,640],[640,-256,512],[704,-256,448],[768,-256,384],[1792,-256,384],[1920,-256,384],[1920,-256,512],[1920,-256,1536],[1920,-256,1664],[1792,-256,1664],[1024,-256,1664],[960,-256,1600],[896,-256,1536],[896,-256,1024],[832,-256,960],[768,-256,896],[256,-256,896],[192,-256,832],[128,-256,768],[128,-512,512],[128,-512,256],[128,-512,128],[220,-512,128],"hall_approach_door",[300,-512,128],[384,-512,384],[384,-512,480],"great_hall_door",[384,-512,570],[640,-512,768],[960,-512,1024],[1560,-1024,1024]]
	for entry in route:
		var ok: bool = await open_door(entry) if entry is String else await walk(entry)
		if not ok:
			break
	if failures.is_empty():
		for landing in [[1664,-1024,768],[1664,-1024,384],[1550,-1024,384],[1200,-1280,384],[1550,-1024,384],[1664,-1024,384],[1664,-1024,768],[1560,-1024,1024]]:
			if not await walk(landing):
				break
		await capture("great_staircase_top", player.position, level.classic.to_world([640,-600,1024]))
		await walk([960,-512,1024])
		await walk([1560,-1024,1024], true)
		await walk([960,-512,1024], true)
		player.look_at(player.position + Vector3.RIGHT)
		Input.action_press("forward")
		Input.action_press("jump")
		var initial_x := player.position.x
		await frames(2)
		Input.action_release("jump")
		await frames(60)
		Input.action_release("forward")
		check(player.position.x - initial_x > 2.5, "Moving jump on great staircase maintains forward progress")
		await frames(60)
		await walk([1560,-1024,1024])
		await walk([960,-512,1024])
		await walk([640,-512,768])
		await walk([384,-512,570])
		# Return along the identical original route with all three doors open.
		for i in range(route.size() - 6, -1, -1):
			if route[i] is Array and not await walk(route[i], true):
				break
		await walk([510,0,1672])
	var space := player.get_world_3d().direct_space_state
	var roof_ray := PhysicsRayQueryParameters3D.create(level.classic.to_world([640,-600,900]), level.classic.to_world([640,-1500,900]), 1, [player.get_rid()])
	var roof := space.intersect_ray(roof_ray)
	check(not roof.is_empty() and absf(roof.position.y - 35.2) < 0.05, "Great hall original ceiling closes the 22.4 m high chamber")
	var wall_ray := PhysicsRayQueryParameters3D.create(level.classic.to_world([640,-900,900]), level.classic.to_world([200,-900,900]), 1, [player.get_rid()])
	var wall := space.intersect_ray(wall_ray)
	check(not wall.is_empty() and wall.collider.get_meta("section_id", "") == "great_hall_northwest", "Tall original west wall provides continuous collision for future climbing")
	var floor_ray := PhysicsRayQueryParameters3D.create(level.classic.to_world([640,-540,900]), level.classic.to_world([640,-480,900]), 1, [player.get_rid()])
	var floor_hit := space.intersect_ray(floor_ray)
	check(not floor_hit.is_empty() and absf(floor_hit.position.y - 12.8) < 0.05, "Great hall original floor supports the wall-test area")
	await capture("great_hall_overview", level.classic.to_world([500,-620,640]), level.classic.to_world([1250,-850,1100]))
	await capture("great_staircase", level.classic.to_world([800,-520,1024]), level.classic.to_world([1250,-900,1024]))
	var file := FileAccess.open("res://tests/expansion_results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results) + "\n")
	print("EXPANSION ", results.size() - failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)
