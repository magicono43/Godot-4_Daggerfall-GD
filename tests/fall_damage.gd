extends "res://tests/character_sheet.gd"
const Falls = preload("res://scripts/fall_damage.gd")
const ORIGIN := Vector3(100, 0, 100)
var sounds: Array[String] = []

func model_checks() -> void:
	for pair in [[0.0,0,"soft"], [2.5,0,"soft"], [2.51,0,"hard"], [5.0,0,"hard"], [5.01,0,"damage"], [5.19,0,"damage"], [5.2,1,"damage"], [6.0,5,"damage"], [12.0,35,"damage"]]:
		var result := Falls.resolve(float(pair[0]))
		check(result.damage == pair[1] and result.kind == pair[2], "Pinned threshold/truncation at %.2f metres" % pair[0])
	check(Falls.resolve(NAN).is_empty() and Falls.resolve(INF).is_empty() and Falls.resolve(-1).is_empty(), "Invalid fall distances reject")
	var model := Falls.new()
	model.begin(Vector3(0,10,0), true)
	model.finish(Vector3(0,10,0), Vector3(0,11,0), false)
	model.begin(Vector3(0,11,0), false)
	model.finish(Vector3(0,11,0), Vector3(0,14,0), false)
	model.begin(Vector3(0,14,0), false)
	var result := model.finish(Vector3(0,14,0), Vector3(0,10,0), true)
	check(result.distance == 0 and result.damage == 0, "Jump apex adds no net drop on same-level landing")
	check(model.finish(Vector3(0,10,0),Vector3(0,10,0),true).is_empty(), "Supported ticks cannot repeat landing event")
	model.begin(Vector3(0,10,0), true)
	model.finish(Vector3(0,10,0), Vector3(0,11,0), false)
	model.begin(Vector3(0,11,0), false)
	result = model.finish(Vector3(0,11,0), Vector3(0,4,0), true)
	check(result.distance == 6 and result.damage == 5, "Jump off a ledge uses departure level, not peak height")
	model.begin(Vector3(0,4,0), false)
	model.finish(Vector3(0,4,0), Vector3(0,3,0), false)
	model.begin(Vector3(0,0,0), true)
	check(not model.active and model.finish(Vector3.ZERO,Vector3.ZERO,true).is_empty(), "Out-of-motor teleport discards previous fall")
	model.begin(Vector3(0,9,0), false)
	model.suspend(Vector3(0,2,0))
	model.begin(Vector3(0,2,0), false)
	result = model.finish(Vector3(0,2,0),Vector3.ZERO,true)
	check(result.damage == 0 and result.distance == 2, "Climbing release starts a fresh fall at release height")

func place(at: Vector3, low := false) -> void:
	release()
	player.climbing.reset()
	player.falling.reset()
	player.fall_feedback_time = 0
	player.crouch.reset(player)
	if low:
		player.crouch.set_height(player, 0.9)
		player.crouch.toggled = true
		player.crouch.requested = true
		player.crouch.active = true
		player.crouch.eye_height = 0.81
	player.position = at
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.stair_supported = false
	player.grounded_time = 0
	player.step_camera_offset = 0
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.health.current = 300
	player.fatigue.current = player.fatigue.maximum()
	player.controls_active = true
	sounds.clear()

func land_on_floor(limit := 240) -> void:
	for index in limit:
		await frames(1)
		if player.is_grounded() and not player.falling.active:
			break

func climb_to(height: float) -> void:
	Input.action_press("forward")
	for index in 600:
		await frames(1)
		if player.position.y >= height:
			break
	release()
	await frames(2)

