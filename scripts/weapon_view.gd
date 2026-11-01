extends TextureRect
## Native dagger overlay: DFU DaggerWeaponAnims alignment on a 320x200 canvas.
var records: Array[Dictionary] = []
var source_record := 0
var source_frame := 0
var shown := true
var actor: CharacterBody3D

func configure(data: Array[Dictionary], body: CharacterBody3D) -> void:
	records = data
	actor = body
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	set_frame(0, 0, true)

func set_frame(record: int, frame: int, show_weapon: bool) -> void:
	source_record = record
	source_frame = frame
	shown = show_weapon
	if not records.is_empty():
		texture = records[record].frames[frame]
	update_layout()

func _process(_delta: float) -> void:
	update_layout()

func update_layout() -> void:
	visible = actor.inventory.has_dagger() and not actor.modal_open and shown and not records.is_empty() and not actor.is_dead() and not actor.climbing.active
	if records.is_empty():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := viewport_size / Vector2(320, 200)
	var dimensions := Vector2(records[source_record].width, records[source_record].height)
	var left_aligned := source_record in [4, 5]
	var offset := 0.04 if source_record == 0 else 0.0
	var native_x := 0.0 if left_aligned else 320.0 * (1.0 - offset) - dimensions.x
	position = Vector2(native_x * factor.x, (200.0 - dimensions.y) * factor.y)
	size = dimensions * factor
