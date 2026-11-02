extends SceneTree
const Save = preload("res://scripts/save_game.gd")
const Inventory = preload("res://scripts/inventory.gd")
var level: Node
var results: Array[String] = []
var failures: Array[String] = []
const PATH := "res://saves/test_manual.json"

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(condition: bool, label: String) -> void:
	results.append(("PASS " if condition else "FAIL ") + label)
	print(results.back())
	if not condition:
		failures.append(label)

func equivalent(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return absf(float(a) - float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not equivalent(a[i], b[i]):
				return false
		return true
	return a == b

func bind() -> void:
	level = current_scene
	level.persistence.slot_path = PATH
	for enemy in level.enemies:
		enemy.melee.enabled = false
	level.player.controls_active = false

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/" + name + ".png")

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	bind()
	await frames(15)
	var save = level.persistence
	if "--persistence-read" in OS.get_cmdline_user_args():
		check(await save.load_slot(), "Separate process loads the saved slot")
		bind()
		check(level.player.inventory.equipped_weapon() == "mace" and level.player.health.current == 63, "Cross-process player equipment and health restore")
		check(level.persistence.snapshot().drops.size() == 2 and level.world_root.get_node("hall_combat_target").health.current == 0, "Cross-process drops and corpse restore")
		finish()
		return
	var p = level.player
	var hall = level.world_root.get_node("hall_combat_target")
	check(save.refusal().is_empty(), "Settled hall spawn can save")
	p.climbing.active = true
	check(not save.save_slot() and save.error.contains("supported ground"), "Attached climbing refuses save")
	p.climbing.reset()
	p.modal_open = true
	check(not save.save_slot(), "Open inventory refuses save")
	p.modal_open = false
	p.combat.elapsed = 0.1
	check(not save.save_slot(), "Pending player attack refuses save")
	p.combat.cancel()
	hall.melee.phase = "windup"
	check(not save.save_slot(), "Pending enemy strike refuses save")
	hall.melee.cancel()
	level.door.busy = true
	check(not save.save_slot(), "Moving door refuses save")
	level.door.busy = false
	p.health.current = 0
	check(not save.save_slot(), "Dead player cannot overwrite save")
	p.health.current = 63
	hall.receive_damage(1000)
	await frames(2)
	var mace := 0
	for item in hall.loot.items.duplicate():
		if item.definition in ["mace", "healing_potion"]:
			hall.loot.transfer_to(p.inventory, item.uid)
			if item.definition == "mace":
				mace = int(item.uid)
			else:
				p.inventory.consume_one(int(item.uid))
	p.inventory.equip(mace)
	p.combat.sheathed = true
	var deposited: int = p.inventory.add_item("twigs", 4)
	p.inventory.find(deposited)["quality"] = {"origin": "save regression", "values": [1, true, "x"]}
	p.inventory.transfer_to(hall.loot, deposited)
	var treasure = level.world_loot.authored_piles.chamber_treasure
	treasure.loot.items.clear()
	treasure.retire_empty()
	for i in 2:
		level.world_loot.begin_drop_session()
		var uid: int = p.inventory.add_item("gold", 3 + i)
		check(level.world_loot.drop(uid), "Separate drop session %d creates a pile" % i)
		level.world_loot.end_drop_session()
	level.door.opened = true
	level.door.swing_angle = PI / 2
	level.door.basis = level.door.closed_basis * Basis(Vector3.UP, PI / 2)
	p.camera.rotation.x = -0.15
	await frames(3)
	check(save.save_slot(), "Changed world writes verified manual slot")
	var expected: Dictionary = save.read_slot()
	var valid_text := FileAccess.get_file_as_string(PATH)
	check(not expected.is_empty(), "Written slot validates")
	# A failed temp write must leave the complete previous slot in place.
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	check(not save.save_slot() and FileAccess.get_file_as_string(PATH) == valid_text, "Failed temporary write preserves prior valid slot")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".tmp"))
	check(save.save_slot(), "Existing manual slot can be replaced successfully")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".interrupted"))
	check(not save.read_slot().is_empty(), "Interrupted replacement can recover retained backup when main slot is missing")
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH + ".interrupted"), ProjectSettings.globalize_path(PATH))
	var regular_path: String = save.slot_path
	save.slot_path = "res://saves/absent_slot_for_test.json"
	check(not await save.load_slot() and current_scene == level, "Missing save leaves current game intact")
	save.slot_path = regular_path
	for payload in ["[]", "null", "{}", "x".repeat(1048577)]:
		FileAccess.open(PATH, FileAccess.WRITE).store_string(payload)
		check(not await save.load_slot() and current_scene == level, "Invalid root or oversized save leaves current game intact")
	FileAccess.open(PATH, FileAccess.WRITE).store_string(valid_text)
	for kind in ["version", "section", "uid", "equipment", "quantity", "position", "health", "pile", "metadata", "nonstackable"]:
		var broken := expected.duplicate(true)
		match kind:
			"version": broken.version = 999
			"section": broken.section_hash = "wrong"
			"uid": broken.drops[0].inventory.items[0].uid = broken.player.inventory.items[0].uid
			"equipment": broken.player.inventory.equipped_uid = 999999
			"quantity": broken.player.inventory.items[0].quantity = -1
			"position": broken.player.position = [0, "invalid", 0]
			"health": broken.player.health = 0
			"pile": broken.authored.erase("chamber_treasure")
			"metadata": broken.player.inventory.items[0]["extra"] = "x".repeat(1025)
			"nonstackable": broken.player.inventory.items[0].quantity = 2
		check(not save.validate(broken), "Reject invalid " + kind)
	var original_scene = level
	FileAccess.open(PATH, FileAccess.WRITE).store_string("{truncated")
	check(not await save.load_slot() and current_scene == original_scene and p.health.current == 63, "Truncated save leaves live scene intact")
	FileAccess.open(PATH, FileAccess.WRITE).store_string(valid_text)
	var blocked := expected.duplicate(true)
	blocked.player.position = [900, 900, 900]
	FileAccess.open(PATH, FileAccess.WRITE).store_string(JSON.stringify(blocked))
	var allocator := Inventory.next_uid
	check(not await save.load_slot() and current_scene == original_scene and Inventory.next_uid == allocator, "Unsupported placement rejects candidate and preserves scene/allocator")
	FileAccess.open(PATH, FileAccess.WRITE).store_string(valid_text)
	# Loading is available from death and from the shared inventory modal.
	p.health.current = 0
	p.die()
	var load_key := InputEventKey.new()
	load_key.physical_keycode = KEY_L
	load_key.pressed = true
	level._input(load_key)
	await frames(6)
	check(current_scene != original_scene, "L dispatch loads from player death")
	bind()
	save = level.persistence
	p = level.player
	level.loot_window.open_inventory()
	check(await save.load_slot(), "Manual load is available while inventory is open")
	bind()
	save = level.persistence
	p = level.player
	check(not level.loot_window.visible and level.loot_window.source == null and level.world_loot.session_pile == null, "Load discards modal source, selection and drop-session state")
	for i in 2:
		check(await save.load_slot(), "Load changed scene, pass %d" % i)
		bind()
		save = level.persistence
		p = level.player
		hall = level.world_root.get_node("hall_combat_target")
		check(equivalent(save.snapshot(), expected), "Repeated load restores identical state without item/pile duplication")
		check(hall.mobile.state == "corpse" and hall.collision_layer == 0 and hall.get_child_count() == 3, "Silent restore retains nonblocking visible corpse and interaction")
		check(level.combat_audio.voices.is_empty() and p.combat.elapsed < 0 and hall.melee.phase == "idle" and hall.navigation.memory_left == 0, "Restore has no voices, pending strikes or pursuit memory")
		check(not p.controls_active and not p.modal_open and not p.climbing.active and p.flight_horizontal == Vector3.ZERO, "Load releases mouse and clears transient motor/UI state")
		check(level.world_loot.authored_piles.chamber_treasure == null and save.snapshot().drops.size() == 2, "Empty authored treasure stays gone; overlapping piles remain separate")
	await frames(5)
	check(level.world_loot.authored_piles.chamber_treasure == null and level.persistence.snapshot().drops.size() == 2, "Delayed initialization cannot regenerate loot after load")
	# Restore a populated authored pile as well as the depleted form above.
	var with_treasure := expected.duplicate(true)
	with_treasure.authored.chamber_treasure = {"id": "chamber_treasure", "position": [19.375, 1.025, 28.6], "inventory": {"items": [{"uid": 500, "definition": "gold", "quantity": 7}], "equipped_uid": 0}}
	FileAccess.open(PATH, FileAccess.WRITE).store_string(JSON.stringify(with_treasure))
	check(await save.load_slot(), "Partly looted authored treasure loads")
	bind()
	p = level.player
	save = level.persistence
	check(level.world_loot.authored_piles.chamber_treasure.loot.items[0].quantity == 7, "Authored treasure keeps remaining quantity instead of fresh contents")
	FileAccess.open(PATH, FileAccess.WRITE).store_string(valid_text)
	check(await save.load_slot(), "Restore depleted fixture after populated-pile check")
	bind()
	p = level.player
	save = level.persistence
	var new_uid: int = p.inventory.add_item("dagger")
	check(new_uid > save.max_uid and p.inventory.find(new_uid).definition == "dagger", "New items use collision-free IDs after restore")
	p.inventory.items.erase(p.inventory.find(new_uid))
	level.loot_window.open_inventory()
	check(level.world_loot.session_pile == null, "Inventory after load begins a new drop session")
	level.loot_window.close()
	p.crouch.toggled = true
	await frames(50)
	check(save.save_slot(), "Settled crouch can save")
	check(await save.load_slot(), "Crouched player placement loads")
	bind()
	p = level.player
	save = level.persistence
	check(p.crouch.is_low(p) and p.crouch.toggled and is_equal_approx(p.camera.position.y, 0.81), "Crouch capsule, toggle and eye restore together")
	# An empty corpse still gets its interaction target and visible original sprite.
	var empty_corpse: Dictionary = save.snapshot()
	empty_corpse.enemies.hall_combat_target.inventory.items = []
	FileAccess.open(PATH, FileAccess.WRITE).store_string(JSON.stringify(empty_corpse))
	check(await save.load_slot(), "Empty corpse snapshot loads")
	bind()
	hall = level.world_root.get_node("hall_combat_target")
	check(hall.loot_available() and hall.loot.items.is_empty() and hall.mobile.visible and hall.collision_layer == 0, "Empty corpse remains visible, inspectable and nonblocking")
	level.loot_window.open(hall)
	check(level.loot_window.visible and level.loot_window.corpse_list.get_item_text(0) == "Empty", "Loaded empty corpse opens the normal loot window")
	level.loot_window.close()
	# Real key dispatch uses the root viewport path and consumes the save key.
	await frames(3)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_K
	event.pressed = true
	level._input(event)
	check(level.persistence.error.contains("complete"), "K dispatch saves without world input forwarding")
	await capture("persistence_crouched_4_3")
	level.presentation.set_profile("widescreen")
	await capture("persistence_crouched_widescreen")
	# Keep the standing changed-world slot for the separate-process read check.
	FileAccess.open(PATH, FileAccess.WRITE).store_string(valid_text)
	var before_restart := FileAccess.get_file_as_string(PATH)
	reload_current_scene()
	await frames(12)
	bind()
	check(level.player.inventory.items.size() == 1 and level.world_root.get_node("hall_combat_target").health.current > 0 and level.world_loot.authored_piles.chamber_treasure != null, "Fresh restart restores authored world")
	check(FileAccess.get_file_as_string(PATH) == before_restart, "Restart leaves manual save untouched")
	finish()

func finish() -> void:
	print("PERSISTENCE RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	var report := "res://tests/persistence_cross_process_results.txt" if "--persistence-read" in OS.get_cmdline_user_args() else "res://tests/persistence_results.txt"
	FileAccess.open(report, FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)


