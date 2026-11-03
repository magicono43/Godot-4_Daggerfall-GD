extends "res://tests/world_loot.gd"

func run() -> void:
	level = load("res://tests/skeleton_regression.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	player = level.player
	window = level.loot_window
	arena = level.world_root
	hall = level.world_root.get_node("hall_combat_target")
	hall.melee.enabled = false
	var original_hall_position := hall.position
	var dagger: int = player.inventory.equipped_uid
	var mace := 0
	for item in hall.loot.items:
		if item.definition == "mace":
			mace = int(item.uid)
	check(mace != 0 and player.inventory.items.size() == 1, "Mace is in nearby hall skeleton loot, starting inventory remains dagger only")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/weapons/mace_frames.json"))
	var frames_total := 0
	for record in 7:
		var data: Dictionary = level.classic.weapon_frames.mace[record]
		var expected: Dictionary = fixture.records[record]
		var matches: bool = data.width == expected.pixels[0] and data.height == expected.pixels[1] and data.frames.size() == expected.rgba_sha256.size()
		for index in data.frames.size():
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(data.frames[index].get_image().get_data())
			matches = matches and hash.finish().hex_encode() == expected.rgba_sha256[index]
			frames_total += 1
		check(matches, "Mace source record %d native dimensions and RGBA match independent audit" % record)
	check(frames_total == 31, "Mace decodes one ready and thirty swing images")
	var icon_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/items/icon_frames.json")).icons.mace
	var icon: Texture2D = level.classic.item_icons.mace
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(icon.get_image().get_data())
	check(icon.get_size() == Vector2(icon_fixture.pixels[0], icon_fixture.pixels[1]) and hash.finish().hex_encode() == icon_fixture.rgba_sha256, "Mace original inventory image 234:14 matches independent audit")
	var raw := FileAccess.get_file_as_bytes(level.classic.arena_path.path_join("WEAPON05.CIF"))
	check(level.classic.decode_weapon_cif(raw.slice(0, raw.size() - 1)).is_empty(), "Truncated mace CIF is rejected")
	var broken := raw.duplicate()
	broken.encode_u16(4, 400)
	check(level.classic.decode_weapon_cif(broken).is_empty(), "Invalid mace CIF dimensions are rejected")
	hall.receive_damage(1000)
	await frames(2)
	aim()
	key(KEY_E)
	await frames(2)
	await mouse_click(window.corpse_list.global_position + window.corpse_list.get_item_rect(4).get_center())
	check(window.preview.texture == icon and window.equip_button.disabled, "Unowned mace previews original icon and cannot equip")
	await mouse_click(window.take_button.get_global_rect().get_center())
	await frames(2)
	await select_owned(mace)
	await mouse_click(window.equip_button.get_global_rect().get_center())
	check(player.inventory.equipped_uid == mace and player.inventory.equipped_weapon() == "mace" and not player.inventory.has_dagger(), "Actual loot/equip click selects owned mace rather than duplicating dagger state")
	await capture("mace_inventory")
	key(KEY_I)
	await frames(2)
	var c = player.combat
	var view = c.weapon
	check(view.weapon_key == "mace" and view.texture == level.classic.weapon_frames.mace[0].frames[0] and view.visible, "Equipped mace displays original ready sprite")
	var screen: Vector2 = level.presentation.viewport.get_visible_rect().size
	check(is_equal_approx(view.position.x, screen.x - view.size.x), "Mace ready sprite uses general right alignment without dagger inset")
	await capture("mace_ready_4_3")
	key(KEY_F2)
	await capture("mace_ready_widescreen")
	key(KEY_F2)
	player.set_physics_process(false)
	player.movement.set_live_stats({"speed_attribute": 50.0})
	var directions: Dictionary = {}
	for i in 100:
		c.cancel()
		c.request_attack(player)
		directions[c.attack_record] = true
	check(directions.size() == 6 and preload("res://scripts/item_catalog.gd").WEAPONS.mace.maximum == 12, "Mace accepts six directions and has its original 1-12 base damage profile")
	c.cancel()
	var target := preload("res://scripts/enemy.gd").new()
	target.player = player
	target.approach_enabled = false
	arena.add_child(target)
	target.position = original_hall_position
	target.health.maximum = 100
	target.health.current = 100
	hall = target
	aim()
	await frames(2)
	c.request_attack(player)
	c.tick(player, c.windup - 0.001)
	check(target.health.current == 100 and view.source_frame == 1, "Mace does not damage before frame two")
	c.tick(player, 0.001)
	check(target.health.current == 85 and view.source_frame == 2, "Mace frame two applies exactly 15 damage")
	c.tick(player, c.recovery + 0.01)
	check(target.health.current == 85 and c.elapsed < 0 and view.source_record == 0, "Mace attack tail cannot repeat damage and returns to ready")
	player.movement.set_live_stats({"speed_attribute": 80.0})
	c.request_attack(player)
	check(is_equal_approx(c.frame_seconds, 3.0 * 35.0 / 980.0), "New mace attack reads live Speed using pinned melee formula")
	c.cancel()
	player.movement.set_live_stats({"speed_attribute": 50.0})
	var cover := box(Vector3(2, 3, 0.15), (target.position + player.position) * 0.5 + Vector3.UP)
	await frames(2)
	c.request_attack(player)
	c.tick(player, c.windup)
	check(target.health.current == 85 and c.feedback == "Blocked", "Mace strike preserves nearest-obstruction targeting")
	c.cancel()
	cover.queue_free()
	await frames(2)
	c.request_attack(player)
	player.inventory.equip(dagger)
	c.tick(player, c.windup)
	check(c.elapsed < 0 and target.health.current == 85 and view.weapon_key == "dagger", "Changing equipment during windup cancels pending mace damage and restores dagger visuals")
	player.inventory.equip(mace)
	c.cancel()
	var sounds: Array = []
	level.combat_audio.played.connect(func(event: String, id: int, _spatial: bool): sounds.append([event, id]))
	c.toggle_sheath()
	check(c.sheathed and not view.visible, "Z sheath state hides equipped mace")
	c.toggle_sheath()
	check(sounds.back() == ["draw_mace", 413] and view.visible, "Drawing mace uses original EquipMaceOrHammer 413")
	player.camera.look_at(player.camera.global_position + Vector3(0.2, 1, 0))
	await frames(2)
	c.request_attack(player)
	c.tick(player, c.windup)
	check(sounds.back() == ["miss_mace", 347], "Missed mace strike uses original medium swing 347")
	c.cancel()
	for record in range(1, 7):
		c.request_attack(player)
		c.attack_record = record
		c.tick(player, c.frame_seconds * 2)
		await capture("mace_swing_%d" % record)
		c.cancel()
	c.request_attack(player)
	key(KEY_I)
	check(c.elapsed < 0 and player.modal_open, "Opening inventory cancels pending mace attack")
	await frames(2)
	await select_owned(mace)
	await mouse_click(window.equip_button.get_global_rect().get_center())
	check(not player.inventory.has_weapon() and not view.visible and not c.request_attack(player), "Unequipping mace hides it and disables attacks")
	player.set_physics_process(true)
	key(KEY_I)
	await frames(4)
	key(KEY_I)
	await frames(2)
	await select_owned(mace)
	await mouse_click(window.drop_button.get_global_rect().get_center())
	var pile: Node3D = level.world_loot.session_pile
	check(is_instance_valid(pile) and not pile.loot.find(mace).is_empty(), "Unequipped mace drops as its own nonstackable instance")
	window.close()
	window.open(pile)
	window.take_all()
	check(not player.inventory.find(mace).is_empty() and not player.inventory.has_weapon(), "Dropped mace recovers without auto-equipping")
	key(KEY_R)
	await frames(10)
	level = current_scene
	player = level.player
	var restored_mace := false
	for item in level.world_root.get_node("hall_combat_target").loot.items:
		restored_mace = restored_mace or item.definition == "mace"
	check(player.inventory.has_dagger() and player.combat.weapon.weapon_key == "dagger" and restored_mace, "R restores starting dagger and skeleton's test mace")
	print("MACE RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	FileAccess.open("res://tests/mace_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)


