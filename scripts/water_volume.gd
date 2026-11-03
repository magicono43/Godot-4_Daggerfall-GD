extends RefCounted
## Authored box bounds in world metres. The upper Y face is the water surface.
var bounds := AABB()

func configure(box: AABB) -> bool:
	if not box.position.is_finite() or not box.size.is_finite() or box.size.x <= 0 or box.size.y <= 0 or box.size.z <= 0:
		return false
	bounds = box
	return true

func contains(at: Vector3) -> bool:
	return at.x >= bounds.position.x and at.x <= bounds.end.x and at.z >= bounds.position.z and at.z <= bounds.end.z and at.y >= bounds.position.y - 0.05 and at.y < bounds.end.y

func surface() -> float:
	return bounds.end.y
