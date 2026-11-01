extends AnimatableBody3D
var opened := false
var busy := false
var closed_basis := Basis.IDENTITY
var swing_angle := -PI / 2
var player: CharacterBody3D
signal used

func interact() -> void:
	if busy:
		return
	# Refuse closing while the player occupies the doorway's swing area.
	if opened and player.global_position.distance_to(global_position) < 1.9:
		return
	animate_leaf(not opened, player)

func request_open(actor: CharacterBody3D) -> void:
	if not opened and not busy:
		animate_leaf(true, actor)

func animate_leaf(open: bool, actor: CharacterBody3D) -> void:
	busy = true
	opened = open
	if opened:
		# All selected classic door leaves extend along local +X. Swing away
		# from the player's side instead of sweeping the capsule out of line.
		var local_player := global_basis.inverse() * (actor.global_position - global_position)
		swing_angle = PI / 2 if local_player.z >= 0 else -PI / 2
	var target := closed_basis * Basis(Vector3.UP, swing_angle if opened else 0.0)
	var initial := basis.get_rotation_quaternion()
	var final := target.get_rotation_quaternion()
	# Transform and collider advance together on physics ticks.
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_method(func(t: float): basis = Basis(initial.slerp(final, t)), 0.0, 1.0, 0.65).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func(): busy = false)
	used.emit()
