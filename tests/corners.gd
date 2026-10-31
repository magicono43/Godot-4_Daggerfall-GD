extends "res://tests/climbing.gd"
var solids: Array[StaticBody3D] = []

func clear_solids() -> void:
	for solid in solids:
		solid.queue_free()
	solids.clear()
	await frames(2)

func climb_start() -> void:
	await reset()
	await attach()
	await frames(60)
	release()

func corner_clearance(at: Vector3) -> float:
	return Vector2(maxf(absf(at.x) - 1.0, 0), maxf(absf(at.z + 2.0) - 1.0, 0)).length()

func run() -> void:
	for action in ["forward", "back", "left", "right", "jump", "sprint", "reload_movement", "movement_debug", "release_mouse", "interact", "reset"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	arena = Node3D.new()
	root.add_child(arena)
	box(Vector3(60, 1, 60), Vector3(0, -0.5, 0))
	player = preload("res://scripts/player.gd").new()
	arena.add_child(player)
	solids.append(box(Vector3(2, 6, 2), Vector3(0, 3, -2)))
	await climb_start()
	check(player.climbing.active, "Square pillar attachment starts corner tests")
	var height := player.position.y
	Input.action_press("right")
	var clearance := 100.0
	var longest_move := 0.0
	for i in 110:
		var previous := player.position
		await frames(1)
		clearance = minf(clearance, corner_clearance(player.position))
		longest_move = maxf(longest_move, player.position.distance_to(previous))
	release()
	check(player.climbing.active and player.climbing.corners.outside_turns >= 1 and player.climbing.wall_normal.x > 0.9, "D wraps an outside corner onto adjacent pillar face")
	check(clearance > 0.34 and longest_move < 0.04, "Outside turn preserves capsule clearance without position jumps")
	check(absf(player.position.y - height) < 0.03 and absf(player.rotation.y) < 0.001, "Outside turn preserves height and free-look yaw")
	Input.action_press("right")
	await frames(500)
	release()
	check(player.climbing.active and player.climbing.corners.outside_turns >= 4, "Continuous D traverses all four outside pillar corners")
	await climb_start()
	player.rotation.y = 0.7
	Input.action_press("left")
	await frames(600)
	release()
	check(player.climbing.active and player.climbing.corners.outside_turns >= 4 and absf(player.rotation.y - 0.7) < 0.001, "Continuous A wraps all four corners while free-look yaw stays unchanged")
	await climb_start()
	Input.action_press("right")
	for i in 100:
		await frames(1)
		if player.climbing.corners.active and float(player.climbing.corners.state.progress) > 0.3:
			break
	release()
	var before := player.position
	await frames(15)
	check(player.climbing.corners.active and player.position.distance_to(before) < 0.01, "Releasing strafe holds midway around outside corner")
	Input.action_press("forward")
	await frames(20)
	release()
	check(player.climbing.active and player.position.y > before.y + 0.45, "Climbing upward remains available during outside turn")
	Input.action_press("left")
	await frames(35)
	release()
	check(player.climbing.active and not player.climbing.corners.active and player.climbing.wall_normal.z > 0.9, "A reverses a partial outside turn onto the original face")
	await start_partial_turn()
	Input.action_press("back")
	for i in 180:
		await frames(1)
		if not player.climbing.active:
			break
	release()
	await frames(10)
	check(not player.climbing.active and player.is_grounded(), "Descending during a corner turn returns to grounded motion")
	await start_partial_turn()
	var ceiling := box(Vector3(10, 0.2, 10), Vector3(0, 4.15, -2))
	Input.action_press("forward")
	Input.action_press("right")
	await frames(40)
	release()
	check(player.climbing.active and player.position.y + player.STANDING_HEIGHT < 4.055 and player.climbing.corners.outside_turns >= 1, "Ceiling stops ascent while lateral corner traversal stays clear")
	ceiling.queue_free()
	await frames(2)
	await start_partial_turn()
	Input.action_press("jump")
	await frames(2)
	release()
	check(not player.climbing.active and player.flight_horizontal.length() > 2.9, "Space ejects from midway around an outside turn")
	await start_partial_turn()
	solids[0].set_meta("climbable", false)
	await frames(3)
	check(not player.climbing.active, "Removing corner support ends a held turn")
	solids[0].set_meta("climbable", true)
	await clear_solids()
	solids.append(box(Vector3(8, 6, 1), Vector3(0, 3, -2)))
	solids.append(box(Vector3(1, 6, 6), Vector3(2.5, 3, 0)))
	await climb_start()
	Input.action_press("right")
	await frames(140)
	release()
	check(player.climbing.active and player.climbing.corners.inside_turns >= 1 and player.climbing.wall_normal.x < -0.9 and player.position.z > -0.5, "D follows an inside corner along its adjoining wall")
	Input.action_press("left")
	await frames(120)
	release()
	check(player.climbing.active and player.climbing.corners.inside_turns >= 2 and player.climbing.wall_normal.z > 0.9, "A traverses the same inside corner in reverse")
	solids[1].set_meta("climbable", false)
	await climb_start()
	Input.action_press("right")
	await frames(140)
	release()
	check(player.climbing.active and player.climbing.corners.inside_turns == 0 and player.position.x < 1.66, "Excluded inside wall blocks traversal without allowing a corner transfer")
	await clear_solids()
	solids.append(box(Vector3(2, 6, 0.5), Vector3(0, 3, -1.25)))
	solids.append(box(Vector3(0.5, 6, 2), Vector3(0.75, 3, -3)))
	await climb_start()
	Input.action_press("right")
	var deepest_z := 100.0
	for i in 300:
		await frames(1)
		deepest_z = minf(deepest_z, player.position.z)
	release()
	check(deepest_z > -1.9, "Corner following stays on connected faces rather than jumping the gap")
	await clear_solids()
	var panel := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var plane := ConcavePolygonShape3D.new()
	plane.backface_collision = true
	plane.set_faces(PackedVector3Array([Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,6,-1),Vector3(-1,0,-1),Vector3(1,6,-1),Vector3(-1,6,-1)]))
	shape.shape = plane
	panel.add_child(shape)
	arena.add_child(panel)
	solids.append(panel)
	await climb_start()
	Input.action_press("right")
	await frames(100)
	release()
	check(not player.climbing.active, "A wall ending without an adjacent face causes ordinary falling")
	await clear_solids()
	arena.queue_free()
	await frames(2)
	await original_pillars()
	print("CORNERS %d/%d" % [results.size() - failures.size(), results.size()])
	var report := FileAccess.open("res://tests/corner_results.txt", FileAccess.WRITE)
	report.store_string("\n".join(results) + "\n")
	quit(0 if failures.is_empty() else 1)