func run() -> void:
	level = load("res://tests/bear_regression.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	player = level.player
	arena = level.world_root
	window = level.loot_window
	for enemy in level.enemies:
		enemy.melee.enabled = false
		enemy.set_physics_process(false)
	level.combat_audio.played.connect(func(event, _id, _spatial):
		if event in ["fall_damage", "fall_hard", "player_hit"]:
			sounds.append(event))
	model_checks()
	check(level.combat_audio.cache.has(91) and level.combat_audio.cache.has(92), "Original ordinal landing samples91/92 decode")
	box(Vector3(90,1,90), ORIGIN + Vector3(0,-0.5,0))
	box(Vector3(8,12,2), ORIGIN + Vector3(0,6,-2))
	box(Vector3(8,8,2), ORIGIN + Vector3(20,4,-2))
	await place(ORIGIN + Vector3(10,0.02,0))
	await frames(20)
	Input.action_press("jump")
	await frames(2)
	release()
	await land_on_floor()
	check(player.health.current == 300 and sounds.is_empty(), "Normal actual jump causes no damage or hard-landing audio")
	player.movement.set_live_stats({"jumping_skill":200})
	player.movement.set_modifier("fall_test_jump", {"jump":2.0})
	await frames(8)
	Input.action_press("jump")
	await frames(2)
	release()
	await land_on_floor()
	check(player.health.current == 300 and sounds.is_empty(), "High jump on same floor remains safe without apex-based damage")
	player.movement.set_live_stats({})
	player.movement.remove_modifier("fall_test_jump")
	await place(ORIGIN + Vector3(10,3.2,0))
	await land_on_floor()
	check(player.health.current == 300 and sounds == ["fall_hard"] and player.fall_feedback.contains("Hard landing"), "3.2m actual fall gives one original hard-landing cue without damage")
	await frames(12)
	check(sounds == ["fall_hard"], "Grounded frames cannot repeat hard-landing sound")
	await place(ORIGIN + Vector3(10,8.2,0))
	await land_on_floor()
	var result: Dictionary = player.falling.last_landing
	check(result.distance > 8.1 and result.distance < 8.3 and result.damage == int((result.distance-5.0)*5.0) and player.health.current == 300 - int(result.damage), "Actual 8.2m drop uses measured feet distance and pinned formula")
	check(sounds == ["fall_damage"] and player.damage_flash > 0 and player.fall_feedback.contains("fall damage"), "Damaging fall gives one original cue, health flash and explicit feedback")
	var health: int = player.health.current
	await frames(8)
	check(player.health.current == health and sounds == ["fall_damage"], "Landing damage applies only once")
	await place(ORIGIN + Vector3(10,8.2,0), true)
	await land_on_floor()
	check(player.health.current == health and player.crouch.is_low(player), "Crouched fall uses same feet displacement, with posture retained")
	await place(ORIGIN + Vector3(10,8.2,0))
	await frames(10)
	var frozen_y: float = player.position.y
	var frozen_departure: float = player.falling.departure_height
	await routed(KEY_C)
	await frames(30)
	check(player.position.y == frozen_y and player.falling.active and player.falling.departure_height == frozen_departure, "Airborne modal pauses and preserves pending fall")
	await routed(KEY_C)
	await land_on_floor()
	check(player.health.current == health and sounds == ["fall_damage"], "Closing modal resumes the same once-only fall damage")
	await place(ORIGIN + Vector3(10,8.2,0))
	await frames(10)
	player.position = ORIGIN + Vector3(10,0.02,0)
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.stair_supported = false
	await frames(10)
	check(player.health.current == 300 and sounds.is_empty(), "Teleport while airborne cannot retain damage from prior height")
	await place(ORIGIN + Vector3(0,0.02,0))
	await frames(20)
	await climb_to(8.0)
	check(player.climbing.active and not player.falling.active and player.health.current == 300, "Real climb owns vertical motion without accumulating fall distance")
	Input.action_press("back")
	await frames(360)
	release()
	await frames(20)
	check(not player.climbing.active and player.is_grounded() and player.health.current == 300 and sounds.is_empty(), "Controlled eight-metre wall descent lands safely")
	await place(ORIGIN + Vector3(0,0.02,0))
	await frames(20)
	await climb_to(8.0)
	Input.action_press("jump")
	await frames(2)
	release()
	await land_on_floor()
	check(player.health.current < 300 and sounds == ["fall_damage"] and player.falling.last_landing.distance > 7.5, "Climbing ejection measures real free fall after release")
	await place(ORIGIN + Vector3(20,8.02,-1.4))
	await frames(20)
	Input.action_press("back")
	await frames(45)
	release()
	check(player.climbing.active and player.position.y < ORIGIN.y+7.8 and not player.falling.active, "Backward ledge entry hands off to climbing without fall damage")
	Input.action_press("back")
	await frames(360)
	release()
	await frames(20)
	check(player.is_grounded() and player.health.current == 300 and sounds.is_empty(), "Backward-entry descent remains safe through ground handover")
	await place(ORIGIN + Vector3(20,8.02,-2))
	await frames(20)
	Input.action_press("forward")
	await frames(100)
	release()
	await land_on_floor()
	var walk_off_damage: int = 300 - player.health.current
	check(walk_off_damage >= 14 and walk_off_damage <= 15 and sounds == ["fall_damage"] and not player.climbing.active, "Continuous forward walk off eight-metre platform causes one real fall")
	await place(ORIGIN + Vector3(20,8.02,-2))
	player.movement.set_live_stats({"jumping_skill":200})
	await frames(20)
	Input.action_press("forward")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await land_on_floor()
	release()
	check(abs(300 - player.health.current - walk_off_damage) <= 1 and player.falling.last_landing.distance < 8.1 and sounds == ["fall_damage"], "High-skill jump off platform uses the same net drop as walking off")
	player.movement.set_live_stats({})
	await place(ORIGIN + Vector3(10,8.2,0))
	await frames(10)
	player.controls_active = false
	await land_on_floor()
	check(player.health.current == health and sounds == ["fall_damage"], "Released mouse does not erase a fall while gravity continues")
	await place(ORIGIN + Vector3(10,-9.5,0))
	await frames(60)
	check(player.health.current == 300 and not player.falling.active and player.position.distance_to(player.spawn) < 0.2, "Existing below-world reset clears fall history without phantom damage")
	# Real hall drop gives readable feedback over normal gameplay in both views.
	await place(player.spawn + Vector3.UP * 8.2)
	await land_on_floor()
	player.look_at(player.position + Vector3(8,0,4))
	player.show_movement_debug = true
	check(player.health.current < 300 and sounds == ["fall_damage"], "Fall damage also works against original hall floor geometry")
	await capture("fall_damage_4_3")
	level.presentation.set_profile("widescreen")
	await frames(2)
	await capture("fall_damage_widescreen")
	player.controls_active = false
	level.persistence.slot_path = "res://tests/fall_damage_slot.json"
	var saved_health: int = player.health.current
	check(level.persistence.save_slot(), "Damaged settled player can save using the current save schema")
	player.controls_active = true
	player.position.y += 8
	player.stair_supported = false
	await frames(8)
	await routed(KEY_C)
	await routed(KEY_L)
	level = current_scene
	player = level.player
	check(player.health.current == saved_health and not player.falling.active and player.fall_feedback_time == 0, "L clears pending fall and feedback while restoring saved health")
	level.combat_audio.played.connect(func(event, _id, _spatial):
		if event in ["fall_damage", "fall_hard", "player_hit"]:
			sounds.append(event))
	await place(player.spawn + Vector3.UP * 8.2)
	player.health.current = 1
	await land_on_floor()
	check(player.is_dead() and not player.falling.active and not player.controls_active and player.combat.elapsed < 0 and sounds == ["fall_damage"], "Fatal landing uses normal death cleanup once")
	await routed(KEY_R)
	level = current_scene
	player = level.player
	await frames(20)
	check(player.health.current == 300 and not player.falling.active and player.fall_feedback_time == 0, "R restores accepted bear baseline with clean fall state")
	print("FALL DAMAGE RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	FileAccess.open("res://tests/fall_damage_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)
