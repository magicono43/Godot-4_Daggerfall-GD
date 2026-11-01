extends Sprite3D
## Original mobile records, physics-clock animation, camera-relative eight-way view.
const ORIENTATION_RECORDS := [0, 1, 2, 3, 4, 3, 2, 1]
const ATTACK_FPS := 10.0
const ATTACK_HIT_FRAME := 4
const ATTACK_FRAMES := 6
var payload: Dictionary
var state := "idle"
var elapsed := 0.0
var strike_pending := false
var strike_emitted := false
var orientation := 0
var source_record := 15
var source_frame := 0

func configure(data: Dictionary) -> void:
	payload = data
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pixel_size = 0.025
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	alpha_scissor_threshold = 0.5
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	refresh()

func set_state(value: String) -> void:
	state = value
	elapsed = 0.0
	strike_pending = false
	strike_emitted = false
	refresh()

func tick(delta: float) -> void:
	elapsed += delta
	if state == "attack":
		# DFU's [0,1,2,3,-1,4,5] marker enters frame 4 at 10 fps.
		if not strike_emitted and elapsed + 0.000001 >= ATTACK_HIT_FRAME / ATTACK_FPS:
			strike_pending = true
			strike_emitted = true
		if elapsed + 0.000001 >= ATTACK_FRAMES / ATTACK_FPS:
			state = "idle"
	elif state == "hurt" and elapsed >= 0.25:
		set_state("idle")
	refresh()

func consume_strike() -> bool:
	var result := strike_pending
	strike_pending = false
	return result

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		select_view(camera.global_position)

func select_view(camera_position: Vector3) -> void:
	var body := get_parent() as Node3D
	var local := body.global_basis.inverse() * (camera_position - body.global_position)
	# Godot forward is -Z. Right-side views use DFU's mirrored records.
	orientation = posmod(roundi(atan2(-local.x, -local.z) / (PI / 4.0)), 8)
	refresh()

func refresh() -> void:
	if payload.is_empty():
		return
	var record: Dictionary
	if state == "corpse":
		record = payload.corpse
		source_record = 1
		source_frame = 0
		flip_h = false
	else:
		var base := 5 if state == "attack" else (10 if state == "hurt" else (0 if state == "move" else 15))
		source_record = base + int(ORIENTATION_RECORDS[orientation])
		record = payload.records[source_record]
		source_frame = mini(int((elapsed + 0.000001) * ATTACK_FPS), ATTACK_FRAMES - 1) if state == "attack" else 0
		if state == "move":
			source_frame = int(elapsed * 6.0) % 4
		flip_h = orientation > 4
	texture = record.frames[source_frame]
	var dimensions: Vector2 = texture.get_size()
	var metres: Vector2 = record.size_metres
	scale = Vector3(metres.x / (dimensions.x * pixel_size), metres.y / (dimensions.y * pixel_size), 1)
	position.y = metres.y * 0.5
