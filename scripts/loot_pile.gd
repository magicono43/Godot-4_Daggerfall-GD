extends Area3D
## Noncorpse loot: nonsolid, original billboard, removed immediately when exhausted.
var loot := preload("res://scripts/inventory.gd").new()
var player: CharacterBody3D
var payload: Dictionary
var dropped := false
var retired := false
var sprite: Sprite3D
signal depleted(container: Node3D)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	add_to_group("world_loot_piles")
	loot.changed.connect(on_contents_changed)
	sprite = Sprite3D.new()
	sprite.texture = payload.frames[0]
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.pixel_size = 0.025
	var dimensions: Vector2 = payload.size_metres
	var pixels: Vector2 = sprite.texture.get_size()
	sprite.scale = Vector3(dimensions.x / (pixels.x * sprite.pixel_size), dimensions.y / (pixels.y * sprite.pixel_size), 1)
	sprite.position.y = dimensions.y * 0.5
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(dimensions.x, 0.3), maxf(dimensions.y, 0.25), 0.4)
	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	add_child(collision)

func interact() -> void:
	if loot_available():
		player.loot_requested.emit(self)

func loot_available() -> bool:
	return not retired and not loot.items.is_empty()

func loot_title() -> String:
	return "DROPPED ITEMS" if dropped else "DUNGEON TREASURE  |  Prototype test loot"

func loot_label() -> String:
	return "Pile contents"

func retire_empty() -> bool:
	if retired:
		return true
	if not loot.items.is_empty():
		return false
	retired = true
	collision_layer = 0
	hide()
	remove_from_group("world_loot_piles")
	depleted.emit(self)
	queue_free()
	return true

func on_contents_changed() -> void:
	if loot.items.is_empty():
		# Deferred for multi-item transfer transactions; UI can retire immediately.
		call_deferred("retire_empty")
