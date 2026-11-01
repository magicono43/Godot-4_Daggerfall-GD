extends "res://tests/climbing.gd"
var target: CharacterBody3D

func swing() -> void:
	player.combat.request_attack(player)
	await frames(ceili((player.combat.windup + player.combat.recovery) * 60.0) + 3)

func run() -> void:
	for action in ["forward", "back", "left", "right", "jump", "sprint", "reload_movement", "movement_debug", "release_mouse", "interact", "reset"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	arena = Node3D.new()
	root.add_child(arena)
	box(Vector3(20, 1, 20), Vector3(0, -0.5, 0))
	player = preload("res://scripts/player.gd").new()
	arena.add_child(player)
	await reset()
	target = preload("res://scripts/enemy.gd").new()
	target.player = player
	target.approach_enabled = false
	target.position = Vector3(0, 0, -1.6)
	arena.add_child(target)
	await frames(10)
	player.camera.look_at(target.global_position + Vector3.UP * 0.4)
	check(player.combat.request_attack(player), "Idle accepts attack")
	check(not player.combat.request_attack(player), "Windup rejects another attack")
	await frames(5)
	check(target.health.current == 30, "Windup applies no early damage")
	await frames(25)
	check(target.health.current == 20, "Strike applies exactly ten damage")
	check(not player.combat.request_attack(player), "Recovery rejects another attack")
	await frames(40)
	check(target.health.current == 20, "One swing never repeats damage")
	var wall := box(Vector3(3, 3, 0.12), Vector3(0, 1.5, -0.8))
	await frames(3)
	await swing()
	check(target.health.current == 20 and player.combat.feedback == "Blocked", "Solid obstruction blocks melee")
	wall.queue_free()
	await frames(3)
	target.position.z = -4
	await frames(3)
	await swing()
	check(target.health.current == 20, "Out of reach target takes no damage")
	target.position.z = -1.6
	await frames(3)
	player.controls_active = false
	check(not player.combat.request_attack(player), "Released mouse prevents attack")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	player._unhandled_input(click)
	check(player.controls_active and player.combat.elapsed < 0, "Mouse recapture does not attack")
	player.climbing.active = true
	check(not player.combat.request_attack(player), "Attached climbing prevents attacks")
	player.climbing.reset()
	player.combat.request_attack(player)
	player.controls_active = false
	await frames(15)
	check(target.health.current == 20 and player.combat.elapsed < 0, "Releasing controls cancels pending strike")
	player.controls_active = true
	await swing()
	await swing()
	check(target.health.current == 0 and not target.visible and target.collision_layer == 0, "Third hit kills and removes blocking collision")
	check(not target.receive_damage(10) and target.health.current == 0, "Dead target rejects further damage")
	var health = preload("res://scripts/health.gd").new()
	check(not health.apply_damage(-10) and health.current == 30, "Negative damage cannot heal")
	health.apply_damage(100)
	check(health.current == 0, "Overkill clamps health to zero")
	arena.queue_free()
	await frames(3)
	var level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	await frames(30)
	player = level.player
	var hall = level.world_root.get_node("hall_combat_target")
	check(level.enemies.size() == 2 and level.enemy.name == "placeholder_enemy", "Hall addition preserves chamber enemy alias")
	check(not hall.approach_enabled and absf(hall.position.y - player.position.y) < 0.2 and hall.position.distance_to(player.position) < 5, "Hall target rests on spawn floor nearby")
	player.camera.look_at(hall.global_position + Vector3.UP * 0.4)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/combat_preview.png")
	# Approach along the original hall floor, then exercise the same combat controller.
	player.position = hall.position + Vector3(-1.5, 0.05, 0)
	await frames(3)
	player.camera.look_at(hall.global_position + Vector3.UP * 0.4)
	# Exercise the real RMB binding after main configures gameplay input.
	player._unhandled_input(click)
	await frames(35)
	check(hall.health.current == 20, "Original hall target receives melee damage")
	level.queue_free()
	await frames(3)
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	await frames(5)
	player = level.player
	check(level.world_root.get_node("hall_combat_target").health.current == 30 and player.combat.elapsed < 0, "Fresh scene restores targets and attack state")
	var file := FileAccess.open("res://tests/combat_results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results))
	print("COMBAT RESULTS: ", results.size() - failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)
