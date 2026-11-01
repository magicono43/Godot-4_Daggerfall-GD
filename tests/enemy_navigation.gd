extends "res://tests/climbing.gd"
var level: Node3D
var enemy: CharacterBody3D
var captured_stair := false

func place(native: Array) -> void:
	enemy.position = level.classic.to_world(native) + Vector3.UP * 0.02
	enemy.velocity = Vector3.ZERO
	enemy.navigation.clear()

func travel(native: Array, limit := 2400) -> bool:
	var goal: Vector3 = level.classic.to_world(native)
	enemy.navigation.observe(goal)
	enemy.navigation.memory_left = 120.0
	var max_step := 0.0
	for i in limit:
		await frames(1)
		if i == 120 and native == [1560,-1024,1024] and not captured_stair:
			captured_stair = true
			await preview("navigation_stairs")
		max_step = maxf(max_step, absf(enemy.navigation.last_step))
		if enemy.position.distance_to(goal) < 0.4:
			print("NAV ARRIVED ", native, " position=", enemy.position, " max_step=", max_step)
			return true
	print("NAV STUCK ", native, " position=", enemy.position, " state=", enemy.navigation.state, " detour=", enemy.navigation.detour_goal, " timer=", enemy.navigation.detour_left)
	return false

func run() -> void:
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(5)
	player = level.player
	enemy = level.world_root.get_node("hall_combat_target")
	enemy.navigation.rng.seed = 123456
	check(not level.world_root.get_children().any(func(node): return node is NavigationRegion3D), "Enemy steering creates no navmesh or route region")
	check(enemy.navigation.enabled and not level.enemy.navigation.enabled, "Only hall Skeleton opts into navigation")
	enemy.melee.enabled = false
	var before := enemy.position
	await frames(65)
	check(enemy.position.distance_to(before) > 1.0 and enemy.position.distance_to(player.position) < 2.0, "Skeleton detects and physically approaches hall spawn")
	check(enemy.mobile.state in ["idle", "move"], "Pursuit uses original idle/movement sprites")
	await preview("navigation_approach")
	player.controls_active = false
	await frames(3)
	before = enemy.position
	await frames(30)
	check(enemy.position.distance_to(before) < 0.02 and enemy.navigation.detour_left <= 0.0, "Mouse release stops pursuit and clears path")
	# Test path/motor separately from perception by giving explicit observed goals.
	player.controls_active = true
	player.position = Vector3(100, 100, 100)
	player.set_physics_process(false)
	place([960,-512,1024])
	await frames(5)
	check(await travel([1560,-1024,1024]), "Enemy continuously climbs original giant staircase")
	check(await travel([1664,-1024,768]), "Enemy follows upper landing")
	check(await travel([1664,-1024,384]), "Enemy turns toward gallery staircase")
	check(await travel([1200,-1280,384]), "Enemy climbs to original 32 m upper gallery")
	check(await travel([1664,-1024,384]), "Enemy descends gallery stairs")
	check(await travel([1560,-1024,1024]), "Enemy returns along upper landing")
	check(await travel([960,-512,1024]), "Enemy descends original giant staircase")
	place([640,-512,768])
	await frames(5)
	check(await travel([384,-512,570]), "Enemy follows original hall floor toward exit")
	check(await travel([384,-512,400]), "Enemy opens and passes original great hall door")
	await preview("navigation_door")
	check(level.model_nodes.great_hall_door.opened, "Pursuit opens unlocked original door")
	check(await travel([300,-512,128]), "Enemy turns through original anteroom")
	check(await travel([128,-512,128]), "Enemy opens second door and enters corridor")
	check(level.model_nodes.hall_approach_door.opened, "Second original door opens for enemy")
	check(await travel([128,-512,512]), "Enemy reaches original second stair top")
	check(await travel([128,-256,768]), "Enemy descends original second staircase")
	await isolated_checks()
	await motor_guards()
	await detour_contract()
	var file := FileAccess.open("res://tests/enemy_navigation_results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results))
	print("NAVIGATION RESULTS: ", results.size()-failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)

func isolated_checks() -> void:
	arena = level.world_root
	var floor := box(Vector3(8, 1, 8), Vector3(100, -0.5, 100))
	var obstacle := box(Vector3(2, 3, 2), Vector3(100, 1.5, 100))
	var platform := box(Vector3(3, 2, 3), Vector3(106, 1, 100))
	enemy.navigation.clear()
	enemy.position = Vector3(100, 0.02, 103)
	enemy.home = enemy.position
	enemy.velocity = Vector3.ZERO
	player.position = Vector3(100, 0.02, 97)
	await frames(15)
	check(enemy.navigation.memory_left == 0 and enemy.position.distance_to(Vector3(100, 0, 103)) < 0.03, "Unseen player behind obstacle does not alert enemy")
	player.position = Vector3(103, 0.02, 103)
	await frames(15)
	check(enemy.navigation.memory_left > 9.0, "Seeing player records a pursuit goal")
	player.position = Vector3(100, 0.02, 97)
	await frames(5)
	check(enemy.navigation.last_seen.z > 102, "Occlusion retains last seen goal instead of tracking hidden player")
	# Once the destination is explicitly observed, the route must bend around cover.
	player.position = Vector3(200, 100, 200)
	enemy.navigation.observe(Vector3(100, 0, 97))
	enemy.navigation.memory_left = 120
	enemy.navigation.detour_left = 0.0
	var avoided := true
	var arrived := false
	var turned := false
	for i in 600:
		await frames(1)
		var point := enemy.position
		var separation := Vector2(maxf(absf(point.x - 100) - 1.0, 0.0), maxf(absf(point.z - 100) - 1.0, 0.0)).length()
		avoided = avoided and separation >= 0.30 # Allow Jolt's shallow contact slop at rounded corners.
		turned = turned or absf(point.x - 100) > 1.35
		if point.distance_to(Vector3(100, 0, 97)) < 0.4:
			arrived = true
			break
	check(arrived and avoided and turned, "Local tested detours move around solid obstacle without penetration")
	enemy.navigation.memory_left = 0.05
	await frames(12)
	var stopped := enemy.position
	await frames(20)
	check(enemy.navigation.state == "idle" and enemy.navigation.detour_left <= 0.0 and enemy.position.distance_to(stopped) < 0.02, "Expired trail stops pursuit")
	enemy.navigation.observe(Vector3(106, 2, 100))
	await frames(40)
	check(enemy.position.y < 0.05 and enemy.position.x < 104.0, "Local probes cannot climb or fly to disconnected elevated target")
	player.position = enemy.position + Vector3(0, 0.02, -1.4)
	enemy.melee.enabled = true
	await frames(5)
	stopped = enemy.position
	await frames(28)
	check(enemy.position.distance_to(stopped) < 0.03 and player.health.current == 90, "Enemy stops moving and uses animation-timed melee in range")
	enemy.receive_damage(100)
	await frames(4)
	stopped = enemy.position
	await frames(30)
	check(enemy.position == stopped and enemy.navigation.detour_left <= 0.0 and enemy.mobile.state == "corpse", "Death clears pursuit and retains inert corpse")

func motor_guards() -> void:
	# Exercise the new optional tread-edge mode against an oversized ledge.
	var floor := box(Vector3(10, 1, 6), Vector3(120, -0.5, 100))
	var ledge := box(Vector3(2, 1, 3), Vector3(122, 0.5, 100))
	var actor = preload("res://scripts/enemy.gd").new()
	actor.navigation.enabled = true
	actor.player = player
	actor.position = Vector3(120, 0.02, 100)
	arena.add_child(actor)
	actor.set_physics_process(false)
	await frames(3)
	for i in 100:
		actor.navigation.move(actor, Vector3.RIGHT * 2.5, 1.0/60.0)
		await frames(1)
	check(actor.position.x < 120.75 and actor.position.y < 0.05, "NPC tread-edge assistance cannot climb a one-metre ledge")
	actor.queue_free()
	ledge.queue_free()
	floor.queue_free()

func preview(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var camera := Camera3D.new()
	level.world_root.add_child(camera)
	camera.global_position = enemy.global_position + (Vector3(0, 1.8, 2) if name == "navigation_door" else Vector3(-4, 2.3, 4))
	camera.fov = 75
	camera.look_at(enemy.global_position + Vector3.UP)
	camera.current = true
	var active := enemy.is_physics_processing()
	enemy.set_physics_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + name + ".png")
	enemy.set_physics_process(active)
	camera.queue_free()
	player.camera.current = true

func detour_contract() -> void:
	var floor := box(Vector3(5, 1, 5), Vector3(140, -0.5, 100))
	var wall := box(Vector3(3, 3, 0.1), Vector3(140, 1.5, 99.58))
	var actor = preload("res://scripts/enemy.gd").new()
	actor.navigation.enabled = true
	actor.sprite_payload = enemy.sprite_payload
	actor.player = player
	actor.position = Vector3(140, 0.02, 100)
	arena.add_child(actor)
	actor.set_physics_process(false)
	await frames(3)
	var steering = actor.navigation
	steering.rng.seed = 123
	var forward := Vector3.FORWARD
	check(steering.probe(actor, forward).blocked, "Local capsule detects obstruction without any navigation map")
	steering.observe(actor.position + forward * 4)
	var alternate: Vector3 = steering.find_detour(actor, forward)
	var angle: float = forward.signed_angle_to(alternate, Vector3.UP) / (PI/4)
	check(not alternate.is_zero_approx() and absf(angle - roundf(angle)) < 0.0001 and steering.clear_direction(actor, alternate) and absf(steering.detour_goal.distance_to(actor.position) - 2.0) < 0.001, "Detour selects a tested 45-degree direction and short local destination")
	var side: bool = steering.clockwise
	steering.detour_left = 0.4
	steering.find_detour(actor, forward)
	check(steering.clockwise == side and is_equal_approx(steering.detour_left, 0.4), "Detour retains side preference and does not prolong an active detour timer")
	actor.position = Vector3(142, 0.02, 100)
	await frames(2)
	check(steering.probe(actor, Vector3.RIGHT).fall and not steering.clear_direction(actor, Vector3.RIGHT), "Local floor look-ahead rejects a genuine drop")
	actor.position = Vector3(140, 0.02, 100)
	steering.clear()
	steering.observe(actor.position)
	steering.last_direction = Vector3.RIGHT
	steering.steering(actor, 1.0/60.0, false)
	check(steering.search_steps == 1 and steering.last_seen == actor.position, "Lost-target search extends last observed direction without reading hidden position")
	actor.queue_free()
	wall.queue_free()
	floor.queue_free()
