extends TextureRect
## Equipped weapon overlay: original per-weapon alignment on a 320x200 canvas.
var records: Array[Dictionary] = []
var source_record := 0
var source_frame := 0
var shown := true
var actor: CharacterBody3D
var fallback_records: Array[Dictionary] = []
var weapon_key := ""

func configure(data: Array[Dictionary], body: CharacterBody3D) -> void:
	records = data
	fallback_records = data
	actor = body
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	set_frame(0, 0, true)

func set_frame(record: int, frame: int, show_weapon: bool) -> void:
	sync_weapon()
	source_record = record
	source_frame = frame
	shown = show_weapon
	if not records.is_empty():
		texture = records[record].frames[frame]
	update_layout()

func _process(_delta: float) -> void:
	update_layout()

func update_layout() -> void:
	sync_weapon()
	visible = actor.inventory.has_weapon() and not actor.modal_open and shown and not records.is_empty() and not actor.is_dead() and not actor.climbing.active
	if records.is_empty():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := viewport_size / Vector2(320, 200)
	var dimensions := Vector2(records[source_record].width, records[source_record].height)
	var left_aligned := source_record in [4, 5]
	var offset: float = preload("res://scripts/item_catalog.gd").WEAPONS.get(weapon_key, {}).get("ready_offset", 0.0) if source_record == 0 else 0.0
	var native_x := 0.0 if left_aligned else 320.0 * (1.0 - offset) - dimensions.x
	position = Vector2(native_x * factor.x, (200.0 - dimensions.y) * factor.y)
	size = dimensions * factor

func sync_weapon() -> void:
	var key: String = actor.inventory.equipped_weapon()
	if key == weapon_key:
		return
	weapon_key = key
	var selected: Array[Dictionary] = []
	selected.assign(actor.weapon_payloads.get(key, fallback_records if key == "dagger" else []))
	records = selected
	source_record = 0
	source_frame = 0
	texture = null if records.is_empty() else records[0].frames[0]
