extends Node
## DFU's retro mode renders 16:10, then presents at 4:3 with 20% vertical stretch.
## A 4:3 camera by itself would crop horizontal content instead of matching that path.
const RETRO_RENDER_SIZE := Vector2i(640, 400)
const RETRO_DISPLAY_ASPECT := 4.0 / 3.0
var profile := "dfu_reference"
var vertical_fov := 75.0
var world_root: Node3D
var viewport: SubViewport
var display: TextureRect
var display_rect := Rect2()
var hud: Control

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("res://presentation.cfg") == OK:
		profile = config.get_value("view", "profile", profile)
		vertical_fov = clampf(float(config.get_value("view", "vertical_fov", vertical_fov)), 60, 120)
	if profile not in ["dfu_reference", "widescreen"]:
		push_warning("Unknown presentation profile; using dfu_reference")
		profile = "dfu_reference"
	viewport = SubViewport.new()
	viewport.name = "DungeonViewport"
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world_root = Node3D.new()
	world_root.name = "DungeonWorld"
	viewport.add_child(world_root)
	var canvas := CanvasLayer.new()
	canvas.layer = -10
	add_child(canvas)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(display)
	get_viewport().size_changed.connect(update_layout)
	update_layout()

func set_profile(value: String) -> void:
	assert(value in ["dfu_reference", "widescreen"])
	profile = value
	update_layout()

func update_layout() -> void:
	var available := get_viewport().get_visible_rect().size
	var size := available
	if profile == "dfu_reference":
		size.x = minf(available.x, available.y * RETRO_DISPLAY_ASPECT)
		size.y = size.x / RETRO_DISPLAY_ASPECT
		viewport.size = RETRO_RENDER_SIZE
	else:
		viewport.size = Vector2i(available)
	display_rect = Rect2((available - size) / 2, size)
	display.position = display_rect.position
	display.size = display_rect.size
	if hud:
		hud.position = display_rect.position
		hud.size = display_rect.size
