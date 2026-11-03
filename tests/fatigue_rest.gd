extends "res://tests/character_sheet.gd"
const Fatigue = preload("res://scripts/fatigue_model.gd")
const Character = preload("res://scripts/character_state.gd")

func model_checks() -> void:
	var state := Character.new()
	var model := Fatigue.new()
	model.setup(state)
	check(model.maximum() == 6400 and model.current == 6400, "STR50 END50 gives 100 displayed /6400 raw fatigue")
	model.tick(4.0, "normal")
	check(model.current == 6400 and model.game_seconds == 48.0, "12x clock retains sub-minute time")
	model.tick(1.0, "normal")
	check(model.current == 6389, "One game minute costs11 raw while standing/walking")
	model.tick(5.0, "running")
	check(model.current == 6301, "Running minute costs88 raw")
	model.tick(5.0, "climbing")
	check(model.current == 6279, "Climbing minute costs22 raw")
	model.jump()
	check(model.current == 6268, "Jump costs11 raw exactly once per accepted jump")
	model.tick(5.0, "running", true, true)
	check(model.current == 6198, "Improved athleticism truncates running cost to70 raw")
	model.jump(true, false)
	check(model.current == 6189, "Athleticism truncates jump cost to9 raw")
	var before := model.snapshot()
	model.tick(NAN, "normal")
	model.tick(-5, "normal")
	check(model.snapshot() == before, "Invalid elapsed time cannot change model state")
	state.set_live({"endurance":60})
	check(model.maximum() == 7040 and model.current == 6189, "Increased live capacity does not create fatigue")
	state.set_live({"endurance":20})
	model.sync_capacity()
	check(model.current == 4480, "Reduced live capacity clamps current fatigue")
	state.set_live({})
	check(model.fatigue_recovery() == 800 and model.health_recovery(300) == 25, "Pinned base recovery gives12.5 fatigue and25 health per hour")
	state.set_live({"endurance":80, "medical":100})
	check(model.health_recovery(300) == 51, "Live Medical and Endurance reach source healing formula")
	state.set_live({})
	var health := preload("res://scripts/health.gd").new()
	health.maximum = 300
	health.current = 290
	model.current = 6399
	var old_seconds := model.game_seconds
	model.rest_hour(health)
	check(health.current == 300 and model.current == 6400 and model.game_seconds == old_seconds + 3600, "Rest hour clamps both pools and advances one game hour")
	health.current = 0
	model.current = 1
	model.rest_hour(health)
	check(health.current == 0 and model.current == 1, "Rest cannot revive the dead")
	model.spend(999999)
	check(model.current == 0 and model.exhausted(), "Fatigue depletion clamps without negative values")
	check(not model.valid({"current":1.5, "game_seconds":0}) and not model.valid({"current":-1, "game_seconds":0}), "Saved fatigue requires bounded whole raw units")
	check(not model.valid({"current":12801, "game_seconds":0}) and not model.valid({"current":1, "game_seconds":INF}), "Oversized pool or nonfinite clock rejects")
	check(not model.valid({"current":1, "game_seconds":-1}) and not model.valid({"current":1, "game_seconds":0, "extra":1}), "Negative clock and unknown fatigue fields reject")

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	player = level.player
	arena = level.world_root
	window = level.loot_window
	hall = level.enemies[1]
	player.controls_active = false
	model_checks()
	var panel: Control = level.rest_window
	check(player.health.maximum == 300 and hall.creature_name == "Bear" and player.character.stat("medical") == 25, "Accepted bear and300HP baseline adds Medical25")
	player.fatigue.current = 0
	player.controls_active = true
	check(not player.combat.request_attack(player) and player.combat.elapsed < 0, "Exhaustion denies attack before animation or RNG")
	player.fatigue.current = 6400
	check(player.combat.request_attack(player) and player.fatigue.current == 6389, "Accepted click swing costs11 raw")
	check(not player.combat.request_attack(player) and player.fatigue.current == 6389, "Rejected repeated swing does not cost fatigue")
	await routed(KEY_T)
	check(panel.visible and player.modal_open and player.combat.elapsed < 0 and level.modal.previous_capture, "T opens modal and cancels pending strike with capture preserved")
	check(panel.rest.refusal().contains("Enemies") and panel.timed_button.disabled, "Living nearby bear prevents rest")
	panel.start_rest(false)
	check(not panel.rest.active and panel.timed_button.disabled, "Unsafe rest cannot start through callback or enable buttons")
	await capture("rest_blocked")
	hall.receive_damage(999)
	player.health.current = 200
	player.fatigue.current = 3200
	panel.refresh()
	check(panel.rest.refusal().is_empty(), "Dead bear and passive chamber do not prevent rest")
	var seconds: float = player.fatigue.game_seconds
	await frames(10)
	check(player.fatigue.current == 3200 and player.fatigue.game_seconds == seconds, "Open selection UI neither drains nor recovers fatigue/time")
	panel.hours.value = 1
	await mouse_click(panel.timed_button.global_position + panel.timed_button.size / 2)
	check(panel.rest.active, "Mouse button begins selected-hour rest")
	await frames(50)
	check(not panel.rest.active and panel.rest.hours_completed == 1 and player.fatigue.current == 4000 and player.health.current == 225, "Completed timed hour restores source amounts once")
	check(player.fatigue.game_seconds == seconds + 3600, "Rest advances game clock without awake drain")
	await capture("rest_recovered_4_3")
	level.presentation.set_profile("widescreen")
	await frames(2)
	await capture("rest_recovered_widescreen")
	panel.start_rest(false)
	await frames(10)
	var current: int = player.fatigue.current
	await routed(KEY_ESCAPE)
	check(not panel.visible and not panel.rest.active and not player.modal_open and player.controls_active and player.fatigue.current == current, "Escape cancels partial hour without recovery and resumes capture")
	player.controls_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await routed(KEY_T)
	panel.start_rest(false)
	await routed(KEY_C)
	check(level.character_sheet.visible and not panel.visible and not panel.rest.active and player.modal_open, "C switches rest to sheet and stops rest")
	check(level.character_sheet.details.text.contains("Medical: 25") and level.character_sheet.details.text.contains("Fatigue:"), "Sheet exposes real Medical and fatigue")
	await routed(KEY_T)
	await routed(KEY_I)
	check(window.visible and not panel.visible and not panel.rest.active, "I switches rest to inventory with one modal")
	await routed(KEY_T)
	await routed(KEY_T)
	check(not player.modal_open and not player.controls_active, "Released capture preference survives all rest transitions")
	panel.open()
	panel.set_process(false) # Deterministic hour-boundary/interrupt tests.
	var home: Vector3 = player.position
	player.position.y += 5
	check(not panel.rest.start(1), "Stale floor flag cannot authorize unsupported rest")
	player.position = home
	player.climbing.active = true
	check(not panel.rest.start(1), "Climbing refuses rest")
	player.climbing.reset()
	player.velocity.x = 1
	check(not panel.rest.start(1), "Moving entry refuses rest")
	player.velocity = Vector3.ZERO
	check(not panel.rest.start(0) and not panel.rest.start(25), "Rest duration bounds reject")
	check(panel.rest.start(1), "Safe rest starts after posture/ground checks")
	var chamber: CharacterBody3D = level.enemies[0]
	var chamber_home: Vector3 = chamber.position
	chamber.position = player.position + Vector3(2, 0, 0)
	chamber.melee.enabled = true
	current = player.fatigue.current
	panel.rest.tick(1)
	check(not panel.rest.active and player.fatigue.current == current, "New nearby threat interrupts before an hour is awarded")
	chamber.position = chamber_home
	chamber.melee.enabled = false
	# Independent sight/proximity fixture, outside the compact dungeon.
	var platform := box(Vector3(36, 1, 36), Vector3(100, -0.5, 100))
	platform.set_meta("section_role", "geometry")
	player.position = Vector3(100, 0.001, 100)
	player.stair_supported = true
	chamber.position = Vector3(100, 0, 113)
	chamber.melee.enabled = true
	await frames(2)
	check(panel.rest.nearby_threat(), "Visible hostile beyond12m still prevents rest")
	var barrier := box(Vector3(4, 4, 0.3), Vector3(100, 1, 106))
	await frames(2)
	check(not panel.rest.nearby_threat(), "Occluded hostile beyond12m does not prevent rest")
	chamber.position.z = 108
	check(panel.rest.nearby_threat(), "Nearby hostile behind a wall still prevents rest")
	chamber.position = chamber_home
	chamber.melee.enabled = false
	player.position = home
	platform.queue_free()
	barrier.queue_free()
	await frames(2)
	panel.rest.start(1)
	player.health.apply_damage(1)
	panel.rest.tick(1)
	check(not panel.rest.active and panel.rest.message.contains("damage") and player.fatigue.current == current, "Damage interrupts rest before recovery")
	player.health.current = 200
	player.fatigue.current = 0
	check(panel.rest.start(24, true), "Exhausted player may start safe full rest")
	panel.rest.tick(6.0)
	check(panel.rest.hours_completed == 8 and panel.rest.recovered() and not panel.rest.active, "Full rest stops after eight hours when both pools recover")
	player.character.set_live({"endurance":0, "medical":0})
	player.health.maximum = 100
	player.health.current = 1
	panel.rest.start(24, true)
	panel.rest.tick(18.0)
	check(panel.rest.hours_completed == 24 and not panel.rest.active and not panel.rest.recovered() and panel.rest.message.contains("limit"), "Full rest is bounded to24 hours when healing is slow")
	player.character.set_live({})
	player.health.maximum = 300
	player.health.current = 300
	panel.close()
	player.fatigue.current = 1234
	player.fatigue.game_seconds = 123.5
	var data: Dictionary = level.persistence.snapshot()
	check(data.version == 9 and data.player.fatigue.current == 1234 and level.persistence.validate(data), "Schema9 saves fatigue and fractional game clock")
	for bad in [{"current":-1,"game_seconds":0}, {"current":1,"game_seconds":NAN}, {"current":1.2,"game_seconds":0}]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.player.fatigue = bad
		check(not level.persistence.validate(invalid), "Malformed fatigue cannot replace scene")
	var old: Dictionary = data.duplicate(true)
	old.version = 3
	check(not level.persistence.validate(old), "Old schema3 rejects explicitly")
	level.persistence.slot_path = "res://tests/fatigue_rest_slot.json"
	check(level.persistence.write_slot(data), "Fatigue test uses isolated save path")
	player.controls_active = true
	panel.open()
	panel.start_rest(false)
	await routed(KEY_L)
	level = current_scene
	player = level.player
	panel = level.rest_window
	check(player.fatigue.current == 1234 and player.fatigue.game_seconds >= 123.5 and player.fatigue.game_seconds < 126, "L from rest restores fatigue and fractional clock")
	check(not panel.visible and not panel.rest.active and not player.modal_open and player.controls_active, "Loaded candidate has no active rest and resumes prior capture")
	panel.open()
	player.health.apply_damage(999)
	check(not panel.visible and not panel.rest.active and not player.controls_active, "Death dismisses rest without restoring controls")
	await routed(KEY_R)
	level = current_scene
	player = level.player
	check(player.health.current == 300 and player.fatigue.current == 6400 and not level.rest_window.rest.active, "R restores fresh accepted bear playtest and full fatigue")
	# Actual motor hooks: zero-fatigue retreat keeps walk; jump cannot double-charge.
	for enemy in level.enemies:
		enemy.melee.enabled = false
		enemy.navigation.enabled = false
	player.fatigue.current = 0
	Input.action_press("sprint")
	Input.action_press("jump")
	Input.action_press("forward")
	var start: Vector3 = player.position
	await frames(10)
	check(not player.is_running and player.position.distance_to(start) > 0.1 and player.position.y < start.y + 0.15, "Exhaustion leaves walking retreat available but blocks running/jumping")
	release()
	player.fatigue.current = 6400
	await frames(20)
	player.fatigue.game_seconds = 0
	Input.action_press("jump")
	await frames(2)
	release()
	check(player.fatigue.current == 6389 and not player.is_grounded(), "Real jump launch charges once")
	await frames(8)
	check(player.fatigue.current == 6389, "Airborne frames do not repeat jump cost")
	print("FATIGUE REST RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	FileAccess.open("res://tests/fatigue_rest_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)
