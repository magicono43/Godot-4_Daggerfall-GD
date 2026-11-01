extends SceneTree
const Profile = preload("res://scripts/movement_profile.gd")
var level: Node3D
var player: CharacterBody3D
var results: Array[String] = []
var failures: Array[String] = []
var fixtures: Node3D
const ARENA := Vector3(100, 0, 100)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)
	print(results[-1])

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + name + ".png")

func place(at: Vector3) -> void:
	for action in ["forward", "back", "left", "right", "jump", "sprint"]:
		Input.action_release(action)
	player.position = at
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.step_camera_offset = 0
	player.stair_supported = false
	await frames(30)

func walk_to(target: Vector3, run: bool = false, limit: int = 360, backwards: bool = false) -> Dictionary:
	var facing := Vector3(target.x, player.position.y, target.z)
	player.look_at(player.position * 2 - facing if backwards else facing)
	Input.action_press("back" if backwards else "forward")
	if run:
		Input.action_press("sprint")
	var airborne := 0
	var largest_step := 0.0
	var peak := player.position.y
	var body_samples: Array[float] = []
	var eye_samples: Array[float] = []
	for i in limit:
		await frames(1)
		if not player.is_grounded():
			airborne += 1
		largest_step = maxf(largest_step, absf(player.last_step))
		peak = maxf(peak, player.position.y)
		body_samples.append(player.global_position.y)
		eye_samples.append(player.camera.global_position.y)
		if Vector2(player.position.x - target.x, player.position.z - target.z).length() < 0.12:
			break
	Input.action_release("forward")
	Input.action_release("back")
	Input.action_release("sprint")
	await frames(10)
	print("STAIR_ROUTE position=", player.position, " target=", target, " airborne=", airborne, " largest_assist=", largest_step)
	var body_roughness := roughness(body_samples)
	var camera_roughness := roughness(eye_samples)
	if body_roughness > 0.001:
		print("VERTICAL_ROUGHNESS body=", body_roughness, " camera=", camera_roughness)
	return {"airborne": airborne, "largest_step": largest_step, "peak": peak, "body_roughness": body_roughness, "camera_roughness": camera_roughness}

func roughness(samples: Array[float]) -> float:
	var sum := 0.0
	for i in range(2, samples.size()):
		var difference := samples[i] - 2 * samples[i - 1] + samples[i - 2]
		sum += difference * difference
	return sqrt(sum / maxf(samples.size() - 2, 1))