func start_partial_turn() -> void:
	await climb_start()
	Input.action_press("right")
	for i in 100:
		await frames(1)
		if player.climbing.corners.active and float(player.climbing.corners.state.progress) > 0.3:
			break
	release()

func original_pillars() -> void:
	var level: Node3D = load("res://main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(30)
	player = level.player
	player.movement.profile.values = preload("res://scripts/movement_profile.gd").DEFAULTS.duplicate(true)
	for id in ["hall_structure_25347", "hall_structure_25587"]:
		var shaft: Node3D = level.model_nodes[id]
		var mesh: MeshInstance3D = shaft.get_child(0)
		var bounds: AABB = shaft.global_transform * mesh.mesh.get_aabb()
		var center := bounds.get_center()
		player.climbing.reset()
		player.position = Vector3(center.x, 12.85, bounds.end.z + 2.0)
		player.velocity = Vector3.ZERO
		player.flight_horizontal = Vector3.ZERO
		player.stair_supported = false
		player.look_at(Vector3(center.x, player.position.y, center.z))
		await frames(25)
		Input.action_press("forward")
		await frames(330)
		release()
		check(player.climbing.active and player.position.y > 18.0, id + " climbs from original pedestal through tapered shaft")
		var before := player.position
		Input.action_press("right")
		await frames(230)
		release()
		check(player.climbing.active and player.climbing.corners.outside_turns > 0, id + " supports outside-corner traversal on original triangles")
		check(absf(player.position.y - before.y) < 0.1, id + " corner traversal retains climbing height")
		if DisplayServer.get_name() != "headless" and id == "hall_structure_25587":
			player.set_physics_process(false)
			player.camera.look_at(player.position + Vector3(-3, -1, 4))
			player.show_movement_debug = true
			await frames(5)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/pillar_corner.png")
			player.camera.rotation = Vector3.ZERO
			player.set_physics_process(true)
	player.climbing.reset()
	player.position = level.classic.to_world([640, -512, 900]) + Vector3.UP * 0.04
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.stair_supported = false
	player.look_at(player.position + Vector3.LEFT)
	await frames(20)
	Input.action_press("forward")
	await frames(400)
	release()
	Input.action_press("right")
	await frames(900)
	release()
	check(player.climbing.active and player.climbing.corners.inside_turns > 0, "Original hall walls support inside-corner traversal")
