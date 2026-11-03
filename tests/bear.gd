extends "res://tests/combat_resolution.gd"

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	player = level.player
	player.controls_active = false
	arena = level.world_root
	window = level.loot_window
	hall = arena.get_node("hall_combat_target")
	hall.melee.enabled = false
	check(player.health.maximum == 300 and player.health.current == 300, "Active playtest starts with 300 current and maximum HP")
	check(player.combat_stats.stat("short_blade") == 50 and player.combat_stats.stat("blunt_weapon") == 50 and player.combat_stats.stat("hand_to_hand") == 50, "Active weapon skills are50; other combat skills remain unchanged")
	var start: Dictionary = level.classic.section.definition.prototype.player_start
	check(player.position.distance_to(level.classic.to_world(start.position_native)) < 0.02 and player.position.distance_to(Vector3(7.25, 12.8, 16.2)) < 0.02, "Original authored hall start beside great stairs is unchanged")
	check(player.inventory.items.size() == 7 and player.inventory.has_dagger() and player.inventory.armor_uid == 0, "Test inventory grants equipment without changing initial dagger or auto-equipping armor")
	var counts := {}
	var mace_uid := 0
	var armor_uid := 0
	for item in player.inventory.items:
		counts[item.definition] = counts.get(item.definition, 0) + int(item.quantity)
		if item.definition == "mace": mace_uid = int(item.uid)
		if item.definition == "steel_cuirass": armor_uid = int(item.uid)
	check(counts == {"dagger": 2, "mace": 1, "steel_cuirass": 1, "healing_potion": 2, "gold": 12, "twigs": 2}, "Mace, cuirass, spare dagger, doses and test materials are immediately owned")
	check(hall.creature_name == "Bear" and hall.sprite_payload.archive == 259 and not hall.can_open_doors, "Hall opponent is original grizzly bear; chamber and primary-enemy alias remain separate")
	check(not level.enemy.approach_enabled and hall != level.enemy, "Chamber placeholder stays passive with its first-enemy alias")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/combat_source.json"))
	var match_attributes := true
	for key in source.bear.attributes:
		match_attributes = match_attributes and level.classic.bear_attributes[key] == int(source.bear.attributes[key])
	check(match_attributes and hall.combat_stats.stat("agility") == 70 and hall.combat_stats.stat("hand_to_hand") == 50, "Bear original MONSTER.BSA career and level4-derived skills match independent evidence")
	check(hall.combat_stats.base_armor == 30 and not hall.combat_stats.skeleton and not hall.combat_stats.parry_sounds and hall.health.current == 30, "Bear armor6x5, no edged resistance/parry, and test health30 are correct")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/enemies/bear_frames.json"))
	var total_frames := 0
	for id in fixture:
		var expected: Dictionary = fixture[id]
		var record: Dictionary = hall.sprite_payload.corpse if id == "401:2" else hall.sprite_payload.records[int(id.split(":")[1])]
		var matches: bool = record.frames.size() == int(expected.frames) and record.frames[0].get_size() == Vector2(expected.pixels[0], expected.pixels[1]) and record.size_metres.distance_to(Vector2(expected.metres[0], expected.metres[1])) < 0.0001
		for i in record.frames.size():
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(record.frames[i].get_image().get_data())
			matches = matches and hash.finish().hex_encode() == expected.rgba_sha256[i]
			total_frames += 1
		check(matches, "Original bear sprite %s native dimensions/RGBA match independent audit" % id)
	check(total_frames == 51, "All51 original bear live/corpse frames are decoded without bundled assets")
	var r := Rules.new()
	check(r.chance(player, hall, 50, 0, 0, 0, 99).chance == 56 and r.chance(player, hall, 50, 0, 0, 0, 0).chance == 58, "Horizontal player hit chance is56 or58 percent against bear")
	var dagger: Dictionary = player.inventory.find(player.inventory.equipped_uid)
	check(weapon_result([0, 99, 0, 5], dagger).damage == 6, "Bear receives full edged weapon damage rather than skeleton halving")
	var enemy_rolls = scripted([8, 0, 99, 0, 7, 0, 99, 0, 7, 0, 99, 0, 9])
	var result: Dictionary = enemy_rolls.enemy_attack(hall, player)
	check(result.damage == 26 and result.components.size() == 3, "Bear's three attack slots roll1-8,1-8,1-10 once and aggregate up to26")
	var skipped = scripted([8, 99, 99, 99])
	check(skipped.enemy_attack(hall, player).damage == 0 and skipped.sequence.is_empty(), "Each bear damage slot has its own reflex gate")
	window.open_inventory()
	await frames(2)
	await select_owned(armor_uid)
	await mouse_click(window.equip_button.get_global_rect().get_center())
	check(player.inventory.armor_uid == armor_uid and player.inventory.has_dagger(), "Starting cuirass can be equipped immediately through inventory")
	await select_owned(mace_uid)
	await mouse_click(window.equip_button.get_global_rect().get_center())
	check(player.inventory.equipped_uid == mace_uid and player.inventory.armor_uid == armor_uid, "Starting mace equips independently of chest armor")
	await capture("bear_starting_equipment")
	window.close()
	player.position = hall.position + Vector3(0, 0, 1.5)
	player.camera.look_at(hall.position + Vector3.UP * 0.6)
	player.set_physics_process(false)
	hall.set_physics_process(false)
	player.controls_active = true
	await frames(2)
	hall.melee.enabled = true
	hall.melee.resolver = scripted([8, 0, 99, 0, 7, 0, 99, 0, 7, 0, 99, 0, 9])
	hall.melee.tick(hall, 0.0)
	hall.mobile.tick(0.299)
	hall.melee.tick(hall, 0.299)
	check(player.health.current == 300, "Bear animation applies no damage before original frame3 marker")
	hall.mobile.tick(0.001)
	hall.melee.tick(hall, 0.001)
	check(player.health.current == 274 and hall.melee.phase == "recovery" and hall.mobile.source_frame == 3, "Bear frame3 event aggregates the three source attacks into one health application")
	hall.mobile.tick(0.1)
	hall.melee.tick(hall, 0.1)
	check(player.health.current == 274 and hall.mobile.source_frame == 0, "Bear attack tail returns to source frame0 without repeating damage")
	hall.melee.cancel()
	hall.mobile.set_state("idle")
	var sounds: Array = []
	level.combat_audio.played.connect(func(event, id, spatial): sounds.append([event, id, spatial]))
	hall.play_sound("skeleton_move")
	check(sounds.back() == ["bear_move", 127, true], "Bear uses own original spatial move sound127")
	var voices: int = level.combat_audio.voices.size()
	level.combat_audio.stop_creature(hall)
	check(level.combat_audio.voices.size() < voices, "Bear-owned voices stop through normal creature lifecycle")
	var c = player.combat
	c.resolver = scripted([0, 99, 99])
	c.request_attack(player)
	c.tick(player, c.windup + 0.00001)
	check(c.feedback == "Missed target" and sounds.back()[0] == "miss_mace" and hall.health.current == 30, "Bear missed-target rolls whiff instead of skeleton clash and do not damage")
	c.cancel()
	player.show_movement_debug = true
	await capture("bear_combat_4_3")
	level.presentation.set_profile("widescreen")
	await capture("bear_combat_widescreen")
	for direction in 8:
		hall.mobile.select_view(hall.position + hall.global_basis * Vector3(-sin(direction * PI/4), 0, -cos(direction * PI/4))*5)
		check(hall.mobile.orientation == direction and hall.mobile.flip_h == (direction > 4), "Bear native view direction%d mirrors correctly" % direction)
	hall.receive_damage(1000)
	check(hall.mobile.state == "corpse" and hall.mobile.source_record == 2 and hall.collision_layer == 0 and hall.loot_title().begins_with("BEAR"), "Bear death keeps native401:2 nonblocking, correctly labeled corpse")
	await capture("bear_corpse")
	player.set_physics_process(true)
	player.controls_active = false
	player.position = player.spawn
	await frames(12)
	level.persistence.slot_path = "res://saves/bear_test.json"
	check(level.persistence.save_slot(), "Active 300HP/equipment/dead-bear state saves")
	check(await level.persistence.load_slot(), "Active bear section loads from fresh validated scene")
	level = current_scene
	player = level.player
	hall = level.world_root.get_node("hall_combat_target")
	check(player.health.maximum == 300 and player.health.current == 274 and player.inventory.equipped_uid == mace_uid and player.inventory.armor_uid == armor_uid and hall.creature_name == "Bear" and hall.mobile.state == "corpse", "Load preserves300 maxHP, current health, equipment and original bear corpse")
	var section := preload("res://scripts/classic_section.gd").new()
	var definition: Dictionary = level.classic.section.definition.duplicate(true)
	definition.prototype.player_test.maximum_health = 0
	check(not section.validate(definition), "Section schema rejects invalid playtest HP")
	definition = level.classic.section.definition.duplicate(true)
	definition.prototype.player_test.items[0].quantity = 2
	check(not section.validate(definition), "Section schema rejects stacking test weapons")
	reload_current_scene()
	await frames(12)
	level = current_scene
	player = level.player
	hall = level.world_root.get_node("hall_combat_target")
	check(player.health.current == 300 and player.inventory.items.size() == 7 and hall.creature_name == "Bear" and hall.health.current == 30, "Fresh restart restores generous testing inventory/health and a living bear")
	print("BEAR RESULTS: %d/%d" % [results.size()-failures.size(), results.size()])
	FileAccess.open("res://tests/bear_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)


