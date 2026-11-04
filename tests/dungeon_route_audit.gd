extends SceneTree
## Test-only floor graph for discovering source routes, never used by gameplay.
const SPACING := 0.4
var level: Node3D
var space: PhysicsDirectSpaceState3D
var nodes: Array[Vector3] = []
var cells: Dictionary = {}
var graph := AStar3D.new()
var capsule := CapsuleShape3D.new()

func _initialize() -> void:
	call_deferred("run")

func clear_at(feet: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [level.player.get_rid()]
	query.transform.origin = feet + Vector3.UP * 0.93
	return space.intersect_shape(query, 1).is_empty()

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	for i in 5:
		await physics_frame
	if not level.ready_to_play:
		print(level.classic.error)
		quit(1)
		return
	level.player.set_physics_process(false)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
		if "--enemy-routes" in OS.get_cmdline_user_args():
			enemy.collision_layer = 0
	for door in level.doors:
		door.request_open(level.player)
	for i in 45:
		await physics_frame
	space = level.world_root.get_world_3d().direct_space_state
	capsule.radius = 0.35
	capsule.height = 1.8
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for body in level.model_nodes.values():
		var mesh: MeshInstance3D = body.get_child(0)
		var box: AABB = body.transform * mesh.mesh.get_aabb()
		low = low.min(box.position)
		high = high.max(box.end)
	print("BOUNDS ", low, " ", high)
	for x in range(floori(low.x / SPACING), ceili(high.x / SPACING) + 1):
		for z in range(floori(low.z / SPACING), ceili(high.z / SPACING) + 1):
			var top := high.y + 1
			for layer in 20:
				var ray := PhysicsRayQueryParameters3D.create(Vector3(x * SPACING, top, z * SPACING), Vector3(x * SPACING, low.y - 1, z * SPACING), 1)
				var hit := space.intersect_ray(ray)
				if hit.is_empty():
					break
				top = hit.position.y - 0.04
				if hit.normal.y < 0.7 or not clear_at(hit.position):
					continue
				var id := nodes.size()
				nodes.append(hit.position)
				graph.add_point(id, hit.position)
				var cell := Vector2i(x, z)
				if not cells.has(cell):
					cells[cell] = []
				cells[cell].append(id)
	for cell in cells:
		for delta in [Vector2i(1, 0), Vector2i(0, 1)]:
			for a in cells[cell]:
				for b in cells.get(cell + delta, []):
					if absf(nodes[a].y - nodes[b].y) > 1.0:
						continue
					var start: Vector3 = nodes[a] + Vector3.UP * 0.15
					var end: Vector3 = nodes[b] + Vector3.UP * 0.15
					start.y = maxf(start.y, end.y)
					end.y = start.y
					var ray := PhysicsRayQueryParameters3D.create(start, end, 1)
					if not space.intersect_ray(ray).is_empty():
						continue
					var sweep := PhysicsShapeQueryParameters3D.new()
					sweep.shape = capsule
					sweep.collision_mask = 1
					sweep.exclude = [level.player.get_rid()]
					sweep.transform.origin = Vector3(nodes[a].x, maxf(nodes[a].y, nodes[b].y) + 0.93, nodes[a].z)
					sweep.motion = Vector3(nodes[b].x - nodes[a].x, 0, nodes[b].z - nodes[a].z)
					if space.cast_motion(sweep)[0] > 0.999:
						graph.connect_points(a, b)
	var origin := graph.get_closest_point(level.player.position)
	var output := {"spacing": SPACING, "floor_samples": nodes.size(), "routes": {}}
	var visited: Dictionary = {origin: true}
	var queue: Array[int] = [origin]
	var cursor := 0
	while cursor < queue.size():
		var a := queue[cursor]
		cursor += 1
		for b in graph.get_point_connections(a):
			if not visited.has(b):
				visited[b] = true
				queue.append(b)
	output["hall_component_samples"] = queue.size()
	# One furthest reachable representative in each source block.
	for block in level.classic.provenance.blocks:
		var chosen := -1
		var distance := -1.0
		for id in queue:
			var native: Vector3 = (nodes[id] + level.classic.origin) / 0.025
			if floori(native.x / 2048) != block.x or floori(-native.z / 2048) != block.z:
				continue
			var length := nodes[id].distance_to(nodes[origin])
			if length > distance:
				chosen = id
				distance = length
		if chosen >= 0:
			var path := graph.get_point_path(origin, chosen)
			var points: Array = []
			for point in path:
				points.append([point.x, point.y, point.z])
			output.routes[block.name] = points
	# Flat-floor discovery intentionally does not certify stairs. The test walks
	# the original hall/gallery stairs continuously before using this second seed.
	var upper := graph.get_closest_point(level.classic.to_world([1200, -1280, 384]))
	var upper_seen: Dictionary = {upper: true}
	var upper_queue: Array[int] = [upper]
	cursor = 0
	while cursor < upper_queue.size():
		var a := upper_queue[cursor]
		cursor += 1
		for b in graph.get_point_connections(a):
			if not upper_seen.has(b):
				upper_seen[b] = true
				upper_queue.append(b)
	var upper_routes: Dictionary = {}
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var chosen := upper
		var score := -INF
		for id in upper_queue:
			if absf(nodes[id].y - 32.0) > 0.1:
				continue
			if nodes[id].dot(direction) > score:
				chosen = id
				score = nodes[id].dot(direction)
		var points: Array = []
		for point in graph.get_point_path(upper, chosen):
			points.append([point.x, point.y, point.z])
		upper_routes[str(direction)] = points
	output["upper_routes"] = upper_routes
	if "--enemy-routes" in OS.get_cmdline_user_args():
		output["enemy_routes"] = {}
		var corridor := graph.get_closest_point(level.classic.to_world([1920,-256,1664]))
		for entry in level.classic.fixed_enemies:
			var goal := graph.get_closest_point(entry.position)
			var points: Array = []
			for point in graph.get_point_path(corridor if entry.record_offset == 32958 else origin, goal):
				points.append([point.x,point.y,point.z])
			output.enemy_routes[entry.id] = points
	var file := FileAccess.open("res://tests/output/enemy_floor_audit.json" if "--enemy-routes" in OS.get_cmdline_user_args() else "res://tests/dungeon_floor_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	print("FLOOR_AUDIT nodes=", nodes.size(), " reachable=", queue.size(), " routes=", output.routes.keys())
	quit()
