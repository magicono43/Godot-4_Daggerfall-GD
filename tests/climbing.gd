extends SceneTree
var player: CharacterBody3D
var arena: Node3D
var failures: Array[String] = []
var results: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)
	print(results[-1], " position=", player.position, " mode=", player.climbing.transition)

func box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = size
	shape.shape = form
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	body.add_child(mesh)
	arena.add_child(body)
	body.position = at
	return body

func release() -> void:
	for action in ["forward", "back", "left", "right", "jump", "sprint"]:
		Input.action_release(action)

func reset() -> void:
	release()
	player.climbing.reset()
	player.position = Vector3(0, 0.02, 0)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.stair_supported = false
	player.movement.set_live_effects({})
	await frames(20)

func attach() -> void:
	Input.action_press("forward")
	await frames(85)

func run() -> void:
	for action in ["forward", "back", "left", "right", "jump", "sprint", "reload_movement", "movement_debug", "release_mouse", "interact", "reset"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	arena = Node3D.new()
	root.add_child(arena)
	box(Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	var wall := box(Vector3(8, 4, 2), Vector3(0, 2, -2))
	player = preload("res://scripts/player.gd").new()
	arena.add_child(player)
	await reset()
	Input.action_press("forward")
	await frames(30)
	check(not player.climbing.active and player.position.y < 0.1, "Wall contact requires sustained attachment delay")
	await frames(55)
	check(player.climbing.active and player.position.y > 0.2, "Intentional wall push attaches and ascends")
	release()
	var before := player.position
	await frames(30)
	check(player.climbing.active and absf(player.position.y - before.y) < 0.02, "Idle holds wall without gravity")
	player.rotation.y = PI / 2
	Input.action_press("right")
	await frames(20)
	check(player.position.x > before.x + 0.3 and absf(player.position.z - before.z) < 0.03, "Strafe follows wall despite free mouse yaw")
	release()
	player.rotation.y = 0
	before = player.position
	Input.action_press("forward")
	await frames(30)
	check(absf(player.position.y - before.y - player.movement.resolve().climb_walk_speed * 0.5) < 0.06, "Ascent uses resolved baseline speed")
	player.movement.set_live_effects({"enhanced_climbing": true})
	before = player.position
	await frames(20)
	check(absf(player.position.y - before.y - player.movement.resolve().climb_walk_speed / 3.0) < 0.08, "Live enhanced climbing doubles ascent speed")
	release()
	Input.action_press("jump")
	await frames(2)
	check(not player.climbing.active and player.flight_horizontal.z > 2.5, "Space ejects with outward airborne momentum")
	release()
	await frames(8)
	check(not player.climbing.active, "Ejection prevents immediate reattachment")
	await reset()
	await attach()
	release()
	Input.action_press("back")
	await frames(100)
	check(not player.climbing.active and player.is_grounded(), "Descent returns to verified ground")
	await reset()
	await attach()
	for i in 180:
		await frames(1)
		if player.climbing.transition == "ledge":
			break
	release()
	await frames(10)
	check(not player.climbing.active and player.position.y > 3.95 and player.position.z < -1.3, "Clear ledge mounts onto walkable wall top")
	var ceiling := box(Vector3(8, 0.3, 3), Vector3(0, 4.7, -1))
	await reset()
	await attach()
	await frames(220)
	release()
	check(player.climbing.active and player.position.y < 3.0 and player.position.z > -0.7, "Low ceiling blocks ascent and unsafe ledge mounting")
	ceiling.queue_free()
	await reset()
	wall.set_meta("climbable", false)
	await attach()
	check(not player.climbing.active, "Explicitly excluded surfaces cannot attach")
	wall.set_meta("climbable", true)
	wall.add_to_group("slice_boundaries")
	await reset()
	await attach()
	check(not player.climbing.active, "Authored boundary caps cannot attach")
	wall.remove_from_group("slice_boundaries")
	wall.set_meta("section_role", "prop")
	await reset()
	await attach()
	check(not player.climbing.active, "Decorative section props cannot attach")
	wall.remove_meta("section_role")
	await reset()
	player.rotation.y = 0.7
	await attach()
	check(not player.climbing.active, "Glancing approaches do not attach")
	await reset()
	Input.action_press("right")
	await attach()
	check(not player.climbing.active, "Moving along wall with forward-strafe does not attach")
	await reset()
	await attach()
	wall.position.x = 15
	await frames(4)
	check(not player.climbing.active and player.velocity.y < 0, "Lost wall returns to ordinary falling")
	wall.position.x = 0
	await reset()
	await attach()
	player.position = Vector3(10, 0.1, 0)
	await frames(3)
	check(not player.climbing.active, "Teleport invalidates wall attachment")
	release()
	await ledge_checks(wall)
	arena.queue_free()
	await frames(2)
	await dungeon_checks()
	print("%d/%d climbing checks passed" % [results.size() - failures.size(), results.size()])
	var report := FileAccess.open("res://tests/climbing_results.txt", FileAccess.WRITE)
	if report:
		report.store_string("\n".join(results) + "\n")
	quit(0 if failures.is_empty() else 1)

func stand_on_top() -> void:
	await reset()
	player.position = Vector3(0, 4.02, -2)
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	await frames(20)

func ledge_checks(wall: StaticBody3D) -> void:
	await stand_on_top()
	Input.action_press("back")
	var largest_move := 0.0
	var previous := player.position
	for i in 120:
		await frames(1)
		largest_move = maxf(largest_move, player.position.distance_to(previous))
		previous = player.position
		if player.climbing.active and player.climbing.entry_path.is_empty() and player.position.y < 3.0:
			break
	release()
	check(player.climbing.active and player.position.y < 3.0 and largest_move < 0.15, "Backing off ledge enters climbing with continuous checked motion")
	check(absf(player.rotation.y) < 0.001 and player.flight_horizontal.is_zero_approx(), "Ledge entry preserves facing and clears walking momentum")
	var before := player.position
	await frames(15)
	check(player.climbing.active and player.position.distance_to(before) < 0.02, "Release S holds normal climbing position after ledge entry")
	Input.action_press("right")
	await frames(15)
	release()
	check(player.position.x > before.x + 0.3, "Ledge descent immediately supports regular sideways climbing")
	Input.action_press("forward")
	for i in 100:
		await frames(1)
		if not player.climbing.active:
			break
	release()
	await frames(10)
	check(player.is_grounded() and player.position.y > 3.95, "W climbs back onto the same ledge after descent")
	await stand_on_top()
	Input.action_press("back")
	for i in 40:
		await frames(1)
		if not player.climbing.entry_path.is_empty():
			break
	release()
	before = player.position
	await frames(10)
	check(player.climbing.active and player.position.distance_to(before) < 0.01, "Releasing S during entry holds without slipping off")
	Input.action_press("forward")
	for i in 45:
		await frames(1)
		if not player.climbing.active:
			break
	release()
	await frames(10)
	check(not player.climbing.active and player.is_grounded() and player.position.y > 3.95, "W reverses an unfinished entry safely onto the ledge")
	await stand_on_top()
	player.rotation.y = PI
	Input.action_press("forward")
	await frames(55)
	release()
	check(not player.climbing.active and player.position.y < 3.8, "Forward walk-off remains an ordinary fall")
	await stand_on_top()
	Input.action_press("back")
	Input.action_press("jump")
	await frames(40)
	release()
	check(not player.climbing.active, "Backward jumps do not trigger ledge capture")
	await stand_on_top()
	wall.set_meta("climbable", false)
	Input.action_press("back")
	await frames(55)
	release()
	check(not player.climbing.active and player.position.y < 3.8, "Excluded wall below ledge does not capture backward walk-off")
	wall.set_meta("climbable", true)
	var lip := box(Vector3(8, 0.2, 2.8), Vector3(0, 3.9, -1.6))
	await stand_on_top()
	Input.action_press("back")
	await frames(55)
	release()
	check(not player.climbing.active, "Overhanging lip without clear wall path refuses capture")
	lip.queue_free()
	await frames(2)
	await stand_on_top()
	Input.action_press("back")
	for i in 40:
		await frames(1)
		if not player.climbing.entry_path.is_empty():
			break
	Input.action_press("jump")
	await frames(2)
	release()
	check(not player.climbing.active and player.flight_horizontal.z > 2.5, "Space ejects during the entry transition")
	before = player.position
	await frames(6)
	check(player.position.z > before.z + 0.25, "Entry ejection retains outward momentum after stale platform contact")
	await stand_on_top()
	Input.action_press("back")
	for i in 40:
		await frames(1)
		if not player.climbing.entry_path.is_empty():
			break
	release()
	wall.set_meta("climbable", false)
	await frames(3)
	check(not player.climbing.active, "Entry stops if its wall becomes unavailable while holding")
	wall.set_meta("climbable", true)
	var step := box(Vector3(8, 0.4, 2), Vector3(12, 0.2, -2))
	await reset()
	player.position = Vector3(12, 0.42, -2)
	await frames(20)
	Input.action_press("back")
	await frames(35)
	release()
	check(not player.climbing.active and player.is_grounded(), "Small backward steps retain ordinary grounded traversal")
	step.queue_free()

func dungeon_checks() -> void:
	var level: Node3D = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(30)
	player = level.player
	player.climbing.reset()
	player.position = level.classic.to_world([640, -512, 900]) + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.stair_supported = false
	player.look_at(player.position + Vector3.LEFT)
	await frames(15)
	Input.action_press("forward")
	await frames(210)
	release()
	check(player.climbing.active and player.position.y > 13.5, "Actual west hall wall supports grounded attachment and ascent")
	var before := player.position
	Input.action_press("forward")
	await frames(180)
	release()
	check(player.climbing.active and player.position.y > before.y + 4.2, "Actual west wall maintains continuous climb across original triangles")
	Input.action_press("right")
	await frames(40)
	release()
	check(player.climbing.active, "Actual west wall supports lateral movement")
	# Capture the playable view looking back across the hall while attached.
	if DisplayServer.get_name() != "headless":
		player.set_physics_process(false)
		player.camera.look_at(player.position + Vector3(3, -2, -4))
		player.show_movement_debug = true
		await frames(5)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/climbing_hall.png")
		player.set_physics_process(true)
	Input.action_press("forward")
	await frames(1000)
	release()
	check(player.climbing.active and player.position.y > 32.0 and player.position.y + player.STANDING_HEIGHT <= 35.23, "Actual full-height west wall stops capsule below hall ceiling")
	Input.action_press("back")
	for i in 1100:
		await frames(1)
		if not player.climbing.active:
			break
	release()
	await frames(10)
	check(not player.climbing.active and player.is_grounded() and absf(player.position.y - 12.8) < 0.05, "Actual hall wall descent reaches original floor")
	await dungeon_ledge_checks(level)

func dungeon_ledge_checks(level: Node3D) -> void:
	player.climbing.reset()
	player.position = level.classic.to_world([1200, -1280, 384]) + Vector3.UP * 0.04
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.stair_supported = false
	player.look_at(player.position + Vector3.BACK)
	await frames(20)
	Input.action_press("back")
	for i in 200:
		await frames(1)
		if player.climbing.active and player.climbing.entry_path.is_empty():
			break
	release()
	check(player.climbing.active and player.position.y > 30.0, "Original upper landing allows backward ledge capture")
	var before := player.position
	Input.action_press("back")
	await frames(60)
	release()
	check(player.climbing.active and player.position.y < before.y - 1.4, "Holding S continues regular descent below original landing")
	if DisplayServer.get_name() != "headless":
		player.set_physics_process(false)
		player.camera.look_at(player.position + Vector3(3, -2, -4))
		await frames(5)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/ledge_descent_hall.png")
		player.camera.rotation = Vector3.ZERO
		player.set_physics_process(true)
	Input.action_press("forward")
	for i in 160:
		await frames(1)
		if not player.climbing.active:
			break
	release()
	await frames(10)
	check(player.is_grounded() and absf(player.position.y - 32.0) < 0.05, "Original landing descent can reverse and mount back onto its top")
