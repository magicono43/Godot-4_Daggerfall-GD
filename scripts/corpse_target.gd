extends Area3D
## Interaction-only layer, excluded from movement and melee casts.
var actor: CharacterBody3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	var dimensions: Vector2 = actor.sprite_payload.corpse.size_metres
	bounds.size = Vector3(dimensions.x, maxf(dimensions.y, 0.25), 0.5)
	shape.shape = bounds
	shape.position.y = bounds.size.y * 0.5
	add_child(shape)

func interact() -> void:
	if actor.health.current == 0:
		actor.player.loot_requested.emit(actor)
