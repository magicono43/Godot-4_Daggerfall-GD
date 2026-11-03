extends RefCounted
## One capture/simulation contract for every player modal.
var actor: CharacterBody3D
var active: Control
var previous_capture := true
var switching := false

func open(window: Control) -> void:
	if active == window:
		return
	if is_instance_valid(active):
		switching = true
		active.close()
		switching = false
	else:
		previous_capture = actor.controls_active
	active = window
	actor.modal_open = true
	actor.controls_active = false
	actor.combat.cancel()
	actor.casting.cancel()
	for enemy in actor.get_tree().get_nodes_in_group("prototype_enemies"):
		enemy.suspend_for_modal()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close(window: Control) -> void:
	if active != window:
		return
	active = null
	if switching:
		return
	actor.modal_open = false
	actor.controls_active = previous_capture and not actor.is_dead()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if actor.controls_active else Input.MOUSE_MODE_VISIBLE
