extends Node
## One section-local manual slot. JSON is data only; no Godot object decoding.
const Inventory = preload("res://scripts/inventory.gd")
const Catalog = preload("res://scripts/item_catalog.gd")
const SLOT := "res://saves/manual.json"
const LIMIT := 1048576
var level: Node
var slot_path := SLOT
var busy := false
var error := ""
var message: Label
var message_left := 0.0
var seen_uids: Dictionary
var max_uid := 0

func _ready() -> void:
	message = Label.new()
	message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	message.position = Vector2(29, -140)
	message.add_theme_font_size_override("font_size", 16)
	message.modulate = Color(1, 0.9, 0.65)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level.presentation.hud.add_child(message)

func _process(delta: float) -> void:
	message_left = maxf(0, message_left - delta)
	message.visible = message_left > 0

func feedback(value: String) -> void:
	error = value
	message.text = value
	message_left = 7.0
	message.show()

func fingerprint() -> String:
	return JSON.stringify(level.classic.section.definition, "", true).sha256_text()

func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func collection(owner: RefCounted) -> Dictionary:
	return {"items": owner.items.duplicate(true), "equipped_uid": owner.equipped_uid, "armor_slots": owner.armor_slots.duplicate()}

func refusal() -> String:
	var p = level.player
	if busy or not level.world_loot.initialized:
		return "Save unavailable while the section is initializing."
	if p.is_dead():
		return "Cannot save while dead. L loads your manual save."
	if p.modal_open:
		return "Close the open panel before saving."
	if p.climbing.active or not p.is_grounded():
		return "Stand on supported ground before saving."
	if Vector2(p.velocity.x, p.velocity.z).length() > 0.03 or absf(p.velocity.y) > 1.0:
		return "Stop moving before saving."
	var low: bool = p.crouch.is_low(p)
	var eye: float = p.crouch.EYE if low else p.EYE_HEIGHT
	if p.crouch.toggled != low or absf(p.crouch.eye_height - eye) > 0.002:
		return "Wait for your posture to settle before saving."
	if p.casting.owns_weapon() or (is_instance_valid(p.casting.projectiles) and p.casting.projectiles.busy()):
		return "Wait for casting to finish before saving."
	if p.combat.elapsed >= 0:
		return "Wait for the attack to finish before saving."
	for actor in level.enemies:
		if actor.melee.phase != "idle" or (actor.mobile and actor.mobile.state in ["attack", "hurt"]):
			return "Wait for combat to settle before saving."
	for door in level.doors:
		if door.busy:
			return "Wait for the door to stop before saving."
	return ""

func snapshot() -> Dictionary:
	var p = level.player
	var data := {"version": 9, "section": level.section_path, "section_hash": fingerprint(),
		"player": {"position": vector(p.position), "yaw": p.rotation.y, "pitch": p.camera.rotation.x,
		"health": p.health.current, "crouched": p.crouch.is_low(p), "sheathed": p.combat.sheathed,
		"inventory": collection(p.inventory), "character": p.character.base.duplicate(), "fatigue": p.fatigue.snapshot(), "magic":p.magic.snapshot(), "light_seconds":p.spell_effects.remaining, "shield":p.spell_effects.shield.snapshot(), "anchor":p.teleport.snapshot()}, "enemies": {}, "doors": {}, "authored": {}, "drops": []}
	for actor in level.enemies:
		data.enemies[String(actor.name)] = {"position": vector(actor.position), "yaw": actor.rotation.y,
			"health": actor.health.current, "inventory": collection(actor.loot)}
	for door in level.doors:
		data.doors[door.get_meta("section_id")] = {"opened": door.opened, "swing": door.swing_angle}
	for entry in level.classic.section.definition.prototype.get("treasure_piles", []):
		var pile = level.world_loot.authored_piles.get(entry.id)
		data.authored[entry.id] = pile_data(pile) if is_instance_valid(pile) and not pile.retired else null
	for pile in level.get_tree().get_nodes_in_group("world_loot_piles"):
		if pile.get_parent() == level.world_root and pile.dropped and not pile.retired:
			data.drops.append(pile_data(pile))
	return data

func pile_data(pile: Node3D) -> Dictionary:
	return {"id": pile.get_meta("save_id"), "position": vector(pile.position), "inventory": collection(pile.loot)}

func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

