extends "res://tests/character_sheet.gd"
const ArmorCatalog = preload("res://scripts/item_catalog.gd")
const InventoryModel = preload("res://scripts/inventory.gd")
const EXPECTED := {"head":"steel_helm", "right_arm":"steel_right_pauldron", "left_arm":"steel_left_pauldron", "chest":"steel_cuirass", "hands":"steel_gauntlets", "legs":"steel_greaves", "feet":"steel_boots"}

func owned_uid(definition: String) -> int:
	for item in player.inventory.items:
		if item.definition == definition:
			return int(item.uid)
	return 0

func inspect_owned(uid: int) -> void:
	for index in window.player_list.item_count:
		if int(window.player_list.get_item_metadata(index)) == uid:
			window.player_list.select(index)
			window.player_list.ensure_current_is_visible()
			window.select_player_item(index)
			await frames(2)
			return

func click_equip() -> void:
	await mouse_click(window.equip_button.global_position + window.equip_button.size / 2)
	await frames(2)

func verify_icons() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/items/icon_frames.json"))
	for id in EXPECTED.values():
		var expected: Dictionary = fixture.icons[id]
		var texture: Texture2D = level.classic.item_icons[id]
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(texture.get_image().get_data())
		check(texture.get_size() == Vector2(expected.pixels[0],expected.pixels[1]) and hash.finish().hex_encode() == expected.rgba_sha256, "Independent original armor icon dimensions/RGBA: " + id)
	var raw: Image = level.classic.read_texture(249,27,0,true,false)
	var clean: Image = level.classic.item_icons.steel_helm.get_image()
	var removed := 0
	var preserved := true
	for y in raw.get_height():
		for x in raw.get_width():
			if raw.get_pixel(x,y).a > 0 and clean.get_pixel(x,y).a == 0:
				removed += 1
			elif raw.get_pixel(x,y) != clean.get_pixel(x,y):
				preserved = false
	check(removed == 1110 and removed == int(fixture.icons.steel_helm.removed_mask_pixels) and preserved, "Helmet removes1110 paper-doll mask pixels and preserves all other RGBA")
	var again: Image = level.classic.read_texture(249,27,0,true)
	check(again.get_data() == raw.get_data(), "Default texture decoding retains mask; inventory cleanup does not mutate world callers")

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
	for enemy in level.enemies:
		enemy.melee.enabled = false
	player.controls_active = false
	if "--armor-read" in OS.get_cmdline_user_args():
		level.persistence.slot_path = "res://tests/armor_slot.json"
		var disk: Dictionary = level.persistence.read_slot()
		check(await level.persistence.load_slot(), "Separate process loads full armor equipment slot")
		level = current_scene
		player = level.player
		var same := true
		for region in 7:
			var slot: String = ArmorCatalog.ARMOR_SLOTS[region]
			same = same and player.inventory.armor_slots[slot] == int(disk.player.inventory.armor_slots[slot]) and player.combat_stats.armor(player,region) == 55
		check(same, "Separate process restores seven original UIDs and matching regional protection")
		check(player.inventory.equipped_uid == int(disk.player.inventory.equipped_uid) and player.health.current == 300, "Separate process retains weapon identity and accepted300HP")
		print("ARMOR CROSS PROCESS RESULTS: %d/%d" % [results.size()-failures.size(),results.size()])
		FileAccess.open("res://tests/armor_cross_process_results.txt",FileAccess.WRITE).store_string("\n".join(results))
		quit(0 if failures.is_empty() else 1)
		return
	check(player.health.current == 300 and hall.creature_name == "Bear" and player.inventory.items.size() == 13, "Accepted bear/300HP start adds six armor pieces to original test inventory")
	check(player.inventory.armor_slots.size() == 7 and player.inventory.armor_slots.values().count(0) == 7 and player.inventory.has_dagger(), "All seven armor slots start empty independently of readied dagger")
	verify_icons()
	var initial_items: Array = player.inventory.items.duplicate(true)
	var weapon_uid: int = player.inventory.equipped_uid
	var destination := InventoryModel.new()
	var rules := preload("res://scripts/combat_resolver.gd").new()
	for region in 7:
		var slot: String = ArmorCatalog.ARMOR_SLOTS[region]
		var uid := owned_uid(EXPECTED[slot])
		var before: Dictionary = rules.chance(hall,player,50,0,0,region,99)
		check(uid != 0 and player.inventory.equip(uid) and player.inventory.armor_slots[slot] == uid and player.inventory.equipped_uid == weapon_uid, "Equip only correct source slot: " + slot)
		var after: Dictionary = rules.chance(hall,player,50,0,0,region,99)
		check(player.combat_stats.armor(player,region) == 55 and before.unclamped - after.unclamped == 45, "Armor resolver and real incoming hit formula use matching region: " + slot)
		check(not player.inventory.transfer_to(destination,uid) and not player.inventory.consume_one(uid), "Equipped armor cannot transfer or consume: " + slot)
		player.inventory.unequip(uid)
		check(player.combat_stats.armor(player,region) == 100 and player.inventory.equipped_uid == weapon_uid, "Unequip restores naked region without touching weapon: " + slot)
	check(player.inventory.items == initial_items and destination.items.is_empty(), "Equipment operations preserve item identities/quantities without copies")
	var helmet_uid := owned_uid("steel_helm")
	var spare: int = player.inventory.add_item("steel_helm")
	player.inventory.equip(helmet_uid)
	player.inventory.equip(owned_uid("steel_cuirass"))
	player.inventory.equip(spare)
	check(player.inventory.armor_slots.head == spare and not player.inventory.is_equipped(helmet_uid) and player.inventory.armor_uid == owned_uid("steel_cuirass"), "Same-slot replacement retains displaced item and leaves chest alias intact")
	check(player.inventory.transfer_to(destination,helmet_uid) and destination.find(helmet_uid).quantity == 1, "Displaced armor becomes transferable without losing UID")
	for slot in ArmorCatalog.ARMOR_SLOTS:
		player.inventory.unequip(player.inventory.armor_slots[slot])
	player.inventory.equip(weapon_uid)
	await routed(KEY_I)
	for region in 7:
		var slot: String = ArmorCatalog.ARMOR_SLOTS[region]
		var uid: int = spare if slot == "head" else owned_uid(EXPECTED[slot])
		await inspect_owned(uid)
		check(window.preview.texture == level.classic.item_icons[EXPECTED[slot]] and window.description.text.contains(ArmorCatalog.SLOT_NAMES[slot]+" protection now: 0"), "Inventory preview/current regional protection: " + slot)
		await click_equip()
		check(player.inventory.armor_slots[slot] == uid and window.drop_button.disabled and window.equip_button.text == "Unequip", "Actual Equip click updates slot/transfer guard: " + slot)
		if slot == "head":
			await capture("armor_helmet_4_3")
			level.presentation.set_profile("widescreen")
			await frames(2)
			await capture("armor_helmet_widescreen")
	check(player.inventory.armor_slots.values().count(0) == 0 and player.inventory.equipped_uid == weapon_uid, "All slots coexist with equipped dagger")
	await routed(KEY_C)
	for region in 7:
		var slot: String = ArmorCatalog.ARMOR_SLOTS[region]
		check(level.character_sheet.details.text.contains(ArmorCatalog.SLOT_NAMES[slot]+" protection: 9 | "+ArmorCatalog.label(EXPECTED[slot])), "Character sheet reads equipped item and actual region defense: " + slot)
	level.character_sheet.details.scroll_to_line(24)
	await frames(2)
	await capture("armor_sheet_widescreen")
	level.presentation.set_profile("dfu_reference")
	await frames(2)
	await capture("armor_sheet_4_3")
	await routed(KEY_ESCAPE)
	# Corpse deposit/take uses unchanged container ownership and nonsolid targeting.
	hall.receive_damage(999)
	window.open(hall)
	await inspect_owned(spare)
	check(not level.world_loot.drop(spare,window.source), "Equipped helmet refuses corpse deposit")
	await click_equip()
	check(level.world_loot.drop(spare,window.source) and hall.loot.find(spare).definition == "steel_helm", "Unequipped helmet deposits into open corpse retaining UID")
	window.refresh()
	for index in window.corpse_list.item_count:
		if window.corpse_list.get_item_metadata(index) == spare:
			window.corpse_list.select(index)
			window.select_corpse_item(index)
			break
	check(window.preview.texture == level.classic.item_icons.steel_helm and window.equip_button.disabled, "Corpse helmet previews but cannot equip while unowned")
	window.take_selected()
	check(player.inventory.find(spare).definition == "steel_helm", "Taking deposited helmet restores same owned instance")
	window.close()
	# Ground drop keeps per-session behavior for newly supported armor.
	window.open_inventory()
	check(level.world_loot.drop(spare), "Unequipped helmet can ground-drop through existing support rules")
	var pile: Area3D = level.world_loot.session_pile
	check(pile.loot.find(spare).definition == "steel_helm", "Ground pile owns original armor UID")
	check(pile.loot.transfer_to(player.inventory,spare) and player.inventory.equip(spare), "Ground armor can be recovered and equipped")
	pile.retire_empty()
	window.close()
	level.persistence.slot_path = "res://tests/armor_slot.json"
	var data: Dictionary = level.persistence.snapshot()
	check(data.version == 8 and data.player.inventory.armor_slots == player.inventory.armor_slots and level.persistence.validate(data), "Schema8 saves all seven independent slot references")
	for kind in ["missing", "extra", "wrong_slot", "unknown_uid", "duplicate", "weapon", "fraction", "enemy", "version"]:
		var bad := data.duplicate(true)
		match kind:
			"missing": bad.player.inventory.armor_slots.erase("feet")
			"extra": bad.player.inventory.armor_slots.shield = 0
			"wrong_slot": bad.player.inventory.armor_slots.head = player.inventory.armor_slots.feet
			"unknown_uid": bad.player.inventory.armor_slots.head = 999999
			"duplicate": bad.player.inventory.armor_slots.feet = spare
			"weapon": bad.player.inventory.armor_slots.head = weapon_uid
			"fraction": bad.player.inventory.armor_slots.head = 1.5
			"enemy": bad.enemies.hall_combat_target.inventory.armor_slots.head = spare
			"version": bad.version = 4
		check(not level.persistence.validate(bad), "Invalid slot save rejects before scene replacement: " + kind)
	check(level.persistence.write_slot(data), "Full equipment writes isolated slot")
	player.controls_active = true
	await routed(KEY_C)
	await routed(KEY_L)
	level = current_scene
	player = level.player
	window = level.loot_window
	check(player.inventory.armor_slots == data.player.inventory.armor_slots and player.inventory.equipped_uid == weapon_uid and player.controls_active, "L restores every slot/weapon UID and prior captured controls")
	var all_protected := true
	for region in 7:
		all_protected = all_protected and player.combat_stats.armor(player,region) == 55
	check(all_protected and player.health.maximum == 300, "Loaded regional protection is derived from restored inventory, with300HP preserved")
	await routed(KEY_R)
	level = current_scene
	player = level.player
	check(player.inventory.items.size() == 13 and player.inventory.armor_slots.values().count(0) == 7 and player.inventory.has_dagger(), "R restores authored pieces unequipped and original equipped dagger")
	print("ARMOR RESULTS: %d/%d" % [results.size()-failures.size(),results.size()])
	FileAccess.open("res://tests/armor_results.txt",FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)
