extends "res://tests/climbing.gd"
var hall: CharacterBody3D
var level: Node3D

func digest(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Capturing must not advance the attack clock differently from headless tests.
	var player_ticks := player.is_physics_processing()
	var enemy_ticks := hall.is_physics_processing()
	player.set_physics_process(false)
	hall.set_physics_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	player.set_physics_process(player_ticks)
	hall.set_physics_process(enemy_ticks)

func run() -> void:
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(20)
	player = level.player
	hall = level.world_root.get_node("hall_combat_target")
	check(hall.mobile != null and level.enemy.mobile == null, "Only hall target selects authored Skeleton visual")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/enemies/skeleton_frames.json"))
	var decoded := 0
	for key in fixture:
		var expected: Dictionary = fixture[key]
		var pieces: PackedStringArray = key.split(":")
		var archive := int(pieces[0])
		var record := int(pieces[1])
		var info: Dictionary = level.classic.texture_info(archive, record)
		var valid: bool = info.frames == expected.frames and info.width == expected.pixels[0] and info.height == expected.pixels[1]
		valid = valid and info.size_metres.distance_to(Vector2(expected.metres[0], expected.metres[1])) < 0.00001
		for frame in int(info.frames):
			var image: Image = level.classic.read_texture(archive, record, frame, true)
			valid = valid and image != null and digest(image) == expected.rgba_sha256[frame]
			decoded += 1
		check(valid, "Original Skeleton %s dimensions and RGBA hashes match independent audit" % key)
	check(decoded == 61, "All sixty-one live/corpse frames decode")
	check(absf(hall.get_child(0).shape.height - 2.0) < 0.001, "Skeleton collision follows original two-metre idle height")
	var section = preload("res://scripts/classic_section.gd").new()
	var invalid: Dictionary = level.classic.section.definition.duplicate(true)
	invalid.prototype.enemies[1].visual = "not_an_enemy"
	check(not section.validate(invalid), "Unknown enemy visual is rejected before scene build")
	hall.set_physics_process(false)
	hall.rotation = Vector3.ZERO
	var mapping := [15, 16, 17, 18, 19, 18, 17, 16]
	for view in 8:
		var angle: float = -view * PI / 4.0
		var offset := Vector3(sin(angle), 0, -cos(angle)) * 3.0
		hall.mobile.select_view(hall.global_position + offset)
		check(hall.mobile.source_record == mapping[view] and hall.mobile.flip_h == (view > 4), "Eight-way orientation %d selects expected record/mirror" % view)
	player.set_physics_process(false)
	for view in [0, 2, 4, 6]:
		var angle: float = -view * PI / 4.0
		player.position = hall.position + Vector3(sin(angle) * 3, 0, -cos(angle) * 3)
		player.camera.look_at(hall.global_position + Vector3.UP)
		await capture("res://tests/skeleton_view_%d.png" % view)
	player.set_physics_process(true)
	hall.set_physics_process(true)
	player.position = hall.position + Vector3(0, 0.03, -1.4)
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.camera.look_at(hall.global_position + Vector3.UP)
	await frames(4)
	check(hall.mobile.state == "attack" and hall.melee.phase == "windup", "Melee starts original attack animation")
	await frames(18)
	check(player.health.current == 100 and hall.mobile.source_frame <= 3, "No damage during original pre-strike frames")
	await capture("res://tests/skeleton_attack.png")
	await frames(8)
	check(player.health.current == 90 and hall.mobile.source_frame == 4 and hall.melee.phase == "recovery", "Entering animation frame four applies damage exactly once")
	await frames(14)
	check(player.health.current == 90 and hall.mobile.state == "idle", "Attack tail finishes without repeated damage")
	# Nonlethal hits use the original hurt pose and interrupt an upcoming strike.
	hall.melee.cancel()
	hall.mobile.set_state("idle")
	await frames(2)
	check(hall.mobile.state == "attack", "Enemy can start next attack cycle")
	hall.receive_damage(10)
	check(hall.mobile.state == "hurt" and hall.melee.phase == "idle", "Nonlethal hit interrupts attack with original hurt pose")
	await capture("res://tests/skeleton_hurt.png")
	await frames(14)
	check(player.health.current == 90 and hall.mobile.state == "hurt", "Hurt pose suppresses pending strike")
	await frames(4)
	check(hall.mobile.state == "attack", "Completed hurt pose permits a fresh windup")
	player.position += Vector3(0, 0, -3)
	await frames(25)
	check(player.health.current == 90 and hall.melee.last_result == "miss", "Animation event still checks live range")
	player.position = hall.position + Vector3(0, 0.03, -1.4)
	player.camera.look_at(hall.global_position + Vector3.UP)
	hall.melee.cancel()
	hall.mobile.set_state("idle")
	await frames(4)
	arena = level.world_root
	var cover := box(Vector3(2, 2.5, 0.1), hall.position + Vector3(0, 1.25, -0.7))
	await frames(26)
	check(player.health.current == 90 and hall.melee.last_result == "miss", "Skeleton animation strike respects intervening cover")
	cover.queue_free()
	await frames(3)
	hall.melee.cancel()
	hall.mobile.set_state("idle")
	await frames(4)
	player.controls_active = false
	await frames(26)
	check(hall.mobile.state == "idle" and hall.melee.phase == "idle" and player.health.current == 90, "Releasing mouse cancels Skeleton animation strike")
	player.controls_active = true
	hall.melee.cancel()
	hall.mobile.set_state("idle")
	await frames(2)
	hall.receive_damage(100)
	check(hall.visible and hall.mobile.state == "corpse" and hall.collision_layer == 0 and hall.collision_mask == 0, "Skeleton death leaves visible nonblocking original corpse")
	check(hall.mobile.texture == hall.sprite_payload.corpse.frames[0] and absf(hall.mobile.position.y - hall.sprite_payload.corpse.size_metres.y / 2.0) < 0.001, "Corpse uses archive 306 record one and keeps feet on floor")
	await frames(45)
	check(player.health.current == 90 and hall.mobile.state == "corpse" and not hall.receive_damage(10), "Corpse stays inert and cancels death-time attack")
	player.position = hall.position + Vector3(0, 0.03, -3)
	player.camera.look_at(hall.global_position + Vector3.UP * 0.25)
	await capture("res://tests/skeleton_corpse.png")
	# Exercise actual R restart, rather than mutating the old corpse back to life.
	var restart := InputEventKey.new()
	restart.physical_keycode = KEY_R
	restart.pressed = true
	level.presentation.viewport.push_input(restart, true)
	await frames(10)
	level = current_scene
	player = level.player
	hall = level.world_root.get_node("hall_combat_target")
	check(hall.health.current == 30 and hall.mobile.state == "idle" and hall.collision_layer == 1 and player.health.current == 100, "Restart restores living Skeleton and player")
	var file := FileAccess.open("res://tests/skeleton_results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results))
	print("SKELETON RESULTS: ", results.size() - failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)
