extends Control
const Catalog = preload("res://scripts/item_catalog.gd")
var actor: CharacterBody3D
var coordinator: RefCounted
var source: Node3D
var corpse_list: ItemList
var player_list: ItemList
var previous_capture := true
var take_button: Button
var close_button: Button
var take_all_button: Button
var equip_button: Button
var use_button: Button
var drop_button: Button
var world_loot: Node
var use_feedback: Label
var title: Label
var corpse_column: VBoxContainer
var container_heading: Label
var description: Label
var selected_uid := 0
var selected_from_corpse := false
var icons: Dictionary = {}
var preview: TextureRect
var item_heading: Label
var equipment_status: Label

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
	title = Label.new()
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
		list.custom_minimum_size = Vector2(260, 200)
		list.fixed_icon_size = Vector2i(56, 28)
		list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		column.add_child(list)
		if heading == "Corpse contents":
			corpse_list = list
			corpse_column = column
			container_heading = label
			list.item_selected.connect(select_corpse_item)
		else:
			player_list = list
			list.item_selected.connect(select_player_item)
	var details := HBoxContainer.new()
	details.add_theme_constant_override("separation", 16)
	layout.add_child(details)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(128, 80)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(preview)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(text)
	item_heading = Label.new()
	item_heading.add_theme_font_size_override("font_size", 18)
	text.add_child(item_heading)
	equipment_status = Label.new()
	equipment_status.modulate = Color(0.92, 0.81, 0.6)
	text.add_child(equipment_status)
	description = Label.new()
	description.custom_minimum_size = Vector2(0, 44)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(description)
	use_feedback = Label.new()
	use_feedback.custom_minimum_size = Vector2(0, 24)
	use_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	use_feedback.modulate = Color(0.92, 0.81, 0.6)
	layout.add_child(use_feedback)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	layout.add_child(buttons)
	for caption in ["Take selected", "Take all", "Equip", "Use", "Drop", "Close (Esc / I)"]:
		var button := Button.new()
		button.text = caption
		buttons.add_child(button)
		if caption == "Take selected":
			take_button = button
			button.pressed.connect(take_selected)
		elif caption == "Take all":
			take_all_button = button
			button.pressed.connect(take_all)
		elif caption == "Equip":
			equip_button = button
			button.pressed.connect(toggle_equipment)
		elif caption == "Use":
			use_button = button
			button.pressed.connect(use_selected)
		elif caption == "Drop":
			drop_button = button
			button.pressed.connect(drop_selected)
		else:
			close_button = button
			button.pressed.connect(close)
	hide()

func open(container: Node3D) -> void:
	if visible or actor.is_dead() or not container.loot_available():
		return
	source = container
	if container.has_signal("depleted") and not container.depleted.is_connected(on_source_depleted):
		container.depleted.connect(on_source_depleted)
	begin_modal()

func open_inventory() -> void:
	if visible or actor.is_dead():
		return
	source = null
	begin_modal()

func begin_modal() -> void:
	world_loot.begin_drop_session()
	use_feedback.text = ""
	selected_uid = 0
	selected_from_corpse = false
	coordinator.open(self)
	previous_capture = coordinator.previous_capture
	show()
	refresh()
	if is_instance_valid(source):
		take_button.grab_focus()
	else:
		player_list.grab_focus()

func close() -> void:
	if not visible:
		return
	world_loot.end_drop_session()
	hide()
	coordinator.close(self)
	source = null

func refresh() -> void:
	var looting := is_instance_valid(source)
	title.text = source.loot_title() if looting else "PLAYER INVENTORY"
	container_heading.text = source.loot_label() if looting else "Pile contents"
	corpse_column.visible = looting
	take_button.visible = looting
	take_all_button.visible = looting
	corpse_list.clear()
	player_list.clear()
	if looting:
		for item in source.loot.items:
			corpse_list.add_item("%s  x%d" % [Catalog.label(item.definition), item.quantity], icons.get(item.definition))
			corpse_list.set_item_metadata(corpse_list.item_count - 1, item.uid)
			if selected_from_corpse and selected_uid == item.uid:
				corpse_list.select(corpse_list.item_count - 1)
		if corpse_list.item_count == 0:
			corpse_list.add_item("Empty")
			corpse_list.set_item_disabled(0, true)
	var dagger_number := 0
	for item in actor.inventory.items:
		# Display order distinguishes identical weapons; internal IDs stay private.
		if item.definition == "dagger":
			dagger_number += 1
		var identity := " %d" % dagger_number if item.definition == "dagger" else ""
		var quantity := "  x%d" % item.quantity if Catalog.DEFINITIONS[item.definition].stackable else ""
		player_list.add_item("%s%s%s%s" % [Catalog.label(item.definition), identity, quantity, " [equipped]" if actor.inventory.is_equipped(item.uid) else ""], icons.get(item.definition))
		var index := player_list.item_count - 1
		player_list.set_item_metadata(index, item.uid)
		if not selected_from_corpse and item.uid == selected_uid:
			player_list.select(index)
	update_details()