func number(value: Variant, bound: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= bound

func position_valid(value: Variant) -> bool:
	return value is Array and value.size() == 3 and number(value[0], 1000) and number(value[1], 1000) and number(value[2], 1000)

func metadata_valid(value: Variant, depth: int = 0) -> bool:
	if depth > 8:
		return false
	if value == null or value is bool:
		return true
	if value is String:
		return value.length() <= 1024
	if value is int or value is float:
		return number(value, 1000000000)
	if value is Array:
		if value.size() > 128:
			return false
		for child in value:
			if not metadata_valid(child, depth + 1):
				return false
		return true
	if value is Dictionary:
		if value.size() > 64:
			return false
		for key in value:
			if not key is String or key.length() > 128 or not metadata_valid(value[key], depth + 1):
				return false
		return true
	return false

func inventory_valid(value: Variant, player_owned: bool = false) -> bool:
	if not value is Dictionary or not value.get("items") is Array or value.items.size() > 512 or not integer(value.get("equipped_uid"), 0, 1000000000):
		return false
	var slots: Variant = value.get("armor_slots")
	if not slots is Dictionary or slots.size() != Catalog.ARMOR_SLOTS.size():
		return false
	for slot in Catalog.ARMOR_SLOTS:
		if not integer(slots.get(slot), 0, 1000000000) or (not player_owned and slots[slot] != 0):
			return false
	var equipped := int(value.equipped_uid)
	var found := equipped == 0
	var found_slots := {}
	for slot in Catalog.ARMOR_SLOTS:
		found_slots[slot] = slots[slot] == 0
	for item in value.items:
		if not item is Dictionary or not item.get("definition") is String or not Catalog.valid(item.definition):
			return false
		if not integer(item.get("uid"), 1, 1000000000) or not integer(item.get("quantity"), 1, 1000000) or not metadata_valid(item) or not Catalog.valid_material(item):
			return false
		var uid := int(item.uid)
		if seen_uids.has(uid) or (not Catalog.DEFINITIONS[item.definition].stackable and item.quantity != 1):
			return false
		seen_uids[uid] = true
		max_uid = maxi(max_uid, uid)
		if uid == equipped:
			found = player_owned and Catalog.WEAPONS.has(Catalog.DEFINITIONS[item.definition].get("weapon", ""))
		for slot in Catalog.ARMOR_SLOTS:
			if uid == int(slots[slot]):
				if not player_owned or Catalog.armor_slot(item) != slot:
					return false
				found_slots[slot] = true
	return found and not found_slots.values().has(false) and (player_owned or equipped == 0)

func actor_valid(value: Variant, maximum: int, is_player: bool = false) -> bool:
	if not value is Dictionary or not position_valid(value.get("position")) or not number(value.get("yaw"), TAU * 1000) or not integer(value.get("health"), 1 if is_player else 0, maximum):
		return false
	return inventory_valid(value.get("inventory"), is_player)

func pile_valid(value: Variant) -> bool:
	return value is Dictionary and position_valid(value.get("position")) and inventory_valid(value.get("inventory")) and not value.inventory.items.is_empty()

func validate(data: Variant) -> bool:
	seen_uids = {}
	max_uid = 0
	error = "Save data is invalid or incompatible with this section."
	if data is Dictionary and data.get("version") != 9:
		error = "Unsupported save version. Start fresh with R and create a new save with K."
		return false
	if not data is Dictionary or data.get("section") != level.section_path or data.get("section_hash") != fingerprint():
		return false
	var p = data.get("player")
	if not actor_valid(p, level.player.health.maximum, true) or not number(p.get("pitch"), PI / 2) or not p.get("crouched") is bool or not p.get("sheathed") is bool:
		return false
	if not level.player.character.valid(p.get("character"), true) or not level.player.fatigue.valid(p.get("fatigue")):
		return false
	if not level.player.magic.valid(p.get("magic")) or not level.player.spell_effects.valid(p.get("light_seconds")):
		return false
	if not level.player.spell_effects.shield.valid(p.get("shield")):
		return false
	if not level.player.teleport.valid(p.get("anchor")):
		return false
	if not data.get("enemies") is Dictionary or data.enemies.size() != level.enemies.size() or not data.get("doors") is Dictionary or data.doors.size() != level.doors.size():
		return false
	for actor in level.enemies:
		if not actor_valid(data.enemies.get(String(actor.name)), actor.health.maximum):
			return false
	for door in level.doors:
		var d = data.doors.get(door.get_meta("section_id"))
		if not d is Dictionary or not d.get("opened") is bool or not number(d.get("swing"), PI / 2 + 0.001) or not is_equal_approx(absf(d.swing), PI / 2):
			return false
	var authored: Array = level.classic.section.definition.prototype.get("treasure_piles", [])
	if not data.get("authored") is Dictionary or data.authored.size() != authored.size() or not data.get("drops") is Array or data.drops.size() > 256:
		return false
	for entry in authored:
		if not data.authored.has(entry.id):
			return false
		var pile = data.authored[entry.id]
		if pile != null and (not pile_valid(pile) or pile.get("id") != entry.id):
			return false
	var drop_ids := {}
	for pile in data.drops:
		if not pile_valid(pile) or not pile.get("id") is String:
			return false
		var id: String = pile.id
		if not id.begins_with("drop_") or not id.trim_prefix("drop_").is_valid_int() or not integer(int(id.trim_prefix("drop_")), 1, 1000000000) or drop_ids.has(id):
			return false
		drop_ids[id] = true
	error = ""
	return true

func save_slot() -> bool:
	var reason := refusal()
	if not reason.is_empty():
		feedback(reason)
		return false
	var data := snapshot()
	if not validate(data) or not placement_valid():
		if error.is_empty():
			error = "Player needs clear, supported ground before saving."
		feedback(error)
		return false
	if not write_slot(data):
		feedback("Save failed; previous slot preserved. " + error)
		return false
	feedback("Manual save complete. L loads it; R starts fresh.")
	return true

func write_slot(data: Dictionary) -> bool:
	error = "Could not replace the manual slot."
	var encoded := JSON.stringify(data, "\t")
	if encoded.to_utf8_buffer().size() > LIMIT:
		error = "Slot exceeds the 1 MiB limit."
		return false
	var path := ProjectSettings.globalize_path(slot_path)
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		error = "Cannot create save directory."
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Cannot write temporary save."
		return false
	file.store_string(encoded)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or FileAccess.get_file_as_string(path + ".tmp") != encoded:
		error = "Temporary save verification failed."
		return false
	# Retain a recoverable old slot across Windows rename failures or interruption.
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak") and DirAccess.remove_absolute(path + ".bak") != OK:
			return false
		if DirAccess.rename_absolute(path, path + ".bak") != OK:
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(path + ".bak", path)
		return false
	return true

func read_slot() -> Dictionary:
	var path := slot_path
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".bak"):
		path += ".bak"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		error = "No manual save found. Press K to save."
		return {}
	if file.get_length() > LIMIT:
		error = "Save exceeds the 1 MiB limit."
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		error = "Manual save is corrupt or truncated."
		return {}
	if not validate(parser.data):
		return {}
	return parser.data

