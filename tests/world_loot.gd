extends "res://tests/inventory.gd"

func select_owned(uid: int) -> void:
	for index in window.player_list.item_count:
		if int(window.player_list.get_item_metadata(index)) == uid:
			await mouse_click(window.player_list.global_position + window.player_list.get_item_rect(index).get_center())
			return

func look_at_pile(pile: Node3D) -> void:
	player.camera.look_at(pile.global_position + Vector3.UP * 0.15)
	player.update_interaction()

func verify_stacking() -> void:
	var owner := preload("res://scripts/inventory.gd").new()
	var other := preload("res://scripts/inventory.gd").new()
	var coins: int = owner.add_item("gold", 18)
	var incoming: int = other.add_item("gold", 12)
	check(other.transfer_to(owner, incoming) and owner.items.size() == 1 and owner.find(coins).quantity == 30 and other.items.is_empty(), "18 plus 12 coins merge into one 30-coin stack on transfer")
	check(not other.transfer_to(owner, incoming) and owner.find(coins).quantity == 30 and owner.find(incoming).is_empty(), "Merged source UID is retired and cannot be transferred twice")
	var doses: int = owner.add_item("healing_potion", 1)
	var more: int = other.add_item("healing_potion", 2)
	check(other.move_to(owner, more) == doses and owner.find(doses).quantity == 3, "Identical healing potions merge and return surviving destination identity")
	check(owner.consume_one(doses) and owner.find(doses).quantity == 2, "Using one dose decrements the merged potion stack")
	check(owner.add_item("gold", 5) == coins and owner.find(coins).quantity == 35, "Adding compatible items directly also stacks")
	var first: int = owner.add_item("dagger")
	var second: int = other.add_item("dagger")
	check(other.transfer_to(owner, second) and first != second and not owner.find(first).is_empty() and not owner.find(second).is_empty(), "Nonstackable daggers keep distinct owned instances")
	owner.equip(first)
	check(not owner.transfer_to(other, first) and owner.has_dagger(), "Stacking preserves equipped item transfer protection")
	var variant: int = other.add_item("healing_potion")
	other.find(variant)["variant"] = "different_effect"
	check(other.transfer_to(owner, variant) and owner.find(variant).quantity == 1 and owner.find(doses).quantity == 2, "Different item metadata prevents incompatible potion stacking")
	check(not owner.transfer_to(owner, coins) and owner.find(coins).quantity == 35, "Self transfer never doubles stack quantity")