func select_player_item(index: int) -> void:
	use_feedback.text = ""
	selected_from_corpse = false
	corpse_list.deselect_all()
	selected_uid = int(player_list.get_item_metadata(index))
	update_details()

func select_corpse_item(index: int) -> void:
	use_feedback.text = ""
	if corpse_list.is_item_disabled(index):
		return
	selected_from_corpse = true
	player_list.deselect_all()
	selected_uid = int(corpse_list.get_item_metadata(index))
	update_details()

func update_details() -> void:
	var item: Dictionary = source.loot.find(selected_uid) if selected_from_corpse and is_instance_valid(source) else actor.inventory.find(selected_uid)
	drop_button.disabled = selected_from_corpse or item.is_empty() or actor.inventory.is_equipped(selected_uid)
	drop_button.tooltip_text = "Unequip this item before dropping." if actor.inventory.is_equipped(selected_uid) else "Drop the whole selected stack."
	use_button.disabled = selected_from_corpse or item.is_empty() or not Catalog.DEFINITIONS.get(item.get("definition", ""), {}).has("heal_amount")
	equip_button.disabled = selected_from_corpse or item.is_empty() or not Catalog.equippable(item)
	var equipped: bool = not selected_from_corpse and actor.inventory.is_equipped(selected_uid)
	equip_button.text = "Unequip" if equipped else "Equip"
	preview.texture = null
	item_heading.text = "Select an item"
	equipment_status.text = ""
	description.text = "Select an item to inspect it."
	if not item.is_empty():
		preview.texture = icons.get(item.definition)
		item_heading.text = "%s  x%d" % [Catalog.label(item.definition), item.quantity]
		equipment_status.text = source.loot_label() if selected_from_corpse else (("Equipped armor" if not Catalog.armor_slot(item).is_empty() else "Equipped weapon") if equipped else "In your inventory")
		description.text = Catalog.description(item)
		var slot := Catalog.armor_slot(item)
		if not slot.is_empty():
			var region := Catalog.ARMOR_SLOTS.find(slot)
			var protection := int((100 - actor.combat_stats.armor(actor, region)) / 5)
			description.text += "\n%s protection now: %d | Selected piece: %d" % [Catalog.SLOT_NAMES[slot], protection, Catalog.armor_protection(item)]

func toggle_equipment() -> void:
	if not visible or actor.is_dead() or equip_button.disabled:
		return
	actor.combat.cancel()
	if actor.inventory.is_equipped(selected_uid):
		actor.inventory.unequip(selected_uid)
	else:
		actor.inventory.equip(selected_uid)
	refresh()

func take_selected() -> void:
	var selected := corpse_list.get_selected_items()
	if not selected.is_empty() and not corpse_list.is_item_disabled(selected[0]):
		take(int(corpse_list.get_item_metadata(selected[0])))

func take(uid: int) -> bool:
	if not visible or not is_instance_valid(source) or actor.is_dead():
		return false
	var target_uid: int = source.loot.move_to(actor.inventory, uid)
	var moved := target_uid != 0
	if moved and selected_uid == uid:
		selected_uid = target_uid
		selected_from_corpse = false
	finish_transfer()
	return moved

func take_all() -> void:
	if not visible or not is_instance_valid(source) or actor.is_dead():
		return
	selected_from_corpse = false
	for item in source.loot.items.duplicate():
		var target_uid: int = source.loot.move_to(actor.inventory, item.uid)
		if target_uid != 0 and selected_uid == item.uid:
			selected_uid = target_uid
	finish_transfer()

func use_selected() -> void:
	if not visible or not actor.modal_open or actor.is_dead() or selected_from_corpse:
		return
	var result := preload("res://scripts/consumables.gd").use_item(actor.inventory, actor.health, selected_uid)
	refresh()
	use_feedback.text = result.message

func finish_transfer() -> void:
	# Corpses deliberately have no retire_empty method and remain inspectable.
	if is_instance_valid(source) and source.has_method("retire_empty") and source.retire_empty():
		close()
	else:
		refresh()

func drop_selected() -> void:
	if not visible or not actor.modal_open or actor.is_dead() or selected_from_corpse:
		return
	if world_loot.drop(selected_uid, source):
		selected_uid = 0
		refresh()
		use_feedback.text = "Added to the open container." if is_instance_valid(source) else "Dropped the selected item stack."
	else:
		use_feedback.text = world_loot.error

func on_source_depleted(container: Node3D) -> void:
	if source == container:
		close()

