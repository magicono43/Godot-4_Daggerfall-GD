extends Node
## Scene-owned pile creation, physical placement and inventory drop transfers.
var player: CharacterBody3D
var world_root: Node3D
var payload: Dictionary
var classic: RefCounted
var authored_piles: Dictionary = {}
var error := ""
var session_pile: Node3D
var initialized := false
var next_drop_id := 1

func spawn_authored() -> void:
	# Static bodies must reach the physics server before ground queries run.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for entry in classic.section.definition.prototype.get("treasure_piles", []):
		var marker: Vector3 = classic.treasure_markers[entry.marker_id]
		var hit := ground(marker, 4.0)
		if hit.is_empty():
			push_error("No selected section support below treasure marker: " + entry.marker_id)
			continue
		var pile := create_pile(hit.position, false)
		pile.name = entry.id
		pile.set_meta("marker_id", entry.marker_id)
		for item in entry.test_loot:
			pile.loot.add_item(item.definition, int(item.quantity))
		authored_piles[entry.id] = pile
		pile.set_meta("save_id", entry.id)
	initialized = true

func ground(at: Vector3, distance: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * distance, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.7 or hit.collider.get_meta("section_role", "") not in ["geometry", "prop"]:
		return {}
	return hit

func create_pile(at: Vector3, dropped: bool) -> Area3D:
	var pile := preload("res://scripts/loot_pile.gd").new()
	pile.payload = payload
	pile.player = player
	pile.position = at
	pile.dropped = dropped
	if dropped:
		pile.set_meta("save_id", "drop_%d" % next_drop_id)
		next_drop_id += 1
	world_root.add_child(pile)
	return pile

func drop(uid: int, preferred: Node3D = null) -> bool:
	error = ""
	var item: Dictionary = player.inventory.find(uid)
	if item.is_empty() or player.is_dead():
		error = "Select an item you own."
		return false
	if uid == player.inventory.equipped_uid:
		error = "Unequip this weapon before dropping it."
		return false
	if preferred != null:
		# The interaction that opened this container already authorized access.
		# Deposits do not repeat distance, LOS or ground-placement checks.
		if not is_instance_valid(preferred) or preferred.is_queued_for_deletion() or not preferred.has_method("loot_available") or not preferred.loot_available():
			error = "That container is no longer available."
			return false
		return player.inventory.transfer_to(preferred.loot, uid)
	if player.climbing.active or not player.is_grounded():
		error = "Stand on supported ground to drop items."
		return false
	var support := ground(player.global_position + Vector3.UP * 0.15, 0.7)
	if support.is_empty():
		error = "No safe surface for a drop."
		return false
	var pile: Node3D = null
	if is_instance_valid(session_pile) and not session_pile.is_queued_for_deletion() and session_pile.loot_available():
		pile = session_pile
	var created := false
	if pile == null:
		pile = create_pile(support.position, true)
		created = true
		session_pile = pile
	var moved: bool = player.inventory.transfer_to(pile.loot, uid)
	if not moved and created:
		pile.retire_empty()
	return moved

func begin_drop_session() -> void:
	session_pile = null

func end_drop_session() -> void:
	session_pile = null