func box(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = size
	shape.shape = form
	body.add_child(shape)
	fixtures.add_child(body)
	body.position = ARENA + at

func clear_fixtures() -> void:
	if fixtures:
		fixtures.queue_free()
	fixtures = Node3D.new()
	level.world_root.add_child(fixtures)
	box(Vector3(30, 1, 30), Vector3(0, -0.5, 0))
	await frames(2)

func synthetic_checks() -> void:
	await clear_fixtures()
	for i in 5:
		box(Vector3(3, 0.3 * (i + 1), 0.5), Vector3(0, 0.15 * (i + 1), -3.5 - i * 0.5))
	box(Vector3(3, 1.5, 3), Vector3(0, 0.75, -7))
	await place(ARENA + Vector3(0, 0.05, -2))
	var top := ARENA + Vector3(0, 1.5, -7)
	var ascent := await walk_to(top)
	check(player.position.distance_to(top) < 0.25 and ascent.airborne <= 2, "Synthetic 0.3 m risers ascend with continuous support")
	await frames(20)
	check(absf(player.camera.position.y - player.EYE_HEIGHT) < 0.001, "Step-only camera smoothing settles to calibrated eye height")
	var descent := await walk_to(ARENA + Vector3(0, 0.05, -2))
	check(descent.airborne <= 2 and player.position.y < 0.01, "Synthetic staircase descends without airborne bouncing")
	await place(ARENA + Vector3(0.7, 0.05, -2))
	await walk_to(top + Vector3(-0.7, 0, 0), true)
	check(player.position.y > 1.49 and player.is_grounded(), "Diagonal running ascent stays on treads")
	await place(ARENA + Vector3(0, 0.05, -2))
	player.movement.profile.values.stepping.enabled = false
	await walk_to(top, false, 120)
	check(player.position.z > ARENA.z - 3.4 and player.position.y < 0.3, "Disabling assisted stepping blocks the same stair riser")
	player.movement.profile.values.stepping.enabled = true
	await clear_fixtures()
	box(Vector3(3, 0.65, 3), Vector3(0, 0.325, -5))
	await place(ARENA + Vector3(0, 0.05, -2))
	await walk_to(ARENA + Vector3(0, 0.65, -5), false, 100)
	check(player.position.z > ARENA.z - 3.5 and player.position.y < 0.25, "0.65 m ledge is not climbed through repeated partial lifts")
	await clear_fixtures()
	box(Vector3(3, 0.3, 3), Vector3(0, 0.15, -5))
	box(Vector3(3, 0.2, 3), Vector3(0, 2.05, -5))
	await place(ARENA + Vector3(0, 0.05, -2))
	await walk_to(ARENA + Vector3(0, 0.3, -5), false, 100)
	check(player.position.z > ARENA.z - 3.5 and player.position.y + player.STANDING_HEIGHT < 1.96, "Low overhead clearance rejects a step without head penetration")
	await clear_fixtures()
	box(Vector3(3, 0.4, 3), Vector3(0, 0.2, -5))
	await place(ARENA + Vector3(0, 0.05, -2))
	player.movement.profile.values.stepping.max_height_metres = 0.2
	await walk_to(ARENA + Vector3(0, 0.4, -5), false, 100)
	check(player.position.z > ARENA.z - 3.5, "Lower configured step limit rejects a 0.4 m riser")
	player.movement.profile.values.stepping.max_height_metres = 0.5
	await clear_fixtures()
	box(Vector3(3, 1.2, 3), Vector3(0, 0.6, -1))
	await place(ARENA + Vector3(0, 1.25, -1))
	var fall := await walk_to(ARENA + Vector3(0, 0.05, -5))
	check(fall.airborne >= 10 and player.position.y < 0.01, "A drop beyond step height causes a real fall")
	await clear_fixtures()
	box(Vector3(3, 0.015, 1), Vector3(0, 0.0075, -4))
	await place(ARENA + Vector3(0, 0.05, -2))
	var seam := await walk_to(ARENA + Vector3(0, 0.05, -6))
	check(seam.airborne <= 2 and player.position.z < ARENA.z - 5.8, "Small raised floor seam does not snag or launch the player")

func moving_stair_jump(target: Vector3) -> void:
	player.look_at(Vector3(target.x, player.position.y, target.z))
	var start := player.position
	Input.action_press("forward")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var stalled := 0
	var longest_stall := 0
	var previous := player.position
	for i in 60:
		await frames(1)
		if absf(player.position.x - previous.x) < 0.001:
			stalled += 1
		else:
			stalled = 0
		longest_stall = maxi(longest_stall, stalled)
		previous = player.position
	Input.action_release("forward")
	print("MOVING_STAIR_JUMP distance=", start.x - player.position.x, " longest_stall=", longest_stall)
	check(start.x - player.position.x > 2.5 and longest_stall <= 8, "Moving stair jump resumes forward progress after riser contact without a long halt")
	await frames(60)

func slow_diagonal_checks() -> void:
	for speed_factor in [1.0, 0.5]:
		for lateral in [false, true]:
			for offset in [-0.18, 0.13]:
				var bottom: Vector3 = level.classic.to_world([1080, -2, 640])
				bottom.z += offset
				await place(bottom)
				player.movement.set_modifier("stair_pace_test", {"walk": speed_factor})
				player.look_at(player.position + Vector3.LEFT)
				Input.action_press("forward")
				var stalled := 0
				var worst_stall := 0
				var previous_x := player.position.x
				var strafe := "right"
				for i in 720:
					Input.action_release("left")
					Input.action_release("right")
					if lateral and player.position.x < 12 and player.position.x > 7.2:
						if player.position.z < 25.45:
							strafe = "left"
						elif player.position.z > 26.15:
							strafe = "right"
						Input.action_press(strafe)
					await frames(1)
					stalled = stalled + 1 if absf(previous_x - player.position.x) < 0.001 else 0
					worst_stall = maxi(worst_stall, stalled)
					previous_x = player.position.x
					if player.position.x < 7.2 or stalled >= 30:
						break
				for action in ["forward", "left", "right"]:
					Input.action_release(action)
				print("SLOW_STAIR factor=", speed_factor, " lateral=", lateral, " offset=", offset, " final=", player.position, " stall=", worst_stall)
				check(player.position.x < 7.2 and worst_stall <= 4, "Slow stair approach factor %.1f, strafe %s, offset %.2f avoids riser snags" % [speed_factor, lateral, offset])
	player.movement.remove_modifier("stair_pace_test")

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(60)
	check(level.ready_to_play, "Extended original section loads")
	if not level.ready_to_play:
		quit(1)
		return
	player = level.player
	# Fixed test baseline; the player's editable configuration remains untouched.
	player.movement.profile.values = Profile.DEFAULTS.duplicate(true)
	player.floor_snap_length = 0.35
	player.floor_max_angle = deg_to_rad(70)
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/stair_geometry.json"))
	var stair := level.model_nodes.first_staircase as StaticBody3D
	check(stair.get_meta("section_id") == "first_staircase" and audit.model == "58008" and audit.record_offset == 12767, "Real staircase uses independently audited original model and placement")
	check(audit.vertical_risers_metres.size() == 16 and audit.vertical_risers_metres.max() <= player.movement.profile.values.stepping.max_height_metres, "Sixteen original vertical risers fit configured step limit")
	var bottom: Vector3 = level.classic.to_world([1080, -2, 640])
	var top: Vector3 = level.classic.to_world([720, -256, 640])
	await place(bottom)
	player.look_at(Vector3(top.x, player.position.y, top.z))
	await screenshot("stairs_bottom")
	var ascent := await walk_to(top)
	check(player.position.distance_to(top) < 0.25 and player.is_on_floor(), "Walk up original staircase to 6.4 m landing without jumping")
	check(ascent.airborne <= 2 and ascent.largest_step <= 0.51, "Original stair ascent stays grounded and respects maximum rise")
	check(ascent.camera_roughness < ascent.body_roughness * 0.6, "Rendered ascent height has substantially less stair vibration than capsule movement")
	player.camera.rotation.x = -0.2
	await screenshot("stairs_landing")
	var landing_center: Vector3 = level.classic.to_world([640, -256, 640])
	await walk_to(landing_center)
	await walk_to(level.classic.to_world([640, -256, 450]), false, 120)
	var continuation: Vector3 = level.classic.to_world([640, -256, 450])
	check(player.position.distance_to(continuation) < 0.25 and player.is_grounded(), "Previous landing barrier is removed and connecting corridor is walkable")
	await walk_to(landing_center)
	await walk_to(top)
	var descent := await walk_to(bottom)
	check(player.position.distance_to(bottom) < 0.25 and player.is_on_floor(), "Walk down original staircase into chamber")
	check(descent.airborne <= 2, "Original stair descent maintains floor contact")
	check(descent.camera_roughness < descent.body_roughness * 0.6, "Rendered descent height has substantially less stair vibration than capsule movement")
	await walk_to(top, true)
	check(player.position.distance_to(top) < 0.35 and player.is_on_floor(), "Run up original staircase without jumping")
	var running_descent := await walk_to(bottom, true)
	check(player.position.distance_to(bottom) < 0.35 and player.is_on_floor(), "Run down original staircase safely")
	check(running_descent.airborne <= 2, "Running stair descent maintains verified support")
	await walk_to(top + Vector3(0, 0, 0.15))
	var reverse_descent := await walk_to(bottom, false, 360, true)
	check(player.position.distance_to(bottom) < 0.25 and reverse_descent.airborne <= 2, "Backward diagonal stair descent maintains support")
	var middle: Vector3 = level.classic.to_world([896, -128, 640])
	await walk_to(middle)
	await moving_stair_jump(top)
	await walk_to(middle)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.velocity.y > 0 and not player.stair_supported and player.last_step == 0, "Jump takes off normally from a stair tread without step assistance")
	await frames(60)
	await walk_to(bottom)
	check(player.position.distance_to(bottom) < 0.25 and player.is_grounded(), "Turn around midway on original stairs and return safely")
	await slow_diagonal_checks()
	await synthetic_checks()
	var file := FileAccess.open("res://tests/stair_results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results) + "\n")
	print("STAIRS ", results.size() - failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)
