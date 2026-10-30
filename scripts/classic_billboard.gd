extends AnimatedSprite3D
## Decorative flat: original centre/size, transparent index zero, yaw-facing camera.
var source_archive := 0
var source_record := 0
var record_offset := 0
var original_size := Vector2.ZERO

func configure(payload: Dictionary) -> void:
	source_archive = payload.archive
	source_record = payload.record
	record_offset = payload.offset
	original_size = payload.size_metres
	position = payload.position
	name = "Billboard_" + payload.id
	set_meta("section_id", payload.id)
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pixel_size = 0.025
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	alpha_scissor_threshold = 0.5
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = source_archive != 210
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var animation := SpriteFrames.new()
	animation.set_animation_speed("default", payload.fps)
	for image in payload.frames:
		animation.add_frame("default", image)
	sprite_frames = animation
	var dimensions: Vector2 = payload.frames[0].get_size()
	scale = Vector3(original_size.x / (dimensions.x * pixel_size), original_size.y / (dimensions.y * pixel_size), 1)
	play("default")
