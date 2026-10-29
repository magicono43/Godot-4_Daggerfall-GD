extends SceneTree
var level: Node3D
var results: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	results.append(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures.append(label)
	print(results[-1])

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func walk_to(point: Vector3, limit: int = 360) -> void:
	var player: CharacterBody3D = level.player
	player.look_at(Vector3(point.x, player.position.y, point.z))
	Input.action_press("forward")
	for i in limit:
		await physics_frame
		if Vector2(player.position.x - point.x, player.position.z - point.z).length() < 0.18:
			break
	Input.action_release("forward")
	await frames(12)

func screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(90)
	check(level.ready_to_play, "Original source loads")
	if not level.ready_to_play:
		quit(1)
		return
	check(level.classic.provenance.block == "S0000999.RDB", "MAPS resolves original starting block")
	check(level.classic.provenance.location_id == 50049, "Privateer's Hold location ID")
	check(level.classic.objects.size() == 7 and level.classic.triangle_count == 318, "RDB placements and ARCH3D triangles")
	check(level.classic.texture_count == 19, "All 19 original slice materials decoded")
	check(level.player.is_on_floor() and absf(level.player.position.y) < 0.08, "Player rests on original floor")
	await screenshot("res://tests/start_room.png")
	var center: Vector3
	# Use actual imported mesh bounds to locate the opening rather than guessed coordinates.
	var instance: MeshInstance3D = level.door.get_child(0)
	center = level.door.transform * instance.mesh.get_aabb().get_center()
	var normal := Vector3(-1, 0, 0)
	var inside := center + normal * 1.2
	inside.y = 0.02
	print("DOOR center=", center, " player=",level.player.position)
	for waypoint in [Vector3(512, 0, -1200), Vector3(512, 0, -1000), Vector3(512, 0, -800), Vector3(750, 0, -768)]:
		await walk_to(waypoint * 0.025 - level.classic.ORIGIN)
		print("WAYPOINT ",level.player.position)
	await walk_to(inside)
	check(level.player.position.distance_to(inside) < 0.6, "Walk from original start to door")
	level.player.look_at(Vector3(center.x - normal.x * 2, level.player.position.y, center.z - normal.z * 2))
	Input.action_press("forward")
	await frames(90)
	Input.action_release("forward")
	await frames(12)
	check((level.player.position - center).dot(normal) > 0.18, "Closed original door blocks capsule")
	level.player.camera.look_at(center)
	await frames(3)
	check(level.player.interact_target == level.door, "Look ray acquires nearby door")
	check(not level.enemy.noticed, "Closed door occludes enemy sight")
	var use_event := InputEventAction.new()
	use_event.action = "interact"
	use_event.pressed = true
	Input.parse_input_event(use_event)
	await frames(2)
	Input.action_release("interact")
	await frames(60)
	check(level.door.opened and not level.door.busy, "E interaction opens animated collidable door")
	level.player.camera.rotation.x = 0
	var beyond := center - normal * 2.5
	beyond.y = 0.02
	await walk_to(beyond, 180)
	print("AFTER DOOR player=",level.player.position," target=",beyond," enemy=",level.enemy.position)
	check((level.player.position - center).dot(normal) < -1.2, "Walk through open door onto original corridor")
	check(level.player.is_on_floor(), "Corridor floor supports player")
	await frames(90)
	check(level.encounter and level.enemy.noticed, "Enemy detects player through open passage")
	level.player.camera.look_at(level.enemy.global_position + Vector3.UP * 0.5)
	await screenshot("res://tests/enemy_encounter.png")
	# Test caps at the original openings, using physics rays across each boundary.
	for pair in [[Vector3(1080, 60, -640), Vector3(980, 60, -640)]]:
		var query := PhysicsRayQueryParameters3D.create(pair[0] * 0.025 - level.classic.ORIGIN, pair[1] * 0.025 - level.classic.ORIGIN, 1)
		var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider.is_in_group("slice_boundaries"), "Greybox passage cap blocks boundary ray")
	level.player.position = center + normal * 0.5
	level.player.position.y = 0.01
	level.door.interact()
	check(level.door.opened, "Door refuses unsafe close beside player")
	level.player.position = center + normal * 3.0
	level.player.position.y = 0.01
	level.door.interact()
	await frames(60)
	check(not level.door.opened and not level.door.busy, "Door closes again when clear")
	var missing := preload("res://scripts/classic_data.gd").new()
	missing.arena_path = "res://tests/absent_arena2"
	check(not missing.load_slice() and not missing.error.is_empty(), "Missing original data produces explicit failure")
	# Moving into the room wall must stop, independent of the door collider.
	level.player.position = Vector3(0, 0.05, 0)
	await frames(15)
	await walk_to(Vector3(30, 0.05, 0), 360)
	check(level.player.position.x < 7 and level.player.is_on_floor(), "Original room wall blocks player")
	var file := FileAccess.open("res://tests/results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results) + "\n")
	print("TESTS ", results.size() - failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)






