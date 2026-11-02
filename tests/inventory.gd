extends "res://tests/climbing.gd"
var level: Node3D
var hall: CharacterBody3D
var window: Control

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	level._input(event)

func aim(distance: float = 1.5) -> void:
	player.climbing.reset()
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.position = hall.position + Vector3(0, 0, distance)
	player.camera.look_at(hall.global_position + Vector3.UP * 0.25)
	player.update_interaction()

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + name + ".png")

func mouse_click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(10)
	player = level.player
	hall = level.world_root.get_node("hall_combat_target")
	hall.melee.enabled = false
	window = level.loot_window
	arena = level.world_root
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/items/icon_frames.json"))
	for id in ["dagger", "gold", "twigs", "healing_potion"]:
		var icon: Texture2D = level.classic.item_icons[id]
		var expected: Dictionary = fixture.icons[id]
		var rgba := icon.get_image().get_data()
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(rgba)
		check(icon.get_size() == Vector2(expected.pixels[0], expected.pixels[1]) and context.finish().hex_encode() == expected.rgba_sha256, "%s original icon dimensions and RGBA match independent source audit" % id)
		var transparent := 0
		for pixel in range(3, rgba.size(), 4):
			if rgba[pixel] == 0:
				transparent += 1
		check(transparent == expected.transparent_pixels, "%s original icon transparent background matches source audit" % id)
	var decoder := preload("res://scripts/classic_data.gd").new()
	decoder.palette = level.classic.palette
	decoder.texture_archives[254] = PackedByteArray([0, 0])
	check(decoder.read_texture(254, 9, 0, true, true) == null, "Truncated inventory archive fails safely")
	check(not preload("res://scripts/item_catalog.gd").valid("bone") and hall.loot.items[1].definition == "twigs", "Authored test loot uses real Twigs ingredient instead of invented bone item")
	var consumables := preload("res://scripts/consumables.gd")
	var isolated_health := preload("res://scripts/health.gd").new()
	var isolated_inventory := preload("res://scripts/inventory.gd").new()
	var isolated_potion: int = isolated_inventory.add_item("healing_potion", 2)
	var outcome: Dictionary = consumables.use_item(isolated_inventory, isolated_health, isolated_potion)
	check(outcome.healed == 0 and isolated_inventory.find(isolated_potion).quantity == 2, "Full-health potion use keeps both doses")
	isolated_health.current = 2
	outcome = consumables.use_item(isolated_inventory, isolated_health, isolated_potion)
	check(outcome.healed == 25 and isolated_health.current == 27 and isolated_inventory.find(isolated_potion).quantity == 1, "Potion service restores prototype 25 health and consumes exactly one dose")
	outcome = consumables.use_item(isolated_inventory, isolated_health, isolated_potion)
	check(outcome.healed == 3 and isolated_health.current == 30 and isolated_inventory.find(isolated_potion).is_empty(), "Final dose clamps to maximum health and removes exhausted stack")
	outcome = consumables.use_item(isolated_inventory, isolated_health, isolated_potion)
	check(outcome.healed == 0 and isolated_inventory.items.is_empty(), "Stale consumed UID cannot heal or create items")
	isolated_potion = isolated_inventory.add_item("healing_potion")
	isolated_health.current = 0
	check(consumables.use_item(isolated_inventory, isolated_health, isolated_potion).healed == 0 and isolated_inventory.find(isolated_potion).quantity == 1 and isolated_health.restore(25) == 0, "Dead actors cannot consume healing potion or be revived by restore")
	isolated_health.current = 10
	var isolated_dagger: int = isolated_inventory.add_item("dagger")
	isolated_inventory.equip(isolated_dagger)
	check(consumables.use_item(isolated_inventory, isolated_health, isolated_dagger).healed == 0 and not isolated_inventory.consume_one(isolated_dagger), "Nonconsumable equipped dagger cannot be used or consumed")
	check(consumables.use_item(isolated_inventory, isolated_health, -1).healed == 0 and isolated_health.restore(-5) == 0, "Unknown items and nonpositive healing are rejected")
	check(player.inventory.items.size() == 1 and player.inventory.has_dagger(), "Fresh player owns exactly one equipped dagger")
	var dagger: int = player.inventory.equipped_uid
	var other := preload("res://scripts/inventory.gd").new()
	check(not player.inventory.transfer_to(other, dagger), "Equipped item cannot leave its owner")
	check(not other.equip(dagger), "Equipment cannot reference another inventory")
	check(other.add_item("unknown") == 0 and other.add_item("dagger", 2) == 0 and other.add_item("gold", 0) == 0, "Invalid definitions and quantities rejected")
	player.inventory.equipped_uid = 0
	check(not player.combat.request_attack(player), "No equipped weapon prevents attack")
	player.combat.toggle_sheath()
	check(not player.combat.sheathed, "No equipped weapon prevents draw toggle")
	check(player.inventory.equip(dagger), "Owned dagger can be equipped again")
	check(player.combat.request_attack(player), "Equipped dagger permits existing attack")
	player.combat.cancel()
	check(hall.loot.items.size() == 4 and not level.enemy.loot_enabled, "Only hall skeleton has authored test loot")
	window.open(hall)
	check(not window.visible, "Living target cannot open loot")
	hall.receive_damage(1000)
	await frames(2)
	check(hall.collision_layer == 0 and hall.collision_mask == 0 and hall.mobile.state == "corpse", "Loot corpse stays visible and physically nonblocking")
	aim()
	check(player.interact_target is Area3D, "Nearby corpse can be targeted by interaction ray")
	aim(4.0)
	check(player.interact_target == null, "Distant corpse cannot be targeted")
	aim()
	var barrier := box(Vector3(2, 3, 0.15), hall.position + Vector3(0, 1.5, 0.7))
	await frames(2)
	player.update_interaction()
	check(player.interact_target == null, "Solid wall blocks corpse selection")
	barrier.queue_free()
	await frames(2)
	aim()
	# Prove doors and corpses compete by first obstruction on the same ray.
	var door: AnimatableBody3D = level.door
	var original := door.global_transform
	door.position = hall.position + Vector3(-0.6, 0, 0.7)
	door.basis = Basis.IDENTITY
	await frames(2)
	aim()
	check(player.interact_target == door, "Closed door in front of corpse retains interaction priority")
	door.global_transform = original
	await frames(2)
	aim()
	var combat = player.combat
	combat.request_attack(player)
	var passive = level.enemy
	passive.melee.phase = "windup"
	passive.melee.remaining = 0.001
	key(KEY_E)
	check(window.visible and player.modal_open and not player.controls_active, "E opens modal loot window and releases gameplay controls")
	check(combat.elapsed < 0 and passive.melee.phase == "idle", "Opening cancels pending player and enemy strikes immediately")
	var at := player.position
	passive.navigation.enabled = true
	passive.navigation.observe(player.position)
	var memory: float = passive.navigation.memory_left
	var enemy_at: Vector3 = passive.position
	var health: int = player.health.current
	Input.action_press("forward")
	await frames(40)
	Input.action_release("forward")
	check(player.position == at and passive.position == enemy_at and player.health.current == health, "Modal freezes player movement and enemy simulation")
	check(not combat.request_attack(player), "Modal rejects combat requests")
	check(passive.navigation.memory_left == memory, "Modal freezes enabled pursuit memory and steering")
	await mouse_click(window.corpse_list.get_global_rect().position + Vector2(30, 17))
	check(not window.corpse_list.get_selected_items().is_empty(), "Actual pointer click selects a corpse row")
	check(window.preview.texture == level.classic.item_icons.gold and window.equipment_status.text == "Corpse contents", "Corpse selection previews original gold icon and ownership")
	check(window.equip_button.disabled, "Corpse preview cannot equip an unowned item")
	await mouse_click(window.corpse_list.global_position + window.corpse_list.get_item_rect(2).get_center())
	var potion_uid: int = hall.loot.items[2].uid
	var potion_health: int = player.health.current
	window.use_selected()
	check(window.use_button.disabled and window.preview.texture == level.classic.item_icons.healing_potion and hall.loot.find(potion_uid).quantity == 2 and player.health.current == potion_health, "Unowned corpse potion previews correctly but cannot be used")
	await mouse_click(window.corpse_list.global_position + window.corpse_list.get_item_rect(1).get_center())
	check(window.preview.texture == level.classic.item_icons.twigs and window.item_heading.text.contains("Twigs"), "Twigs corpse row shows matching ingredient preview")
	await capture("loot_twigs")
	await mouse_click(window.corpse_list.global_position + window.corpse_list.get_item_rect(0).get_center())
	await capture("loot_4_3")
	key(KEY_F2)
	await capture("loot_widescreen")
	check(level.presentation.profile == "widescreen" and window.visible, "Presentation can toggle while modal remains open")
	var uid: int = hall.loot.items[0].uid
	await mouse_click(window.take_button.get_global_rect().get_center())
	check(not player.inventory.find(uid).is_empty(), "Actual Take selected button transfers item into player ownership")
	check(not window.take(uid) and not player.inventory.find(uid).is_empty() and hall.loot.find(uid).is_empty(), "Repeated stale transfer cannot duplicate item")
	key(KEY_ESCAPE)
	check(not window.visible and not player.modal_open and player.controls_active, "Escape closes and restores captured controls")
	check(combat.elapsed < 0, "Closing leaves attack cancelled")
	aim()
	key(KEY_E)
	check(window.visible and hall.loot.items.size() == 3, "Reopening preserves remaining loot")
	await mouse_click(window.take_all_button.get_global_rect().get_center())
	window.take_all()
	await frames(2)
	check(hall.loot.items.is_empty() and player.inventory.items.size() == 5, "Take All is repeat-safe and empties corpse")
	var second_dagger: int = player.inventory.items[-1].uid
	check(second_dagger != dagger and player.inventory.items[-1].definition == "dagger", "Looted dagger has its own owned identity")
	await mouse_click(window.player_list.global_position + window.player_list.get_item_rect(4).get_center())
	check(window.player_list.get_item_icon(4) == level.classic.item_icons.dagger and window.preview.texture == level.classic.item_icons.dagger and window.equipment_status.text == "In your inventory", "Looted dagger row and preview use cached original icon before equip")
	check(window.selected_uid == second_dagger, "Actual pointer selects the distinct looted dagger")
	await mouse_click(window.equip_button.get_global_rect().get_center())
	check(player.inventory.equipped_uid == second_dagger and player.inventory.items.size() == 5, "Equip looted dagger replaces equipment reference without duplicating items")
	await mouse_click(window.player_list.global_position + window.player_list.get_item_rect(1).get_center())
	check(window.equip_button.disabled and window.description.text.contains("currency"), "Nonweapon selection shows description and disables equipment action")
	check(window.preview.texture == level.classic.item_icons.gold and window.equipment_status.text == "In your inventory", "Player gold preview retains correct icon and ownership after transfer")
	await mouse_click(window.player_list.global_position + window.player_list.get_item_rect(3).get_center())
	check(not window.use_button.disabled and window.equip_button.disabled, "Owned potion enables Use and disables Equip")
	await mouse_click(window.use_button.get_global_rect().get_center())
	check(player.health.current == player.health.maximum and player.inventory.find(potion_uid).quantity == 2 and window.use_feedback.text.contains("Potion kept"), "Actual Use at full health keeps potion with clear feedback")
	await capture("potion_full_health")
	player.receive_damage(65)
	await mouse_click(window.use_button.get_global_rect().get_center())
	check(player.health.current == 60 and player.inventory.find(potion_uid).quantity == 1 and window.use_feedback.text == "Restored 25 health.", "Actual Use in loot window heals and decrements exactly one dose")
	check(player.modal_open and player.combat.elapsed < 0 and player.inventory.equipped_uid == second_dagger, "Healing keeps modal suspension and weapon equipment intact")
	await capture("potion_loot_4_3")
	await mouse_click(window.player_list.global_position + window.player_list.get_item_rect(1).get_center())
	await capture("loot_empty")
	await mouse_click(window.close_button.get_global_rect().get_center())
	check(not window.visible and player.controls_active and combat.elapsed < 0, "Actual Close click restores controls without starting an attack")
	key(KEY_I)
	await frames(2)
	player.health.restore(35)
	await mouse_click(window.player_list.global_position + window.player_list.get_item_rect(3).get_center())
	key(KEY_F2)
	await capture("potion_inventory_4_3")
	key(KEY_F2)
	await capture("potion_inventory_widescreen")
	await mouse_click(window.use_button.get_global_rect().get_center())
	check(player.health.current == 100 and player.inventory.find(potion_uid).is_empty() and window.use_feedback.text == "Restored 5 health.", "Standalone Use clamps partial healing and removes last potion")
	check(window.use_button.disabled and window.preview.texture == null, "Exhausted potion clears preview and disables Use")
	window.use_selected()
	check(player.health.current == 100 and player.inventory.items.size() == 4, "Repeated stale Use cannot consume another item or heal twice")
	key(KEY_I)
	await frames(2)
	aim()
	key(KEY_E)
	check(window.visible and window.corpse_list.get_item_text(0) == "Empty", "Empty corpse remains inspectable")
	await mouse_click(Vector2(20, 20), MOUSE_BUTTON_RIGHT)
	check(window.visible and not player.controls_active and combat.elapsed < 0, "Outside RMB click cannot recapture controls or attack through modal")
	window.close()
	passive.navigation.enabled = false
	player.controls_active = false
	window.open(hall)
	window.close()
	check(not player.controls_active, "Close preserves pre-existing released controls")
	player.controls_active = true
	window.open(hall)
	player.receive_damage(1000)
	check(not window.visible and not player.modal_open and not player.controls_active, "Death closes modal without recapturing controls")
	key(KEY_R)
	await frames(5)
	level = current_scene
	player = level.player
	hall = level.world_root.get_node("hall_combat_target")
	check(player.inventory.items.size() == 1 and player.inventory.has_dagger() and hall.loot.items.size() == 4 and hall.health.current > 0, "Scene restart restores clean inventory, equipment, living skeleton and loot")
	hall.receive_damage(1000)
	await frames(2)
	level.loot_window.open(hall)
	level.loot_window.take_all()
	key(KEY_R)
	await frames(5)
	level = current_scene
	player = level.player
	hall = level.world_root.get_node("hall_combat_target")
	check(not player.modal_open and player.inventory.items.size() == 1 and hall.loot.items.size() == 4 and hall.health.current > 0, "Actual R while looting restores a clean playable scene")
	window = level.loot_window
	player.combat.request_attack(player)
	key(KEY_I)
	await frames(2)
	check(player.combat.elapsed < 0, "Standalone inventory cancels a pending strike")
	check(window.visible and not window.corpse_column.visible and player.modal_open, "I opens standalone inventory without a corpse")
	await mouse_click(window.player_list.global_position + window.player_list.get_item_rect(0).get_center())
	check(window.preview.texture == level.classic.item_icons.dagger and window.equipment_status.text == "Equipped weapon", "Standalone preview clearly marks equipped original dagger")
	check(not window.equip_button.disabled and window.equip_button.text == "Unequip" and not window.description.text.is_empty(), "Selected equipped dagger shows description and Unequip action")
	await mouse_click(window.equip_button.get_global_rect().get_center())
	check(not player.inventory.has_dagger(), "Actual Unequip button clears equipped state")
	await capture("inventory_4_3")
	key(KEY_I)
	await frames(2)
	await frames(2)
	check(not window.visible and not player.combat.request_attack(player) and not player.combat.weapon.visible, "I closes inventory and unequipped weapon stays hidden and cannot attack")
	key(KEY_I)
	await frames(2)
	await mouse_click(window.player_list.global_position + window.player_list.get_item_rect(0).get_center())
	await mouse_click(window.equip_button.get_global_rect().get_center())
	key(KEY_F2)
	await capture("inventory_widescreen")
	key(KEY_ESCAPE)
	check(player.inventory.has_dagger() and player.combat.request_attack(player), "Re-equipping through standalone inventory restores attack availability")
	player.combat.cancel()
	player.controls_active = false
	key(KEY_I)
	await frames(2)
	key(KEY_I)
	await frames(2)
	check(not player.controls_active, "Inventory I toggle preserves previously released controls")
	player.controls_active = true
	var section := preload("res://scripts/classic_section.gd").new()
	var definition: Dictionary = level.classic.section.definition.duplicate(true)
	definition.prototype.enemies[1].test_loot[0].definition = "unknown"
	check(not section.validate(definition), "Schema rejects unknown loot definitions")
	definition = level.classic.section.definition.duplicate(true)
	definition.prototype.enemies[1].test_loot[0].quantity = 0
	check(not section.validate(definition), "Schema rejects invalid loot quantities")
	definition = level.classic.section.definition.duplicate(true)
	definition.prototype.enemies[1].test_loot = [{"definition": "dagger", "quantity": 2}]
	check(not section.validate(definition), "Schema rejects stacked nonstackable items")
	player.receive_damage(1000)
	key(KEY_I)
	check(not window.visible and not player.modal_open, "Dead player cannot open standalone inventory")
	print("INVENTORY RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	FileAccess.open("res://tests/inventory_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)
