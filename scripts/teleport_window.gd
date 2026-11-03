extends Control
var actor: CharacterBody3D
var coordinator: RefCounted
var details: Label
var anchor_button: Button
var teleport_button: Button
var close_button: Button
var choosing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.015,0.01,1)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,28)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",16)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "TELEPORT"
	title.add_theme_font_size_override("font_size",22)
	layout.add_child(title)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size",20)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(details)
	anchor_button = Button.new()
	anchor_button.text = "Anchor"
	anchor_button.pressed.connect(choose_anchor)
	layout.add_child(anchor_button)
	teleport_button = Button.new()
	teleport_button.text = "Teleport"
	teleport_button.pressed.connect(teleport)
	layout.add_child(teleport_button)
	close_button = Button.new()
	close_button.text = "Cancel (Esc)"
	close_button.pressed.connect(close)
	layout.add_child(close_button)
	hide()

func open() -> void:
	if actor.is_dead():
		return
	coordinator.open(self)
	choosing = true
	anchor_button.show()
	teleport_button.show()
	close_button.text = "Cancel (Esc)"
	details.text = "Set an Anchor or Teleport to it?\n\n" + ("An anchor exists. Setting a new one replaces it." if not actor.teleport.anchor.is_empty() else "No anchor is set.") + "\n\nTeleport consumes the anchor after arrival. Magicka has already been spent."
	show()
	anchor_button.grab_focus()

func choose_anchor() -> void:
	if not can_choose():
		return
	actor.teleport.set_anchor(actor)
	close()
	actor.casting.reject("Anchor set.")

func teleport() -> void:
	if not can_choose():
		return
	choosing = false
	var error: String = actor.teleport.arrive(actor)
	if error.is_empty():
		close()
		actor.casting.reject("Teleported. Anchor consumed.")
	else:
		details.text = error
		anchor_button.hide()
		teleport_button.hide()
		close_button.text = "Close (Esc)"
		close_button.grab_focus()

func can_choose() -> bool:
	return visible and choosing and coordinator.active == self and not actor.is_dead()

func close() -> void:
	if not visible:
		return
	choosing = false
	hide()
	coordinator.close(self)

