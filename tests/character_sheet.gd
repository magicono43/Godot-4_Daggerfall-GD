extends "res://tests/inventory.gd"

func routed(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await frames(2)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	root.push_input(event)
	await frames(1)

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	player = level.player
	window = level.loot_window
	hall = level.enemies[1]
	hall.melee.enabled = false
	var sheet: Control = level.character_sheet
	check(player.character.stat("speed") == 50 and player.character.stat("short_blade") == 50 and player.character.stat("running") == 25, "Shared baseline retains accepted stats")
	var before: Dictionary = player.character.base.duplicate()
	check(not player.character.set_base({"speed":80}) and player.character.base == before, "Incomplete base rejects atomically")
	check(not player.character.set_live({"strength":50.5}) and not player.character.set_live({"speed":INF}), "Invalid shared live values reject")
	var old_walk: float = player.movement.resolve().walk_speed
	player.character.set_live({"speed":70, "strength":60})
	check(player.movement.stat("speed_attribute") == 70 and player.combat_stats.stat("strength") == 60 and player.movement.resolve().walk_speed > old_walk, "Shared live API reaches both consumers")
	player.movement.set_live_stats({"speed_attribute":80})
	check(player.character.stat("speed") == 80 and player.character.stat("strength") == 60, "Movement adapter preserves combat override")
	player.combat_stats.set_live_stats({"agility":65})
	check(player.character.stat("speed") == 80 and player.character.stat("agility") == 65 and player.character.stat("strength") == 50, "Combat adapter replaces only its own override keys")
	check(player.reload_movement() and player.character.stat("speed") == 80 and player.character.stat("agility") == 65, "F3 retains shared overrides")
	var original_path: String = player.combat_profile_path
	player.combat_profile_path = "res://tests/missing_character.cfg"
	check(not player.reload_movement() and player.character.base == before, "Failed combined reload preserves baseline")
	player.combat_profile_path = original_path
	player.reload_movement()
	player.character.set_live({"speed":70})
	player.controls_active = true
	player.combat.request_attack(player)
	var attack_time: float = player.combat.frame_seconds
	player.character.set_live({"speed":90})
	check(is_equal_approx(attack_time, 3.0 * 45.0 / 980.0) and player.combat.frame_seconds == attack_time, "Attack snapshots shared Speed at start")
	player.combat.cancel()
	player.combat.request_attack(player)
	check(player.combat.frame_seconds < attack_time, "Next attack reads changed shared Speed")
	player.combat.cancel()
	player.character.set_live({})
	player.controls_active = true
	await routed(KEY_C)
	check(sheet.visible and player.modal_open and not player.controls_active and level.modal.previous_capture, "C opens sheet with captured preference")
	check(sheet.details.text.contains("300 / 300") and sheet.details.text.contains("Short Blade: 50.0") and sheet.details.text.contains("Speed: 50.0"), "Sheet reads real health and shared stats")
	check(player.combat.elapsed < 0, "Opening cancels pending player strikes")
	await routed(KEY_I)
	check(window.visible and not sheet.visible and player.modal_open and level.modal.previous_capture, "I switches to inventory without losing capture preference")
	await routed(KEY_C)
	check(sheet.visible and not window.visible and window.source == null, "C switches back and clears loot source")
	check(not level.persistence.refusal().is_empty(), "K refuses any modal")
	await routed(KEY_ESCAPE)
	check(not player.modal_open and player.controls_active, "Escape restores captured controls")
	player.controls_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await routed(KEY_C)
	await routed(KEY_C)
	check(not player.modal_open and not player.controls_active, "Released controls survive sheet toggle")
	var armor_uid := 0
	var mace_uid := 0
	for item in player.inventory.items:
		if item.definition == "steel_cuirass": armor_uid = item.uid
		if item.definition == "mace": mace_uid = item.uid
	player.inventory.equip(armor_uid)
	player.inventory.equip(mace_uid)
	player.health.apply_damage(30)
	sheet.open()
	check(sheet.details.text.contains("270 / 300") and sheet.details.text.contains("Chest protection: 9") and sheet.details.text.contains("Mace"), "Sheet reflects live health and independently equipped armor/weapon")
	await capture("character_sheet_4_3")
	sheet.details.scroll_to_line(25)
	await frames(2)
	await capture("character_sheet_equipment")
	level.presentation.set_profile("widescreen")
	await frames(2)
	await capture("character_sheet_widescreen")
	sheet.close()
	var baseline: Dictionary = player.character.base.duplicate()
	baseline.speed = 65
	player.character.set_base(baseline)
	var data: Dictionary = level.persistence.snapshot()
	check(data.version == 8 and data.player.character.speed == 65 and level.persistence.validate(data), "Schema8 validates persistent character base")
	var invalid := data.duplicate(true)
	invalid.player.character.speed = -1
	check(not level.persistence.validate(invalid), "Malformed saved character rejects before apply")
	invalid = data.duplicate(true)
	invalid.version = 2
	check(not level.persistence.validate(invalid), "Old schema rejects explicitly")
	player.character.set_live({"speed":90})
	level.persistence.apply(data)
	check(player.character.stat("speed") == 65 and player.character.live.is_empty(), "Restore applies base and clears transient overrides")
	level.persistence.slot_path = "res://tests/character_sheet_slot.json"
	check(level.persistence.write_slot(data), "Character test slot writes without touching manual save")
	player.controls_active = true
	sheet.open()
	await routed(KEY_L)
	level = current_scene
	player = level.player
	window = level.loot_window
	sheet = level.character_sheet
	check(player.character.stat("speed") == 65 and not player.modal_open and not sheet.visible and player.controls_active, "Routed L from sheet restores persistent base and prior captured controls")
	check(window.source == null and level.modal.active == null, "Loaded scene has no stale modal or loot source")
	sheet.open()
	player.health.apply_damage(1000)
	check(not sheet.visible and not player.modal_open and not player.controls_active, "Death closes sheet without restoring controls")
	print("CHARACTER SHEET RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	FileAccess.open("res://tests/character_sheet_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)



