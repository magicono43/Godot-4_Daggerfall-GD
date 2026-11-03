extends Control
var actor: CharacterBody3D
var coordinator: RefCounted
var rest := preload("res://scripts/rest_controller.gd").new()
var details: Label
var hours: SpinBox
var timed_button: Button
var full_button: Button
var stop_button: Button
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
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "REST  |  Recover health, fatigue and magicka"
	title.add_theme_font_size_override("font_size", 22)
	layout.add_child(title)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_font_size_override("font_size", 18)
	layout.add_child(details)
	var row := HBoxContainer.new()
	layout.add_child(row)
	var label := Label.new()
	label.text = "Hours: "
	row.add_child(label)
	hours = SpinBox.new()
	hours.min_value = 1
	hours.max_value = 24
	hours.value = 1
	row.add_child(hours)
	timed_button = Button.new()
	timed_button.text = "Rest selected hours"
	timed_button.pressed.connect(func(): start_rest(false))
	row.add_child(timed_button)
	full_button = Button.new()
	full_button.text = "Rest until recovered (up to 24h)"
	full_button.pressed.connect(func(): start_rest(true))
	layout.add_child(full_button)
	stop_button = Button.new()
	stop_button.text = "Stop resting"
	stop_button.pressed.connect(stop_rest)
	layout.add_child(stop_button)
	close_button = Button.new()
	close_button.text = "Close (T / Esc)  |  C: character  |  I: inventory"
	close_button.pressed.connect(close)
	layout.add_child(close_button)
	hide()

func open() -> void:
	if actor.is_dead():
		return
	coordinator.open(self)
	rest.stop("Choose a rest duration.")
	rest.hours_completed = 0
	show()
	refresh()
	close_button.grab_focus()

func close() -> void:
	if not visible:
		return
	rest.stop()
	hide()
	coordinator.close(self)

func stop_rest() -> void:
	rest.stop()
	refresh()

func start_rest(full: bool) -> void:
	if not visible or coordinator.active != self:
		return
	rest.start(24 if full else int(hours.value), full)
	refresh()
	if rest.active:
		stop_button.grab_focus()

func _process(delta: float) -> void:
	if visible and coordinator.active == self:
		rest.tick(delta)
		refresh()

func refresh() -> void:
	actor.fatigue.sync_capacity()
	var reason := rest.refusal()
	var blocked := not reason.is_empty()
	if reason == rest.message:
		reason = ""
	details.text = "Health: %d / %d\nFatigue: %.1f / %.1f\n\nPer hour: +%d health, +%.1f fatigue\nHours completed: %d%s\n\n%s\n%s\n\nRecovery is awarded after each completed hour. Closing or switching panels stops rest.\nNearby living enemies prevent rest. No random encounters are added in this prototype." % [actor.health.current, actor.health.maximum, actor.fatigue.current / 64.0, actor.fatigue.maximum() / 64.0, actor.fatigue.health_recovery(actor.health.maximum), actor.fatigue.fatigue_recovery() / 64.0, rest.hours_completed, " | Remaining: %d" % rest.hours_left if rest.active else "", rest.message, reason]
	details.text += "\nMagicka: %d / %d | +%d per completed hour" % [actor.magic.current, actor.magic.maximum(), actor.magic.recovery()]
	timed_button.disabled = rest.active or blocked or rest.recovered()
	full_button.disabled = timed_button.disabled
	hours.editable = not rest.active
	stop_button.disabled = not rest.active