func restore_inventory(owner: RefCounted, data: Dictionary) -> void:
	owner.items.clear()
	for item in data.items:
		var copy: Dictionary = item.duplicate(true)
		copy.uid = int(copy.uid)
		copy.quantity = int(copy.quantity)
		owner.items.append(copy)
	owner.equipped_uid = int(data.equipped_uid)
	for slot in Catalog.ARMOR_SLOTS:
		owner.armor_slots[slot] = int(data.armor_slots[slot])

func apply(data: Dictionary) -> void:
	level.player.character.set_base(data.player.character)
	level.player.character.set_live({})
	for door in level.doors:
		var state: Dictionary = data.doors[door.get_meta("section_id")]
		door.opened = state.opened
		door.swing_angle = state.swing
		door.basis = door.closed_basis * Basis(Vector3.UP, door.swing_angle if door.opened else 0.0)
	for actor in level.enemies:
		var state: Dictionary = data.enemies[String(actor.name)]
		restore_inventory(actor.loot, state.inventory)
		actor.restore_state(state)
	for entry in level.classic.section.definition.prototype.get("treasure_piles", []):
		var state = data.authored[entry.id]
		level.world_loot.authored_piles[entry.id] = null
		if state != null:
			level.world_loot.authored_piles[entry.id] = restore_pile(state, false)
	for state in data.drops:
		restore_pile(state, true)
	level.world_loot.initialized = true
	var p = level.player
	var state: Dictionary = data.player
	restore_inventory(p.inventory, state.inventory)
	p.position = Vector3(state.position[0], state.position[1], state.position[2])
	p.rotation.y = state.yaw
	p.camera.rotation.x = state.pitch
	p.health.current = int(state.health)
	p.fatigue.restore(state.fatigue)
	p.magic.restore(state.magic)
	p.casting.cancel()
	p.spell_effects.restore(float(state.light_seconds))
	p.spell_effects.shield.restore(state.shield)
	p.teleport.restore(state.anchor)
	p.combat.cancel()
	p.combat.sheathed = state.sheathed
	p.climbing.reset()
	p.falling.reset()
	p.fall_feedback_time = 0.0
	p.crouch.reset(p)
	if state.crouched:
		p.crouch.set_height(p, p.crouch.HEIGHT)
		p.crouch.toggled = true
		p.crouch.requested = true
		p.crouch.active = true
		p.crouch.eye_height = p.crouch.EYE
	p.camera.position.y = p.crouch.eye_height
	p.velocity = Vector3.ZERO
	p.flight_horizontal = Vector3.ZERO
	p.input_axes = Vector2.ZERO
	p.grounded_time = 0.0
	p.step_camera_offset = 0.0
	p.stair_supported = false
	p.interact_target = null
	p.combat.pose()

