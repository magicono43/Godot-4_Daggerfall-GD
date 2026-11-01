extends "res://tests/climbing.gd"
var enemy: CharacterBody3D

func begin_attack() -> void:
	enemy.melee.enabled = false
	enemy.melee.cancel()
	player.controls_active = true
	player.position = Vector3(0, 0.02, 0)
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	await frames(3)
	enemy.melee.enabled = true
	await frames(2)

func door_frames(count: int) -> void:
	# Freeze the enemy motor so the oversized isolated hinge cannot shove it;
	# continue its real attack controller against the moving physical door.
	for i in count:
		enemy.melee.tick(enemy, 1.0 / 60.0)
		await frames(1)

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var bindings = preload("res://scripts/main.gd").new()
	bindings.configure_input()
	bindings.free()
	for action in ["forward", "back", "left", "right", "jump", "sprint", "reload_movement", "movement_debug", "release_mouse", "interact", "reset", "crouch"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	arena = Node3D.new()
	root.add_child(arena)
	box(Vector3(20, 1, 20), Vector3(0, -0.5, 0))
	player = preload("res://scripts/player.gd").new()
	arena.add_child(player)
	await reset()
	enemy = preload("res://scripts/enemy.gd").new()
	enemy.player = player
	enemy.approach_enabled = false
	enemy.position = Vector3(0, 0, -1.4)
	arena.add_child(enemy)
	await frames(3)
	await begin_attack()
	check(enemy.melee.phase == "windup" and enemy.body_material.albedo_color.g > 0.5, "In-range enemy visibly telegraphs attack")
	await frames(20)
	check(player.health.current == 100, "Windup does not damage player early")
	await frames(23)
	check(player.health.current == 90 and player.damage_flash > 0, "Strike applies ten damage with player feedback")
	await frames(30)
	check(player.health.current == 90 and enemy.melee.phase == "recovery", "Recovery prevents repeated damage")
	check(enemy.position.distance_to(enemy.home) < 0.01, "Attacking enemy remains stationary")
	await begin_attack()
	player.position.z = 1.5
	await frames(43)
	check(player.health.current == 90 and enemy.melee.last_result == "miss", "Backing out during windup avoids strike")
	await begin_attack()
	player.position = enemy.position + Vector3(0, 0.02, -1.4)
	await frames(43)
	check(player.health.current == 90, "Moving behind committed attack avoids strike")
	await begin_attack()
	player.position.y = 2.5
	player.set_physics_process(false)
	await frames(43)
	check(player.health.current == 90, "Different floor height is outside enemy melee")
	player.set_physics_process(true)
	await begin_attack()
	var wall := box(Vector3(4, 3, 0.1), Vector3(0, 1.5, -0.7))
	await frames(43)
	check(player.health.current == 90 and enemy.melee.last_result == "miss", "Cover inserted during windup blocks strike")
	wall.queue_free()
	await frames(3)
	await begin_attack()
	player.controls_active = false
	await frames(50)
	check(player.health.current == 90 and enemy.melee.phase == "idle", "Released mouse cancels and suspends attacks")
	await begin_attack()
	player.crouch.toggled = true
	await frames(43)
	check(player.health.current == 80 and player.crouch.active, "Enemy targets actual crouched capsule centre")
	enemy.melee.enabled = false
	player.crouch.reset(player)
	await frames(3)
	# Real hinged door: close it during a windup, then open for a later attack.
	enemy.set_physics_process(false)
	var door = preload("res://scripts/door.gd").new()
	door.sync_to_physics = false
	door.player = player
	var shape := CollisionShape3D.new()
	var leaf := BoxShape3D.new()
	leaf.size = Vector3(4, 3, 0.12)
	shape.shape = leaf
	shape.position = Vector3(2, 1.5, 0)
	door.add_child(shape)
	arena.add_child(door)
	door.position = Vector3(-2, 0, -0.7)
	door.closed_basis = Basis.IDENTITY
	door.interact()
	await frames(45)
	await begin_attack()
	enemy.melee.tick(enemy, 1.0 / 60.0)
	door.interact()
	await door_frames(43)
	check(player.health.current == 80 and enemy.melee.last_result == "miss", "Closing hinged door during windup prevents damage")
	enemy.melee.enabled = false
	await frames(5)
	door.interact()
	await frames(45)
	await begin_attack()
	await door_frames(43)
	check(player.health.current == 70, "Opening hinged door permits subsequent strike")
	door.queue_free()
	enemy.set_physics_process(true)
	await frames(3)
	await begin_attack()
	enemy.receive_damage(100)
	await frames(45)
	check(player.health.current == 70 and enemy.melee.phase == "idle", "Killing windup enemy cancels its pending damage")
	player.combat.request_attack(player)
	player.climbing.active = true
	player.flight_horizontal = Vector3(3, 0, 0)
	check(player.receive_damage(1000), "Lethal player damage is accepted")
	check(player.is_dead() and not player.controls_active and not player.climbing.active and player.combat.elapsed < 0 and player.flight_horizontal == Vector3.ZERO, "Death clears attacks, climbing, controls and cached motion")
	var death_position := player.position
	Input.action_press("forward")
	Input.action_press("jump")
	await frames(30)
	release()
	check(player.position == death_position and not player.combat.request_attack(player), "Dead player cannot move, jump or attack")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	check(not player.controls_active and not player.receive_damage(10), "Dead player cannot recapture controls or take repeated damage")
	arena.queue_free()
	await frames(3)
	var level = load("res://main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(20)
	player = level.player
	var hall = level.world_root.get_node("hall_combat_target")
	check(hall.melee.enabled and not hall.approach_enabled and not level.enemy.melee.enabled, "Section enables only stationary hall retaliation")
	var section = preload("res://scripts/classic_section.gd").new()
	var invalid: Dictionary = level.classic.section.definition.duplicate(true)
	invalid.prototype.enemies[1].attack_enabled = "yes"
	check(not section.validate(invalid), "Section rejects non-boolean attack_enabled")
	player.show_movement_debug = true
	await frames(3)
	check(level.movement_status.position.y >= level.status.position.y + level.status.get_minimum_size().y + 10, "Diagnostics follow expanded status without overlap")
	player.position = hall.position + Vector3(-1.4, 0.03, 0)
	await frames(3)
	player.camera.look_at(hall.global_position + Vector3.UP * 0.4)
	await frames(15)
	await capture("res://tests/enemy_windup.png")
	await frames(27)
	await capture("res://tests/player_damage.png")
	check(player.health.current == 90, "Authored hall enemy damages player in original geometry")
	player.receive_damage(1000)
	await frames(3)
	check(level.prompt.text.contains("died") and level.player_status.text.contains("DEAD"), "Death HUD shows restart instruction and zero health")
	await capture("res://tests/player_death.png")
	var restart := InputEventKey.new()
	restart.physical_keycode = KEY_R
	restart.pressed = true
	level.presentation.viewport.push_input(restart, true)
	await frames(10)
	player = current_scene.player
	check(player.health.current == 100 and not player.is_dead() and player.controls_active and current_scene.world_root.get_node("hall_combat_target").health.current == 30, "R through gameplay viewport reloads healthy player and enemy after death")
	var file := FileAccess.open("res://tests/retaliation_results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results))
	print("RETALIATION RESULTS: ", results.size() - failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)
