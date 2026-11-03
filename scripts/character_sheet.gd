extends Control
var actor: CharacterBody3D
var coordinator: RefCounted
var details: RichTextLabel
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var heading := Label.new()
	heading.text = "CHARACTER  |  Read-only test character"
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)
	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.focus_mode = Control.FOCUS_ALL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("normal_font_size", 17)
	layout.add_child(details)
	close_button = Button.new()
	close_button.text = "Close (C / Esc)  |  I: inventory"
	close_button.pressed.connect(close)
	layout.add_child(close_button)
	hide()

func open() -> void:
	if actor.is_dead():
		return
	coordinator.open(self)
	refresh()
	show()
	details.grab_focus()

func close() -> void:
	if not visible:
		return
	hide()
	coordinator.close(self)

func refresh() -> void:
	actor.fatigue.sync_capacity()
	var lines: Array[String] = ["[b]Health: %d / %d[/b]" % [actor.health.current, actor.health.maximum], "Fatigue: %.1f / %.1f" % [actor.fatigue.current / 64.0, actor.fatigue.maximum() / 64.0], "", "[b]Attributes[/b]"]
	actor.magic.sync_capacity()
	lines.insert(2, "Magicka: %d / %d" % [actor.magic.current, actor.magic.maximum()])
	for key in ["strength", "intelligence", "willpower", "agility", "endurance", "personality", "speed", "luck"]:
		var unused: bool = key in ["willpower", "personality"]
		lines.append("%s: %.1f%s" % [key.capitalize(), actor.character.stat(key), " (no gameplay consumer yet)" if unused else ""])
	lines.append("\n[b]Skills[/b]")
	for key in ["short_blade", "blunt_weapon", "hand_to_hand", "dodging", "critical_strike", "medical", "restoration", "illusion", "destruction", "running", "jumping", "swimming", "climbing"]:
		var note := ""
		if key == "hand_to_hand": note = " (input hook; unarmed attacks unavailable)"
		if key == "swimming": note = " (speed hook only)"
		if key == "climbing": note = " (success/slip checks deferred)"
		lines.append("%s: %.1f%s" % [key.capitalize(), actor.character.stat(key), note])
	lines.append("\n[b]Equipment and protection[/b]")
	var catalog = preload("res://scripts/item_catalog.gd")
	var weapon: Dictionary = actor.inventory.find(actor.inventory.equipped_uid)
	lines.append("Weapon: %s" % ((str(weapon.get("material", "")).capitalize() + " " + catalog.label(weapon.definition)).strip_edges() if not weapon.is_empty() else "None"))
	for region in catalog.ARMOR_SLOTS.size():
		var slot: String = catalog.ARMOR_SLOTS[region]
		var armor: Dictionary = actor.inventory.find(actor.inventory.armor_slots[slot])
		var protection := int((100 - actor.combat_stats.armor(actor, region)) / 5)
		lines.append("%s protection: %d | %s" % [catalog.SLOT_NAMES[slot], protection, catalog.label(armor.definition) if not armor.is_empty() else "None"])
	var motion: Dictionary = actor.movement.resolve()
	lines.append("\nWalk %.3f m/s | Run %.3f m/s | Jump %.3f m/s" % [motion.walk_speed, motion.run_speed, motion.jump_velocity])
	lines.append("Protection: higher is better; applies only to the listed region.\nT opens rest. B opens spells. Q casts; F recasts. Progression is not implemented.")
	details.text = "\n".join(lines)