func restore_pile(data: Dictionary, dropped: bool) -> Node3D:
	var pile = level.world_loot.create_pile(Vector3(data.position[0], data.position[1], data.position[2]), dropped)
	pile.set_meta("save_id", data.id)
	restore_inventory(pile.loot, data.inventory)
	if dropped:
		level.world_loot.next_drop_id = maxi(level.world_loot.next_drop_id, int(String(data.id).trim_prefix("drop_")) + 1)
	return pile

func placement_valid() -> bool:
	var p = level.player
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = p.capsule_collision.shape
	query.transform = p.capsule_collision.global_transform
	query.collision_mask = 1
	query.exclude = [p.get_rid()]
	# A tiny inset tolerates the contact margin on supported sloping treads.
	var capsule: CapsuleShape3D = query.shape.duplicate()
	capsule.radius -= 0.015
	capsule.height -= 0.03
	query.shape = capsule
	if not p.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	var hit := PhysicsTestMotionResult3D.new()
	var steps = preload("res://scripts/step_solver.gd")
	if not steps.sweep(p, p.global_transform, Vector3.DOWN * 0.08, hit):
		return false
	for i in hit.get_collision_count():
		if hit.get_collision_normal(i).y >= cos(p.floor_max_angle):
			return true
	return false

func show_canvases(scene: Node, value: bool) -> void:
	for parent in [scene, scene.presentation]:
		for child in parent.get_children():
			if child is CanvasLayer:
				child.visible = value

func load_slot() -> bool:
	if busy:
		return false
	var data := read_slot()
	if data.is_empty():
		feedback(error)
		return false
	busy = true
	var old_uid := Inventory.next_uid
	var restored_max := max_uid
	var old_mode: ProcessMode = level.process_mode
	var old_mouse := Input.mouse_mode
	var resume_controls: bool = level.player.controls_active or level.player.is_dead()
	if level.player.modal_open:
		resume_controls = level.modal.previous_capture
	var paused_voices: Dictionary = {}
	for voice in level.combat_audio.voices:
		paused_voices[voice] = voice.stream_paused
		voice.stream_paused = true
	level.process_mode = Node.PROCESS_MODE_DISABLED
	# Preserve the selected entry scene, including isolated regression fixtures.
	var candidate = load(level.scene_file_path).instantiate()
	candidate.restoring = true
	candidate.enemy_navigation_enabled = level.enemy_navigation_enabled
	get_tree().root.add_child(candidate)
	# Keep collision bodies registered: disabling process mode removes them from
	# physics by default. The player's modal flag freezes both actor motors.
	candidate.presentation.hud.hide()
	candidate.presentation.display.hide()
	show_canvases(candidate, false)
	var success: bool = candidate.ready_to_play
	if success:
		candidate.persistence.slot_path = slot_path
		success = candidate.persistence.validate(data)
	if success:
		candidate.persistence.apply(data)
		await get_tree().physics_frame
		await get_tree().physics_frame
		success = candidate.persistence.placement_valid()
	if not success:
		candidate.queue_free()
		Inventory.next_uid = old_uid
		level.process_mode = old_mode
		Input.mouse_mode = old_mouse
		for voice in paused_voices:
			if is_instance_valid(voice):
				voice.stream_paused = paused_voices[voice]
		busy = false
		feedback("Load refused: section or player placement could not be restored safely.")
		return false
	Inventory.next_uid = restored_max + 1
	var tree := get_tree()
	tree.current_scene = candidate
	candidate.restoring = false
	candidate.player.modal_open = false
	candidate.player.controls_active = resume_controls
	candidate.presentation.hud.show()
	candidate.presentation.display.show()
	show_canvases(candidate, true)
	candidate.process_mode = Node.PROCESS_MODE_INHERIT
	# Preserve the live control preference, not the hidden candidate's defaults.
	# Captured play resumes after one L; deliberately released controls stay so.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if resume_controls else Input.MOUSE_MODE_VISIBLE
	candidate.persistence.feedback("Manual save loaded. R starts fresh." if resume_controls else "Manual save loaded. Click to resume; R starts fresh.")
	level.queue_free()
	return true



