extends "res://tests/magic.gd"
const TELEPORT_PATH := "res://tests/teleport_slot.json"
var teleport_sounds: Array[String] = []

func cast_teleport() -> void:
	player.casting.cancel()
	player.magic.current = 150
	player.magic.select("teleport")
	player.controls_active = true
	await routed(KEY_Q)

func finish_teleport() -> void:
	print("TELEPORT RESULTS: %d/%d" % [results.size()-failures.size(),results.size()])
	var report := "res://tests/teleport_cross_process_results.txt" if "--teleport-read" in OS.get_cmdline_user_args() else "res://tests/teleport_results.txt"
	FileAccess.open(report,FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	bind_magic()
	level.persistence.slot_path = TELEPORT_PATH
	if "--teleport-read" in OS.get_cmdline_user_args():
		check(await level.persistence.load_slot(), "Separate process restores Teleport anchor")
		bind_magic()
		player.set_physics_process(false)
		level.persistence.slot_path = TELEPORT_PATH
		var disk: Dictionary = level.persistence.read_slot()
		check(JSON.stringify(player.teleport.snapshot(),"",true) == JSON.stringify(disk.player.anchor,"",true) and player.character.stat("mysticism") == 65, "Cross-process anchor position/context/posture/orientation and Mysticism persist")
		var destination: Vector3 = Vector3(disk.player.anchor.position[0],disk.player.anchor.position[1],disk.player.anchor.position[2])
		check(player.teleport.arrive(player).is_empty() and player.position.distance_to(destination) < 0.03 and player.teleport.anchor.is_empty(), "Restored anchor teleports once then is consumed")
		finish_teleport()
		return
	player.set_physics_process(false)
	arena = level.world_root
	var prompt: Control = level.teleport_window
	level.combat_audio.played.connect(func(event,_id,_spatial):teleport_sounds.append(event))
	check(player.magic.known.size() == 7 and player.magic.known.has("teleport") and player.character.stat("mysticism") == 50, "Authored seventh spell and shared Mysticism50 available")
	check(Catalog.cost("teleport",player.character) == 48, "Source zero-component cost320 yields48 at Mysticism50")
	player.character.set_live({"mysticism":100})
	check(Catalog.cost("teleport",player.character) == 8 and player.reload_movement() and player.character.stat("mysticism") == 100, "Live Mysticism reaches cost and survives atomic F3")
	player.character.set_live({})
	check(player.health.maximum == 300 and player.magic.maximum() == 150 and player.inventory.items.size() == 13, "Teleport preserves accepted test resources/equipment")
	await cast_teleport()
	check(prompt.visible and prompt.choosing and level.modal.active == prompt and player.modal_open and not player.controls_active, "Q opens paid Anchor/Teleport choice through shared modal")
	check(player.magic.current == 102 and player.magic.last_cast == "teleport" and teleport_sounds == ["cast_magic"], "Opening choice spends48 once, remembers cast and emits correct magic cue")
	check(not player.casting.active() and not level.persistence.refusal().is_empty(), "Choice cancels pending simulation and prevents saving")
	var clock: float = player.fatigue.game_seconds
	player.tick_fatigue(10,"normal")
	check(player.fatigue.game_seconds == clock, "Choice pauses awake simulation/clock")
	await capture("teleport_choice_4_3")
	level.presentation.set_profile("widescreen")
	await frames(2)
	await capture("teleport_choice_widescreen")
	await mouse_click(prompt.teleport_button.get_global_rect().get_center())
	check(prompt.visible and not prompt.choosing and prompt.details.text == "There is no existing anchor" and player.magic.current == 102, "Teleport without anchor shows exact message and keeps spent mana")
	prompt.teleport()
	check(player.magic.current == 102 and player.teleport.anchor.is_empty(), "Repeated result action cannot cast or spend twice")
	await routed(KEY_ESCAPE)
	check(not player.modal_open and player.controls_active and player.combat.elapsed < 0, "Result close restores capture without weapon attack")
	await cast_teleport()
	var first_position: Vector3 = player.position
	player.rotation.y = 0.6
	player.camera.rotation.x = -0.2
	await mouse_click(prompt.anchor_button.get_global_rect().get_center())
	check(not player.teleport.anchor.is_empty() and player.teleport.anchor.section == level.section_path and player.position == first_position, "Anchor stores current section/feet position without moving")
	var first_anchor: Dictionary = player.teleport.snapshot()
	player.position += Vector3(0.2,0,0)
	await cast_teleport()
	prompt.choose_anchor()
	check(player.teleport.anchor.position[0] != first_anchor.position[0] and player.teleport.anchor.size() == 5, "New Anchor replaces previous record rather than adding another")
	var destination: Vector3 = player.position
	player.position += Vector3(0.3,0,0)
	player.rotation.y = -0.4
	player.camera.rotation.x = 0.3
	player.velocity = Vector3(2,-4,3)
	player.flight_horizontal = Vector3(2,0,3)
	player.input_axes = Vector2.ONE
	player.step_camera_offset = -0.4
	player.falling.begin(player.position,false)
	await cast_teleport()
	await mouse_click(prompt.teleport_button.get_global_rect().get_center())
	check(not player.modal_open and player.position.distance_to(destination) < 0.03 and player.teleport.anchor.is_empty(), "Teleport arrives at latest anchor and consumes it only after success")
	check(is_equal_approx(player.rotation.y,0.6) and is_equal_approx(player.camera.rotation.x,-0.2), "Arrival restores anchored yaw/pitch")
	check(player.velocity == Vector3.ZERO and player.flight_horizontal == Vector3.ZERO and player.input_axes == Vector2.ZERO and player.step_camera_offset == 0 and not player.falling.active, "Arrival clears cached momentum/stair camera/fall history")
	check(player.controls_active and player.combat.elapsed < 0 and not player.casting.owns_weapon(), "Successful arrival restores capture with no stale attacks/casts")
	await cast_teleport()
	prompt.teleport()
	check(prompt.details.text == "There is no existing anchor", "Used anchor cannot be reused on next paid cast")
	prompt.close()
	await cast_teleport()
	await routed(KEY_ESCAPE)
	check(player.magic.current == 102 and player.teleport.anchor.is_empty(), "Cancelling choice spends mana without setting an anchor")
	# Book activation and modal switching must not leave a paid action runnable.
	player.magic.current = 150
	await routed(KEY_B)
	await double_click_spell(6)
	check(prompt.visible and not level.spellbook.visible and player.magic.current == 102 and level.modal.previous_capture, "Book double-click transitions directly to paid choice without click-through")
	await routed(KEY_I)
	prompt.choose_anchor()
	check(window.visible and not prompt.visible and player.teleport.anchor.is_empty(), "Switching to inventory cancels choice and stale Anchor callback")
	window.close()
	player.controls_active = false
	player.magic.current = 150
	await routed(KEY_B)
	await double_click_spell(6)
	check(prompt.visible and not level.modal.previous_capture, "Released mouse preference survives book-to-choice transition")
	prompt.choose_anchor()
	check(not player.controls_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Anchor closes without forcing previously released capture")
	player.teleport.anchor.clear()
	player.controls_active = true
	player.magic.current = 0
	check(not player.casting.request(player) and not prompt.visible and player.teleport.anchor.is_empty(), "Insufficient magicka opens no choice or anchor")
	# Crouched and airborne anchors are legitimate; clearance uses stored posture.
	var origin: Vector3 = player.position
	player.crouch.set_height(player,player.crouch.HEIGHT)
	player.crouch.toggled = true
	player.crouch.requested = true
	player.crouch.active = true
	player.crouch.eye_height = player.crouch.EYE
	player.teleport.set_anchor(player)
	player.position += Vector3(0.3,0,0)
	player.crouch.reset(player)
	check(player.teleport.arrive(player).is_empty() and player.crouch.is_low(player) and player.crouch.toggled and is_equal_approx(player.camera.position.y,player.crouch.EYE), "Crouched anchor restores feet-anchored posture and eye without standing expansion")
	player.crouch.reset(player)
	player.position = origin+Vector3.UP*3
	player.teleport.set_anchor(player)
	player.position = origin
	player.climbing.active = true
	check(player.teleport.arrive(player).is_empty() and not player.climbing.active and player.position.y > origin.y+2.9 and not player.falling.active, "Airborne anchor is allowed; arrival clears climbing and starts fresh fall tracking")
	player.position = origin
	# An occupied destination must fail without consuming the only anchor.
	player.teleport.set_anchor(player)
	var saved_anchor: Dictionary = player.teleport.snapshot()
	var blocker := box(Vector3(1,2,1),origin+Vector3.UP)
	player.position += Vector3(2,0,0)
	await frames(2)
	await cast_teleport()
	prompt.teleport()
	check(prompt.details.text == "The anchor is blocked." and player.teleport.snapshot() == saved_anchor and player.magic.current == 102, "Blocked destination retains anchor but paid cast still costs mana")
	prompt.close()
	blocker.queue_free()
	await frames(2)
	await cast_teleport()
	prompt.teleport()
	check(player.teleport.anchor.is_empty() and player.position.distance_to(origin) < 0.03, "Unblocked retry can arrive and consume preserved anchor")
	# Save anchor independently of current player location; no prompt survives load.
	player.teleport.set_anchor(player)
	var base: Dictionary = player.character.base.duplicate()
	base.mysticism = 65
	player.character.set_base(base)
	var data: Dictionary = level.persistence.snapshot()
	check(data.version == 9 and level.persistence.validate(data), "Schema9 validates persistent anchor and shared Mysticism")
	for kind in ["missing","context","position","nan","pitch","posture","extra","old"]:
		var bad := data.duplicate(true)
		match kind:
			"missing":bad.player.erase("anchor")
			"context":bad.player.anchor.section = "other_section"
			"position":bad.player.anchor.position = [1,2]
			"nan":bad.player.anchor.position[0] = NAN
			"pitch":bad.player.anchor.pitch = 5
			"posture":bad.player.anchor.crouched = 1
			"extra":bad.player.anchor.foo = 1
			"old":bad.version = 8
		check(not level.persistence.validate(bad), "Malformed anchor save rejects: "+kind)
	check(level.persistence.write_slot(data), "Writes isolated Teleport slot without overwriting manual")
	await cast_teleport()
	await routed(KEY_L)
	bind_magic()
	player.set_physics_process(false)
	level.persistence.slot_path = TELEPORT_PATH
	prompt = level.teleport_window
	check(not prompt.visible and not player.modal_open and not player.teleport.anchor.is_empty() and player.character.stat("mysticism") == 65, "L from choice restores anchor and closes paid action without replay")
	prompt.teleport()
	check(not player.teleport.anchor.is_empty(), "Stale post-load choice action cannot consume restored anchor")
	await cast_teleport()
	player.receive_damage(10000)
	check(player.is_dead() and not prompt.visible and not prompt.choosing, "Death closes paid choice and cannot execute delayed teleport")
	await routed(KEY_L)
	bind_magic()
	check(not player.is_dead() and not player.teleport.anchor.is_empty() and player.controls_active, "L after death restores persisted anchor and controls")
	await routed(KEY_R)
	bind_magic()
	check(player.teleport.anchor.is_empty() and player.magic.known.has("teleport") and player.magic.current == 150, "R clears anchor while preserving authored spell knowledge")
	finish_teleport()
