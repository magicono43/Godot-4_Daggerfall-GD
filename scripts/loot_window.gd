extends Control
const Catalog = preload("res://scripts/item_catalog.gd")
var actor: CharacterBody3D
var source: CharacterBody3D
var corpse_list: ItemList
var player_list: ItemList
var previous_capture := true
var take_button: Button
var close_button: Button
var take_all_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(590, 360)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var title := Label.new()
	title.text = "SKELETON REMAINS  |  Prototype test loot"
	title.add_theme_font_size_override("font_size", 20)
	layout.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	for heading in ["Corpse contents", "Player inventory"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		var label := Label.new()
		label.text = heading
		column.add_child(label)
		var list := ItemList.new()
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.custom_minimum_size = Vector2(260, 220)
		column.add_child(list)
		if heading == "Corpse contents":
			corpse_list = list
		else:
			player_list = list
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	layout.add_child(buttons)
	for caption in ["Take selected", "Take all", "Close (Esc)"]:
		var button := Button.new()
		button.text = caption
		buttons.add_child(button)
		if caption == "Take selected":
			take_button = button
			button.pressed.connect(take_selected)
		elif caption == "Take all":
			take_all_button = button
			button.pressed.connect(take_all)
		else:
			close_button = button
			button.pressed.connect(close)
	hide()

func open(corpse: CharacterBody3D) -> void:
	if visible or actor.is_dead() or corpse.health.current > 0 or not corpse.loot_enabled:
		return
	source = corpse
	previous_capture = actor.controls_active
	actor.modal_open = true
	actor.controls_active = false
	actor.combat.cancel()
	# Clear pending strikes before any enemy can consume its animation event.
	for enemy in get_tree().get_nodes_in_group("prototype_enemies"):
		enemy.suspend_for_modal()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	refresh()
	take_button.grab_focus()

func close() -> void:
	if not visible:
		return
	hide()
	actor.modal_open = false
	actor.controls_active = previous_capture and not actor.is_dead()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if actor.controls_active else Input.MOUSE_MODE_VISIBLE
	source = null

func refresh() -> void:
	corpse_list.clear()
	player_list.clear()
	for item in source.loot.items:
		corpse_list.add_item("%s  x%d" % [Catalog.label(item.definition), item.quantity])
		corpse_list.set_item_metadata(corpse_list.item_count - 1, item.uid)
	if corpse_list.item_count == 0:
		corpse_list.add_item("Empty")
		corpse_list.set_item_disabled(0, true)
	for item in actor.inventory.items:
		player_list.add_item("%s  x%d%s" % [Catalog.label(item.definition), item.quantity, " [equipped]" if item.uid == actor.inventory.equipped_uid else ""])

func take_selected() -> void:
	var selected := corpse_list.get_selected_items()
	if not selected.is_empty() and not corpse_list.is_item_disabled(selected[0]):
		take(int(corpse_list.get_item_metadata(selected[0])))

func take(uid: int) -> bool:
	if not visible or not is_instance_valid(source) or actor.is_dead():
		return false
	var moved: bool = source.loot.transfer_to(actor.inventory, uid)
	refresh()
	return moved

func take_all() -> void:
	if not visible or not is_instance_valid(source) or actor.is_dead():
		return
	for item in source.loot.items.duplicate():
		source.loot.transfer_to(actor.inventory, item.uid)
	refresh()
