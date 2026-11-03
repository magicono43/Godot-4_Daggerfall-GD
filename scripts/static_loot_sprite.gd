extends "res://scripts/classic_billboard.gd"
## Visual-only treasure marker representation; contents/activation are deferred.

func _ready() -> void:
	set_meta("source_marker_position", position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 4.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.7:
		push_error("No walkable support below static treasure marker: " + name)
		return
	# Marker heights describe editor flats, not the pile's bottom edge.
	global_position = hit.position + Vector3.UP * original_size.y * 0.5
