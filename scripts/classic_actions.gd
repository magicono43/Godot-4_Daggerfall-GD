extends Node
## Selected classic rotation/translation chains; no generic trap/quest interpreter.
var level: Node3D
var entries: Dictionary = {}
var groups: Dictionary = {}
var environment_rids: Array[RID] = []

func setup(scene: Node3D) -> void:
	level = scene
	process_physics_priority = -100
	for body in level.model_nodes.values():
		environment_rids.append(body.get_rid())
	var source_keys: Dictionary = {}
	for object in level.classic.objects:
		if object.action.is_empty():
			continue
		var body: AnimatableBody3D = level.model_nodes[object.id]
		var mesh: MeshInstance3D = body.get_child(0)
		entries[object.id] = {"body": body, "start": body.transform, "source": object.action, "guard": mesh.mesh.create_convex_shape()}
		source_keys["%s:%d" % [object.block, object.offset]] = object.id
	for object in level.classic.objects:
		if object.action.is_empty() or object.action.trigger != 2:
			continue
		var chain: Array[String] = []
		var id: String = object.id
		while not id.is_empty():
			chain.append(id)
			var member: Dictionary = entries[id]
			id = source_keys["%s:%d" % [object.block, member.source.next]] if member.source.next >= 0 else ""
		var duration := 0.0
		for member_id in chain:
			duration = maxf(duration, float(entries[member_id].source.duration) / 20.0)
		groups[object.id] = {"members": chain, "duration": duration, "elapsed": 0.0, "raised": false, "busy": false, "forward": true, "blocked": false}
		var trigger: Node = entries[object.id].body
		trigger.controller = self
		trigger.action_id = object.id

func prompt(id: String) -> String:
	var group: Dictionary = groups[id]
	if group.blocked:
		return "Mechanism blocked — clear the moving object"
	if group.busy:
		return "Mechanism moving"
	return "E  |  Toggle mechanism"

func activate(id: String) -> void:
	if not groups.has(id) or level.player.modal_open or not level.player.controls_active or level.player.is_dead():
		return
	var group: Dictionary = groups[id]
	if group.busy:
		return
	group.busy = true
	group.forward = not group.raised
	group.elapsed = 0.0
	group.blocked = false
	for member_id in group.members:
		var member: Dictionary = entries[member_id]
		level.combat_audio.play_action(int(member.source.sound), member.body)

func pose(entry: Dictionary, fraction: float) -> Transform3D:
	var result: Transform3D = entry.start
	var source: Dictionary = entry.source
	if source.flags == 1:
		# RDBLayout translation vectors are world-aligned. This checked subset
		# uses positive vertical travel; retain the native scale conversion.
		var axes := [Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT, Vector3.DOWN, Vector3.UP, Vector3.FORWARD, Vector3.BACK]
		result.origin += axes[int(source.axis)] * float(source.magnitude) * 0.025 * fraction
	elif source.flags == 8:
		# Reflect Unity's rotation axes through Z for Godot, then rotate locally.
		var axes := [Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
		result.basis = result.basis * Basis(axes[int(source.axis)], float(source.magnitude) * TAU / 2048.0 * fraction)
	return result

func rider(group: Dictionary) -> CharacterBody3D:
	var actor: CharacterBody3D = level.player
	if actor.climbing.active or not actor.is_grounded():
		return null
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.08, actor.global_position + Vector3.DOWN * 0.15, 1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.7:
		return null
	for id in group.members:
		if entries[id].source.flags == 1 and hit.collider == entries[id].body:
			return actor
	return null

func safe(group: Dictionary, targets: Dictionary, passenger: CharacterBody3D) -> bool:
	var space: PhysicsDirectSpaceState3D = level.player.get_world_3d().direct_space_state
	var excludes: Array[RID] = []
	for id in group.members:
		excludes.append(entries[id].body.get_rid())
	if passenger != null:
		var travel := Vector3.ZERO
		for id in group.members:
			if entries[id].source.flags == 1:
				travel = targets[id].origin - entries[id].body.position
				break
		var headroom := PhysicsShapeQueryParameters3D.new()
		headroom.shape = passenger.capsule_collision.shape
		headroom.transform = passenger.capsule_collision.global_transform
		headroom.motion = travel
		headroom.collision_mask = 1
		headroom.exclude = excludes
		if space.cast_motion(headroom)[0] < 0.999:
			return false
	for id in group.members:
		var entry: Dictionary = entries[id]
		if entry.source.flags == 30:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = entry.guard
		query.transform = targets[id]
		query.collision_mask = 3
		query.exclude = environment_rids
		query.margin = 0.005
		# Original convex outlines conservatively prevent actor crushing. The
		# platform's supported passenger is checked against world headroom above.
		for hit in space.intersect_shape(query, 32):
			if hit.collider is CharacterBody3D and hit.collider != passenger:
				return false
	return true

func _physics_process(delta: float) -> void:
	var paused: bool = level.player.modal_open or not level.player.controls_active or level.player.is_dead()
	for voice in level.combat_audio.voices:
		if voice.get_meta("action_voice", false):
			voice.stream_paused = paused
	if paused:
		return
	for group in groups.values():
		if not group.busy:
			continue
		var elapsed := minf(group.duration, group.elapsed + delta)
		var targets: Dictionary = {}
		for id in group.members:
			var entry: Dictionary = entries[id]
			var duration := float(entry.source.duration) / 20.0
			var fraction := minf(1.0, elapsed / duration) if duration > 0 else 1.0
			targets[id] = pose(entry, fraction if group.forward else 1.0 - fraction)
		group.blocked = not safe(group, targets, rider(group))
		if group.blocked:
			continue
		group.elapsed = elapsed
		for id in group.members:
			entries[id].body.transform = targets[id]
		if elapsed >= group.duration:
			group.busy = false
			group.raised = group.forward

func moving() -> bool:
	return groups.values().any(func(group: Dictionary): return group.busy)

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for id in groups:
		result[id] = groups[id].raised
	return result

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != groups.size():
		return false
	for id in groups:
		if not data.get(id) is bool:
			return false
	return true

func restore(data: Dictionary) -> void:
	for id in groups:
		var group: Dictionary = groups[id]
		group.raised = data[id]
		group.busy = false
		group.blocked = false
		for member_id in group.members:
			entries[member_id].body.transform = pose(entries[member_id], 1.0 if group.raised else 0.0)