func run() -> void:
	level = load("res://tests/skeleton_regression.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(15)
	player = level.player
	window = level.loot_window
	arena = level.world_root
	verify_stacking()
	var manager = level.world_loot
	var pile: Node3D = manager.authored_piles.chamber_treasure
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/items/world_loot.json"))
	var marker: Vector3 = level.classic.treasure_markers.chamber_treasure_marker
	check(marker == level.classic.to_world(fixture.markers.chamber_treasure_marker.native), "Treasure location matches independent original 199:19 marker")
	check(pile.position.x == marker.x and pile.position.z == marker.z and absf(pile.position.y - 1.025) < 0.01, "Original pile XZ preserved and billboard feet align to selected support")
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(pile.sprite.texture.get_image().get_data())
	check(context.finish().hex_encode() == fixture.sprite.rgba_sha256, "Pile uses audited original TEXTURE.216:0 RGBA image")
	check(pile.collision_layer == 4 and pile.collision_mask == 0 and pile.loot.items.size() == 2, "Authored pile has test collection and nonsolid interaction only")
	player.position = pile.position + Vector3(0, -1.02, 1.6)
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	await frames(12)
	look_at_pile(pile)
	check(player.interact_target == pile, "Nearby original pile is E-targetable independently of supporting prop")
	await capture("treasure_pile_world")
	var near := player.position
	player.position.z += 4
	look_at_pile(pile)
	check(player.interact_target != pile, "Distant world pile cannot be selected")
	player.position = near
	var cover := box(Vector3(2, 3, 0.15), pile.position + Vector3(0, 0.5, 0.7))
	await frames(2)
	look_at_pile(pile)
	check(player.interact_target != pile, "World geometry blocks pile targeting")
	cover.queue_free()
	await frames(2)
	look_at_pile(pile)
	key(KEY_E)
	check(window.visible and window.source == pile and window.title.text.contains("DUNGEON TREASURE"), "E opens shared loot window for original pile")
	var gold: int = pile.loot.items[0].uid
	window.take(gold)
	check(pile.loot.items.size() == 1 and pile.visible, "Partly looted pile stays visible")
	key(KEY_ESCAPE)
	look_at_pile(pile)
	key(KEY_E)
	check(pile.loot.items.size() == 1, "Original pile remaining contents persist across reopening")
	await frames(2)
	await select_owned(gold)
	await mouse_click(window.drop_button.get_global_rect().get_center())
	check(player.inventory.find(gold).is_empty() and not pile.loot.find(gold).is_empty() and pile.loot.items.size() == 2, "Drop adds owned stack back into open nearby noncorpse pile")
	await capture("treasure_pile_ui")
	key(KEY_F2)
	await capture("treasure_pile_widescreen")
	key(KEY_F2)
	window.take_all()
	check(not window.visible and pile.retired and not pile.visible and pile.collision_layer == 0, "Taking final pile item immediately hides billboard, disables interaction and closes UI")
	await frames(2)
	check(not is_instance_valid(pile) and get_nodes_in_group("world_loot_piles").is_empty(), "Empty noncorpse pile object is removed")
	key(KEY_I)
	await frames(2)
	var dagger: int = player.inventory.equipped_uid
	await select_owned(dagger)
	check(window.drop_button.disabled and not manager.drop(dagger) and player.inventory.has_dagger(), "Equipped weapon drop rejected without losing equipment")
	await select_owned(gold)
	await mouse_click(window.drop_button.get_global_rect().get_center())
	var drops := get_nodes_in_group("world_loot_piles")
	check(drops.size() == 1 and player.inventory.find(gold).is_empty(), "Actual Drop creates a world pile and moves whole owned stack")
	var dropped: Node3D = drops[0]
	check(dropped.dropped and dropped.loot.find(gold).quantity == 18, "Dropped pile preserves instance UID and full quantity")
	var potion: int = player.inventory.items[1].uid
	await select_owned(potion)
	await mouse_click(window.drop_button.get_global_rect().get_center())
	check(get_nodes_in_group("world_loot_piles").size() == 1 and dropped.loot.items.size() == 2, "All drops in one inventory-open session share its new pile")
	check(not manager.drop(gold) and dropped.loot.items.size() == 2, "Repeated stale drop cannot duplicate ownership")
	key(KEY_I)
	key(KEY_I)
	await frames(2)
	var extra: int = player.inventory.add_item("twigs", 3)
	window.refresh()
	await frames(2)
	await select_owned(extra)
	await mouse_click(window.drop_button.get_global_rect().get_center())
	var second_session: Node3D = manager.session_pile
	check(get_nodes_in_group("world_loot_piles").size() == 2 and second_session != dropped and dropped.loot.items.size() == 2 and second_session.loot.find(extra).quantity == 3, "Reopening inventory at the same spot creates a separate pile without proximity merging")
	check(second_session.position.distance_to(dropped.position) < 0.01, "Each session's pile stays where the player stood, even beside an older pile")
	key(KEY_I)
	window.open(second_session)
	window.take_all()
	await frames(2)
	check(not is_instance_valid(second_session) and dropped.loot.items.size() == 2, "Emptying one session pile leaves the other pile intact")
	window.open(dropped)
	await frames(2)
	await select_owned(extra)
	await mouse_click(window.drop_button.get_global_rect().get_center())
	check(dropped.loot.items.size() == 3 and not dropped.loot.find(extra).is_empty(), "Explicitly reopening an older pile allows adding more items to that pile")
	window.close()
	player.position.x -= 0.8
	await frames(4)
	look_at_pile(dropped)
	await capture("dropped_pile_world")
	key(KEY_E)
	check(window.visible and window.source == dropped and window.title.text == "DROPPED ITEMS", "Dropped pile can be opened using E")
	window.take_all()
	await frames(2)
	check(not is_instance_valid(dropped) and not player.inventory.find(gold).is_empty() and not player.inventory.find(potion).is_empty(), "Dropped items can be recovered once and empty dropped object disappears")
	key(KEY_I)
	await frames(2)
	await select_owned(player.inventory.equipped_uid)
	await mouse_click(window.equip_button.get_global_rect().get_center())
	await mouse_click(window.drop_button.get_global_rect().get_center())
	check(not player.inventory.has_dagger() and player.inventory.find(dagger).is_empty() and get_nodes_in_group("world_loot_piles").size() == 1, "Unequipped dagger can be dropped without leaving a stale equipped reference")
	var weapon_pile: Node3D = get_nodes_in_group("world_loot_piles")[0]
	key(KEY_I)
	player.position.x -= 0.8
	await frames(4)
	look_at_pile(weapon_pile)
	key(KEY_E)
	window.take_all()
	await frames(2)
	check(not player.inventory.find(dagger).is_empty() and not player.inventory.has_dagger(), "Recovered dagger remains owned and unequipped")
	var external: Node3D = manager.create_pile(player.position, true)
	var twig: int = external.loot.add_item("twigs")
	window.open(external)
	external.loot.transfer_to(player.inventory, twig)
	await frames(2)
	check(not is_instance_valid(external) and not window.visible, "Any transfer that empties a pile removes it and closes its active UI")
	# A fresh pile behind a wall must not receive a nearby or preferred drop.
	var beyond: Node3D = manager.create_pile(player.position + Vector3(0.9, 0, 0), true)
	beyond.loot.add_item("twigs")
	var wall := box(Vector3(0.12, 3, 2), player.position + Vector3(0.45, 1.5, 0))
	await frames(2)
	window.open(beyond)
	var original_position := player.position
	player.position += Vector3(0, 10, 0)
	player.climbing.active = true
	check(manager.drop(gold, beyond) and beyond.loot.items.size() == 2 and player.inventory.find(gold).is_empty(), "Already-open pile accepts deposit without a second reach, wall or ground check")
	player.climbing.reset()
	player.position = original_position
	window.close()
	wall.queue_free()
	var before: int = player.inventory.items.size()
	player.position.y += 10
	check(not manager.drop(potion) and player.inventory.items.size() == before, "Unsupported airborne drop fails without item loss")
	player.position.y -= 10
	player.climbing.active = true
	check(not manager.drop(potion) and player.inventory.items.size() == before, "Climbing drop fails without item loss")
	player.climbing.reset()
	var hall_enemy: CharacterBody3D = level.world_root.get_node("hall_combat_target")
	hall_enemy.receive_damage(1000)
	window.open(hall_enemy)
	window.take_all()
	check(window.visible and hall_enemy.visible and hall_enemy.loot.items.is_empty(), "Empty corpse remains visible and inspectable unlike noncorpse piles")
	var pile_count := get_nodes_in_group("world_loot_piles").size()
	await frames(2)
	await select_owned(potion)
	await mouse_click(window.drop_button.get_global_rect().get_center())
	check(hall_enemy.loot.find(potion).quantity == 3 and player.inventory.find(potion).is_empty() and get_nodes_in_group("world_loot_piles").size() == pile_count, "Actual Drop deposits merged potions into open corpse without creating a ground pile")
	await capture("corpse_deposit_stacks")
	check(window.take(potion) and hall_enemy.loot.items.is_empty() and hall_enemy.visible and window.visible, "Deposited corpse potion stack can be recovered and empty corpse persists")
	window.close()
	window.open(beyond)
	await frames(2)
	var existing_gold := 0
	for item in player.inventory.items:
		if item.definition == "gold":
			existing_gold = int(item.uid)
	await mouse_click(window.corpse_list.global_position + window.corpse_list.get_item_rect(1).get_center())
	await mouse_click(window.take_button.get_global_rect().get_center())
	check(player.inventory.find(existing_gold).quantity == 30 and player.inventory.find(gold).is_empty(), "Actual Take merges original 18-coin pile into skeleton's 12-coin stack")
	check(window.selected_uid == existing_gold and not window.selected_from_corpse and window.item_heading.text.contains("x30"), "Selection and preview follow surviving merged player stack")
	await capture("merged_player_stack")
	window.close()
	var corpse_gold: int = hall_enemy.loot.add_item("gold", 7)
	window.open(hall_enemy)
	await frames(2)
	await select_owned(existing_gold)
	await mouse_click(window.drop_button.get_global_rect().get_center())
	check(hall_enemy.loot.find(corpse_gold).quantity == 37 and player.inventory.find(existing_gold).is_empty(), "Actual corpse deposit merges compatible stacks in destination container")
	window.take_all()
	check(player.inventory.find(corpse_gold).quantity == 37 and hall_enemy.loot.items.is_empty() and hall_enemy.visible, "Merged corpse contents round-trip without loss and corpse remains")
	key(KEY_R)
	await frames(10)
	level = current_scene
	player = level.player
	check(get_nodes_in_group("world_loot_piles").size() == 1 and level.world_loot.authored_piles.chamber_treasure.loot.items.size() == 2 and player.inventory.items.size() == 1, "R removes dropped piles and restores authored treasure and player inventory")
	var section := preload("res://scripts/classic_section.gd").new()
	var definition: Dictionary = level.classic.section.definition.duplicate(true)
	definition.treasure_markers[0].expected_record = 16
	check(not section.validate(definition), "Schema rejects non-treasure editor marker")
	definition = level.classic.section.definition.duplicate(true)
	definition.prototype.treasure_piles[0].marker_id = "missing"
	check(not section.validate(definition), "Schema rejects unselected pile marker")
	definition = level.classic.section.definition.duplicate(true)
	definition.prototype.treasure_piles[0].test_loot[0].quantity = 0
	check(not section.validate(definition), "Schema rejects invalid pile loot quantities")
	print("WORLD LOOT RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	FileAccess.open("res://tests/world_loot_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)

