extends "res://tests/climbing.gd"
var level: Node3D

func click(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	level.presentation.viewport.push_input(event, true)

func ready_key() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Z
	event.pressed = true
	level.presentation.viewport.push_input(event, true)

func hash_image(texture: Texture2D) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(texture.get_image().get_data())
	return context.finish().hex_encode()

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var active := player.is_physics_processing()
	player.set_physics_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + name + ".png")
	player.set_physics_process(active)

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(10)
	player = level.player
	player.movement.set_live_stats({"speed_attribute": 50.0})
	var hall = level.world_root.get_node("hall_combat_target")
	hall.melee.enabled = false
	var combat = player.combat
	var view = combat.weapon
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/weapons/dagger_frames.json"))
	var count := 0
	for record in 7:
		var expected: Dictionary = fixture.records[record]
		var actual: Dictionary = level.classic.dagger_frames[record]
		var valid: bool = actual.width == expected.pixels[0] and actual.height == expected.pixels[1] and actual.frames.size() == expected.rgba_sha256.size()
		for frame in actual.frames.size():
			valid = valid and hash_image(actual.frames[frame]) == expected.rgba_sha256[frame]
			count += 1
		check(valid, "Dagger CIF record %d native dimensions and all RGBA hashes match independent audit" % record)
	check(count == 31, "One ready pose and thirty directional attack frames load")
	var bytes := FileAccess.get_file_as_bytes(level.classic.arena_path.path_join("WEAPON02.CIF"))
	check(level.classic.decode_dagger_cif(bytes.slice(0, bytes.size()-100)).is_empty(), "Truncated weapon archive is rejected")
	var broken := bytes.duplicate()
	broken.encode_u16(4, 500)
	check(level.classic.decode_dagger_cif(broken).is_empty(), "Oversized CIF image is rejected")
	broken = bytes.duplicate()
	broken.encode_u16(9307 + 12, 1)
	check(level.classic.decode_dagger_cif(broken).is_empty(), "Invalid animation data offset is rejected")
	var truncated := PackedByteArray([255])
	check(level.classic.cif_rle(truncated,0,1,128).is_empty(), "Truncated RLE run is rejected")
	view.update_layout()
	check(view.visible and view.source_record == 0 and view.source_frame == 0 and view.size.distance_to(Vector2(130,286)) < 0.01, "Readied dagger uses native dimensions at 640x400")
	check(absf(view.position.x + view.size.x - 640.0*0.96) < 0.01 and absf(view.position.y + view.size.y - 400) < 0.01, "Ready pose uses DFU bottom-right alignment and four-percent inset")
	await capture("dagger_ready")
	# Controlled poses inspect all directions, independent of random attack selection.
	for record in range(1,7):
		view.set_frame(record,2,true)
		var left: bool = record in [4,5]
		check((absf(view.position.x) < 0.01 if left else absf(view.position.x + view.size.x - 640) < 0.01), "Dagger swing %d uses source alignment" % record)
		await capture("dagger_swing_%d" % record)
	combat.pose()
	var directions: Dictionary = {}
	combat.rng.seed = 42
	for i in 120:
		combat.request_attack(player)
		directions[combat.attack_record] = true
		combat.cancel()
	check(directions.size() == 6, "Random attacks exercise all six supported swing directions")
	player.position = hall.position + Vector3(-1.5,0.02,0)
	player.camera.look_at(hall.global_position + Vector3.UP)
	await frames(4)
	click(MOUSE_BUTTON_LEFT)
	check(combat.elapsed < 0, "Left-click no longer attacks")
	click(MOUSE_BUTTON_RIGHT)
	check(combat.elapsed == 0 and view.source_record in [1,2,3,4,5,6], "Right-click starts one random original attack")
	check(absf(combat.frame_seconds - 195.0/980.0) < 0.00001, "Weapon timing resolves DFU Speed-50 frame interval")
	await frames(13)
	check(hall.health.current == 30 and view.source_frame == 1, "First attack frames apply no early damage")
	await frames(13)
	check(hall.health.current == 20 and view.source_frame == 2, "Entering dagger frame two applies damage once")
	await frames(40)
	check(hall.health.current == 20 and combat.elapsed < 0 and view.source_record == 0, "Completed swing restores ready pose without repeated damage")
	click(MOUSE_BUTTON_RIGHT)
	ready_key()
	await frames(30)
	check(combat.sheathed and combat.elapsed < 0 and not view.visible and hall.health.current == 20, "Z sheath cancels pending attack and hides dagger")
	check(not combat.request_attack(player), "Sheathed weapon cannot attack")
	ready_key()
	view.update_layout()
	check(not combat.sheathed and view.visible and view.source_record == 0, "Z draws dagger in ready pose")
	player.controls_active = false
	click(MOUSE_BUTTON_RIGHT)
	check(player.controls_active and combat.elapsed < 0, "Right-click recapture resumes without attacking")
	player.climbing.active = true
	view.update_layout()
	check(not view.visible and not combat.request_attack(player), "Attached climbing hides dagger and prevents attacks")
	player.climbing.reset()
	view.update_layout()
	var ready_position: Vector2 = view.position
	player.crouch.toggled = true
	player.camera.rotation.x = -0.4
	await frames(20)
	check(view.visible and view.position == ready_position, "Crouching and camera pitch keep overlay anchored to the display")
	player.crouch.toggled = false
	await frames(20)
	player.movement.set_live_stats({"speed_attribute": 80.0})
	combat.request_attack(player)
	check(absf(combat.frame_seconds - 105.0/980.0) < 0.00001, "New attack reads live Speed independently of movement motor")
	combat.cancel()
	player.movement.set_live_stats({})
	level.presentation.set_profile("widescreen")
	await frames(2)
	view.update_layout()
	var screen: Vector2 = level.presentation.viewport.size
	check(absf(view.position.y + view.size.y - screen.y) < 0.01 and absf(view.position.x + view.size.x - screen.x*0.96) < 0.01, "Widescreen resizes overlay within active display")
	await capture("dagger_widescreen")
	level.presentation.set_profile("dfu_reference")
	await frames(2)
	player.receive_damage(1000)
	await frames(2)
	check(not view.visible and not combat.request_attack(player), "Player death hides dagger and blocks further attacks")
	var restart := InputEventKey.new()
	restart.physical_keycode = KEY_R
	restart.pressed = true
	level.presentation.viewport.push_input(restart,true)
	await frames(8)
	player = current_scene.player
	check(not player.combat.sheathed and player.combat.weapon.visible and player.combat.elapsed < 0, "Restart restores readied dagger and clears attack state")
	var file := FileAccess.open("res://tests/dagger_results.txt",FileAccess.WRITE)
	file.store_string("\n".join(results))
	print("DAGGER RESULTS: ",results.size()-failures.size(),"/",results.size())
	quit(0 if failures.is_empty() else 1)
