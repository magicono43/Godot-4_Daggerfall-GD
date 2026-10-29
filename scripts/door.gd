extends AnimatableBody3D
var opened := false
var busy := false
var closed_basis := Basis.IDENTITY
var player: CharacterBody3D
signal used

func interact() -> void:
	if busy:
		return
	# Refuse closing while the player occupies the doorway's swing area.
	if opened and player.global_position.distance_to(global_position) < 1.9:
		return
	busy = true
	opened = not opened
	var target := closed_basis * Basis(Vector3.UP, -PI / 2 if opened else 0.0)
	var initial := basis.get_rotation_quaternion()
	var final := target.get_rotation_quaternion()
	# Transform and collider advance together on physics ticks.
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(t: float): basis = Basis(initial.slerp(final, t)), 0.0, 1.0, 0.65).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func(): busy = false)
	used.emit()
