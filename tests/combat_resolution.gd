extends "res://tests/world_loot.gd"
const Rules = preload("res://scripts/combat_resolver.gd")
const Catalog = preload("res://scripts/item_catalog.gd")

class Rolls extends "res://scripts/combat_resolver.gd":
	var sequence: Array[int] = []
	func roll(maximum: int) -> int:
		assert(not sequence.is_empty(), "Unexpected combat roll")
		var value: int = sequence.pop_front()
		assert(value >= 0 and value < maximum, "Roll outside its source range")
		return value

func _initialize() -> void:
	# Intentionally use real formulas, without the legacy fixed-damage fixture.
	call_deferred("run")

func scripted(sequence: Array) -> RefCounted:
	var result := Rolls.new()
	result.sequence.assign(sequence)
	return result

func weapon_result(sequence: Array, item: Dictionary, record: int = 3) -> Dictionary:
	var resolver = scripted(sequence)
	var result: Dictionary = resolver.weapon_attack(player, hall, item, record)
	assert(resolver.sequence.is_empty(), "Unconsumed expected rolls")
	return result

func run() -> void:
	level = load("res://tests/skeleton_regression.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	player = level.player
	arena = level.world_root
	window = level.loot_window
	hall = arena.get_node("hall_combat_target")
	hall.melee.enabled = false
	player.controls_active = false
	var stats = player.combat_stats
	var rules := Rules.new()
	var dagger: Dictionary = player.inventory.find(player.inventory.equipped_uid).duplicate(true)
	var mace := {"uid": 800, "definition": "mace", "quantity": 1, "material": "steel"}
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/combat_source.json"))
	var attributes_match := true
	for key in source.skeleton.attributes:
		attributes_match = attributes_match and level.classic.skeleton_attributes[key] == int(source.skeleton.attributes[key])
	check(attributes_match and hall.combat_stats.stat("agility") == 80, "Original MONSTER.BSA skeleton career matches independent audit")
	check(hall.combat_stats.stat("hand_to_hand") == 75 and hall.combat_stats.base_armor == 10 and hall.combat_stats.parry_sounds, "Skeleton level-derived skills, armor x5 and parry flag match pinned source")
	check(ClassicData.decode_monster_attributes(PackedByteArray([1, 2])).is_empty(), "Truncated original career rejects cleanly")
	check(stats.stat("strength") == 50 and stats.stat("short_blade") == 25 and dagger.material == "steel", "Authored baseline is explicit; original starting dagger is steel")
	var before: Dictionary = stats.values.duplicate()
	check(not stats.set_live_stats({"short_blade": -1}) and stats.live_stats.is_empty(), "Invalid live combat values reject atomically")
	check(not stats.set_live_stats({"speed": 70}) and not stats.set_live_stats({"strength": 50.5}), "Combat does not invent a second Speed or accept fractional skills")
	var config := ConfigFile.new()
	config.set_value("player", "strength", -5)
	config.save("res://tests/invalid_combat.cfg")
	check(not stats.load_file("res://tests/invalid_combat.cfg") and stats.values == before, "Invalid combat reload retains the complete previous baseline")
	stats.load_file(player.combat_profile_path)
	var chance: Dictionary = rules.chance(player, hall, 25, 0, 0, 3, 99)
	check(chance.chance == 4 and chance.armor == 10 and chance.stats == -3 and chance.dodging == -18 and chance.monster == 40, "Independently calculated 4 percent skeleton hit chance preserves all baseline modifiers")
	check(rules.chance(player, hall, 25, 0, 0, 3, 0).chance == 6, "Critical Strike proc adds skill/10 to chance, not doubled damage")
	stats.set_live_stats({"agility": 71, "luck": 41})
	check(rules.chance(player, hall, 25, 0, 0, 3, 99).stats == 0, "Negative attribute differences use C# truncation toward zero")
	stats.set_live_stats({})
	check(rules.chance(player, hall, 0, -100, -10, 0, 99).chance == 3 and rules.chance(player, hall, 100, 100, 10, 0, 99).chance == 97, "Hit probability clamps at 3 and 97 percent")
	check(weapon_result([0, 99, 3, 5], dagger).damage == 3, "Roll just below 4 percent succeeds; dagger max6 halves to3 versus skeleton")
	check(weapon_result([0, 99, 4], dagger).outcome == "miss", "Roll at the hit threshold fails without consuming damage roll")
	check(weapon_result([0, 99, 0, 0], dagger).outcome == "no_damage", "A successful one-point edged roll can become zero after skeleton resistance")
	check(weapon_result([0, 99, 0, 11], mace).damage == 12, "Mace max12 bypasses edged-weapon resistance")
	var silver := dagger.duplicate()
	silver.material = "silver"
	check(weapon_result([0, 99, 0, 5], silver).damage == 6, "Skeleton silver doubles after edged halving")
	stats.set_live_stats({"strength": 55})
	check(weapon_result([0, 99, 0, 5], dagger).damage == 4, "Strength adds after skeleton resistance")
	stats.set_live_stats({"strength": 49})
	check(weapon_result([0, 99, 0, 5], dagger).damage == 2, "Strength below50 uses floor rather than truncation")
	stats.set_live_stats({})
	for record in range(1, 7):
		var result := weapon_result([0, 99, 0, 5], dagger, record)
		check(result.damage == [5, 4, 3, 3, 2, 1][record - 1] and result.swing == [-10, -5, 0, 0, 5, 10][record - 1], "Displayed swing record %d has exact source chance/damage modifiers" % record)
	var iron := dagger.duplicate()
	iron.material = "iron"
	check(weapon_result([0, 99, 0, 5], iron).damage == 2, "Iron subtracts one damage after skeleton resistance")
	check(rules.chance(player, hall, 25, -10, 0, 0, 99).chance == 3, "Iron minus-one material converts to minus-ten hit chance")
	hall.combat_stats.minimum_material = 2
	check(weapon_result([], dagger).outcome == "ineffective", "Ineffective material rejects before hit/body/damage rolls")
	hall.combat_stats.minimum_material = -1
	var distribution := {}
	for region in Rules.BODY_PARTS:
		distribution[region] = distribution.get(region, 0) + 1
	check(distribution == {0: 2, 1: 3, 2: 3, 3: 4, 4: 4, 5: 3, 6: 1}, "Seven body regions use pinned weighted selection, independent of aiming height")
	var cuirass := 0
	var mace_uid := 0
	for item in hall.loot.items:
		if item.definition == "steel_cuirass":
			cuirass = int(item.uid)
		if item.definition == "mace":
			mace_uid = int(item.uid)
	check(cuirass != 0 and mace_uid != 0, "Hall test loot contains the cuirass and mace")
	hall.receive_damage(1000)
	await frames(2)
	window.open(hall)
	check(window.take(cuirass) and window.take(mace_uid), "Real corpse collection transfers cuirass and mace ownership")
	await frames(2)
	await select_owned(cuirass)
	await mouse_click(window.equip_button.get_global_rect().get_center())
	check(player.inventory.armor_uid == cuirass and player.inventory.equipped_uid == dagger.uid and window.equipment_status.text == "Equipped armor", "Actual Equip click gives armor its own slot without replacing the weapon")
	check(window.preview.texture == level.classic.item_icons.steel_cuirass and window.description.text.contains("Protection 9"), "Cuirass uses original image and clear region/protection description")
	var icon_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/items/icon_frames.json")).icons.steel_cuirass
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(level.classic.item_icons.steel_cuirass.get_image().get_data())
	check(hash.finish().hex_encode() == icon_fixture.rgba_sha256 and level.classic.item_icons.steel_cuirass.get_size() == Vector2(38, 50), "Steel cuirass original 249:4 RGBA matches independent read-only audit")
	check(stats.armor(player, 3) == 55 and stats.armor(player, 0) == 100, "Steel cuirass lowers chest armor by45; other regions remain naked")
	check(rules.chance(hall, player, 75, 0, 0, 3, 99).chance == 77 and rules.chance(hall, player, 75, 0, 0, 0, 99).chance == 97, "Cuirass reduces this skeleton's chest hit chance from capped97 to77 percent")
	check(not level.world_loot.drop(cuirass, hall) and not player.inventory.consume_one(cuirass), "Equipped armor cannot be dropped, deposited or consumed")
	await capture("combat_armor_inventory")
	await mouse_click(window.equip_button.get_global_rect().get_center())
	check(player.inventory.armor_uid == 0 and player.inventory.has_dagger(), "Unequipping armor preserves the equipped dagger")
	await mouse_click(window.equip_button.get_global_rect().get_center())
	player.inventory.equip(mace_uid)
	check(player.inventory.armor_uid == cuirass and player.inventory.equipped_uid == mace_uid, "Weapon switching preserves equipped chest armor")
	window.close()
	var strike = scripted([8, 0, 99, 76, 10])
	check(strike.enemy_attack(hall, player).damage == 15, "Skeleton reflex-pass plus chest hit applies original 5-15 damage range")
	strike = scripted([8, 0, 99, 77])
	check(strike.enemy_attack(hall, player).damage == 0, "Skeleton chest roll at77 misses equipped steel cuirass")
	strike = scripted([8, 50])
	check(strike.enemy_attack(hall, player).get("reflex_skipped", false), "Average reflex gate rejects50 before hit/damage rolls")
	stats.set_live_stats({"reflexes": 4})
	strike = scripted([8, 30])
	check(strike.enemy_attack(hall, player).get("reflex_skipped", false), "Reflex setting changes monster attempt chance from50 to30 percent")
	stats.set_live_stats({})
	# Audio/animation integration with a living fresh actor; do not revive corpse.
	var living := preload("res://scripts/enemy.gd").new()
	living.player = player
	living.approach_enabled = false
	living.combat_stats.configure_skeleton(level.classic.skeleton_attributes)
	living.position = hall.position
	living.sprite_payload = level.classic.enemy_visuals.skeleton
	living.combat_audio = level.combat_audio
	arena.add_child(living)
	living.set_physics_process(false)
	player.position = living.position + Vector3(0, 0, 1.5)
	player.camera.look_at(living.position + Vector3.UP * 0.6)
	player.controls_active = true
	player.set_physics_process(false)
	await frames(2)
	living.melee.enabled = true
	living.melee.resolver = scripted([8, 0, 99, 0, 0])
	living.melee.tick(living, 0.0)
	living.mobile.tick(0.4)
	living.melee.tick(living, 0.4)
	check(player.health.current == 95 and living.melee.phase == "recovery", "Actual skeleton frame-four event consumes one formula result against equipped armor")
	living.melee.tick(living, 0.1)
	check(player.health.current == 95, "Enemy recovery does not repeat formula damage")
	living.melee.cancel()
	living.mobile.set_state("idle")
	player.health.current = 100
	var sounds: Array = []
	level.combat_audio.played.connect(func(event, id, spatial): sounds.append([event, id, spatial]))
	var c = player.combat
	c.sheathed = false
	c.resolver = scripted([0, 99, 99])
	check(c.request_attack(player), "Real equipped mace starts an animation-driven formula attack")
	c.tick(player, c.windup + 0.00001)
	check(c.feedback == "Missed target" and living.health.current == 30 and living.mobile.state == "idle", "Failed target roll deals no damage and does not hurt-interrupt the skeleton")
	check(sounds.back()[0] == "parry" and sounds.back()[1] >= 428 and sounds.back()[1] <= 436 and sounds.back()[2], "Skeleton failed-target roll emits one spatial original parry-bank cue")
	var count := sounds.size()
	c.tick(player, c.recovery + 0.01)
	check(sounds.size() == count, "Attack tail does not replay miss/parry cue")
	living.combat_stats.parry_sounds = false
	c.resolver = scripted([0, 99, 99])
	c.request_attack(player)
	c.tick(player, c.windup + 0.00001)
	check(sounds.back()[0] == "miss_mace", "Ordinary failed target roll retains weapon whiff sound")
	c.cancel()
	living.combat_stats.parry_sounds = true
	c.resolver = scripted([0, 99, 0, 11])
	c.request_attack(player)
	c.attack_record = 1
	c.pose()
	c.tick(player, c.windup + 0.00001)
	check(c.feedback == "Hit: 16" and living.health.current == 14 and sounds.back()[0] == "impact", "Mace's visible down-swing resolves base12 plus4 once with impact sound")
	c.cancel()
	await capture("combat_formula_hit")
	player.show_movement_debug = true
	await capture("combat_formula_diagnostics_4_3")
	level.presentation.set_profile("widescreen")
	await capture("combat_formula_diagnostics_widescreen")
	# Persistence checks run on authored nodes only; retire isolated integration actor.
	living.queue_free()
	player.set_physics_process(true)
	player.position = player.spawn
	player.controls_active = false
	await frames(12)
	level.persistence.slot_path = "res://saves/combat_test.json"
	check(level.persistence.save_slot(), "Version2 snapshot saves armor, weapon material and normal world state")
	var saved: Dictionary = level.persistence.read_slot()
	if saved.is_empty():
		print("READ DETAIL ", level.persistence.error)
		quit(1)
		return
	check(saved.version == 6 and saved.player.inventory.armor_slots.chest == cuirass, "Save includes independent armor UID")
	var bad := saved.duplicate(true)
	bad.version = 1
	check(not level.persistence.validate(bad) and level.persistence.error.contains("Unsupported save version"), "Old prototype saves reject explicitly without migration")
	bad = saved.duplicate(true)
	bad.player.inventory.armor_slots.chest = mace_uid
	check(not level.persistence.validate(bad), "Save rejects weapon references in armor slot")
	bad = saved.duplicate(true)
	for item in bad.player.inventory.items:
		if item.uid == mace_uid:
			item.material = "invalid"
	check(not level.persistence.validate(bad), "Save rejects unknown material before scene replacement")
	check(await level.persistence.load_slot(), "Version2 load restores equipped armor and steel mace")
	level = current_scene
	player = level.player
	window = level.loot_window
	check(player.inventory.armor_uid == cuirass and player.inventory.equipped_uid == mace_uid and player.combat_stats.armor(player, 3) == 55, "Loaded armor changes defense without replacing weapon identity")
	await frames(3)
	window.open_inventory()
	await frames(2)
	await select_owned(cuirass)
	await mouse_click(window.equip_button.get_global_rect().get_center())
	await mouse_click(window.drop_button.get_global_rect().get_center())
	check(player.inventory.find(cuirass).is_empty() and player.inventory.equipped_uid == mace_uid, "Unequipped armor drops through actual inventory UI without disturbing weapon")
	window.close()
	var drops := get_nodes_in_group("world_loot_piles")
	var found = null
	for pile in drops:
		if not pile.loot.find(cuirass).is_empty():
			found = pile
	check(found != null, "Dropped cuirass retains its UID in a world pile")
	if found != null:
		window.open(found)
	check(found != null and window.take(cuirass) and player.inventory.equip(cuirass), "Dropped armor can be recovered and re-equipped")
	window.close()
	print("COMBAT RESOLUTION RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	FileAccess.open("res://tests/combat_resolution_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)


