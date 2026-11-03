extends StaticBody3D
## Original exit stays closed until exterior locations are supported.
var notice_seconds := 0.0

func interact() -> void:
	notice_seconds = 4.0

func _process(delta: float) -> void:
	notice_seconds = maxf(0.0, notice_seconds - delta)

func interaction_prompt() -> String:
	return "Exterior travel is not implemented yet." if notice_seconds > 0 else "E  |  Dungeon exit (outside unavailable)"
