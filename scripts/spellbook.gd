extends Control
const Catalog = preload("res://scripts/spell_catalog.gd")
var actor: CharacterBody3D
var coordinator: RefCounted
var list: ItemList
var details: Label
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 1)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	var heading := Label.new()
	heading.text = "SPELLBOOK  |  Known spells"
	heading.add_theme_font_size_override("font_size", 22)
	layout.add_child(heading)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_font_size_override("font_size", 20)
	list.item_selected.connect(choose)
	list.item_activated.connect(activate_spell)
	layout.add_child(list)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 18)
	layout.add_child(details)
	close_button = Button.new()
	close_button.text = "Close (B / Esc)  |  Q: cast/ready selected  |  F: recast last"
	close_button.pressed.connect(close)
	layout.add_child(close_button)
	hide()

func open() -> void:
	if actor.is_dead():
		return
	coordinator.open(self)
	show()
	refresh()
	list.grab_focus()

func close() -> void:
	if not visible:
		return
	hide()
	coordinator.close(self)

func choose(index: int) -> void:
	if index >= 0 and index < actor.magic.known.size():
		actor.magic.select(actor.magic.known[index])
		refresh_details()

func activate_spell(index: int) -> void:
	if not visible or coordinator.active != self or actor.is_dead() or index < 0 or index >= actor.magic.known.size():
		return
	actor.magic.select(actor.magic.known[index])
	# Consume this GUI activation before restoring world input; its release cannot attack.
	get_viewport().set_input_as_handled()
	close()
	actor.casting.request(actor, false, true)

func refresh() -> void:
	actor.magic.sync_capacity()
	list.clear()
	for id in actor.magic.known:
		list.add_item("%s  |  %s  |  %d magicka" % [Catalog.SPELLS[id].name, str(Catalog.SPELLS[id].school).capitalize(), Catalog.cost(id, actor.character)])
		if id == actor.magic.selected:
			list.select(list.item_count - 1)
	refresh_details()

func refresh_details() -> void:
	var id: String = actor.magic.selected
	details.text = "Magicka: %d / %d\n%s\nDouble-click to cast/ready and close. LMB releases readied spells; Esc cancels. Q casts/readies after closing; F repeats your last cast." % [actor.magic.current, actor.magic.maximum(), Catalog.SPELLS[id].description if Catalog.SPELLS.has(id) else "No known spells."]
