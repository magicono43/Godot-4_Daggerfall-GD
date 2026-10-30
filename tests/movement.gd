extends SceneTree
## Independent flat arena: motor checks do not depend on dungeon surface shape.
const Model = preload("res://scripts/movement_model.gd")
const Profile = preload("res://scripts/movement_profile.gd")
var player: CharacterBody3D
var arena: Node3D
var results: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)
	print(results[-1])

func near(actual: float, expected: float, tolerance: float = 0.0001) -> bool:
	return absf(actual - expected) <= tolerance

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func parameter_checks() -> void:
	var model := Model.new()
	var resolved := model.resolve()
	check(near(resolved.walk_speed, 175.0 / 39.5), "Speed 50 walk uses DFU drag formula")
	check(near(resolved.run_speed, 295.0 / 39.5), "Running 25 uses independent DFU run formula")
	check(near(resolved.jump_velocity, 5.0625) and near(resolved.gravity, 20.0), "Jumping 25 launch and gravity baseline")
	check(near(resolved.swim_walk_speed, 1.661392405) and near(resolved.climb_walk_speed, 1.476793249), "Future swim/climb speed hooks resolve without enabling modes")
	model.set_live_stats({"speed_attribute": 20.0, "running_skill": 100.0, "jumping_skill": 100.0})
	resolved = model.resolve()
	check(near(resolved.walk_speed, 135.0 / 39.5) and near(resolved.run_speed, 314.5 / 39.5), "Live stats handle low-Speed drag floor and running skill")
	check(near(resolved.jump_velocity, 6.75), "Live Jumping skill changes launch velocity")
	model.set_live_stats({})
	model.set_live_effects({"athleticism": true, "improved_athleticism": true, "enhanced_jumping": true, "enhanced_climbing": true})
	resolved = model.resolve()
	check(near(resolved.jump_velocity, 8.6625) and resolved.air_control, "Athleticism and Jump effect add bonuses; Jump effect enables air control")
	check(near(resolved.climb_walk_speed, 2.953586498), "Enhanced climbing doubles future speed hook")
	model.set_live_effects({"improved_athleticism": true})
	check(near(model.resolve().jump_velocity, 5.0625), "Improved Athleticism requires Athleticism")
	model.set_live_effects({})
	model.set_modifier("boots", {"walk": 1.5, "run": 1.5})
	model.set_modifier("slow", {"walk": 0.5, "jump": 0.5, "gravity": 0.5})
	check(near(model.resolve().walk_speed, 175.0 / 39.5 * 0.75) and near(model.resolve().jump_velocity, 2.53125) and near(model.resolve().gravity, 10.0), "Named effect factors combine across separate channels")
	model.set_modifier("boots", {"walk": 2.0})
	check(near(model.resolve().walk_speed, 175.0 / 39.5) and near(model.resolve().run_speed, 295.0 / 39.5), "Replacing an effect ID updates rather than stacks stale factors")
	model.remove_modifier("slow")
	check(near(model.resolve().walk_speed, 350.0 / 39.5) and near(model.resolve().jump_velocity, 5.0625), "Removing a named effect restores other channels")
	check(not model.set_live_stats({"speed_attribute": -1}) and model.live_stats.is_empty(), "Invalid live stat update is transactional")
	check(not model.set_live_effects({"levitation": true}) and not model.set_modifier("bad", {"walk": NAN}) and not model.set_modifier("bad", {"teleport": 1.0}), "Unknown effects/channels and nonfinite modifiers rejected")
	var profile := Profile.new()
	check(profile.load_file(), "Shipped movement configuration is valid")
	var previous: Dictionary = profile.values.duplicate(true)
	var file := FileAccess.open("res://tests/movement_test_case.cfg", FileAccess.WRITE)
	file.store_string('[baseline]\nspeed_attribute=90.0\n[physics]\ngravity=-1.0\n')
	file.close()
	check(not profile.load_file("res://tests/movement_test_case.cfg") and profile.values == previous, "Invalid reload preserves entire previous configuration")
	file = FileAccess.open("res://tests/movement_test_case.cfg", FileAccess.WRITE)
	file.store_string('[locomotion]\nrespones="smooth"\n')
	file.close()
	check(not profile.load_file("res://tests/movement_test_case.cfg") and "respones" in profile.error, "Misspelled configuration key produces actionable error")
	file = FileAccess.open("res://tests/movement_test_case.cfg", FileAccess.WRITE)
	file.store_string('[baseline]\nspeed_attribute=60.0\n[locomotion]\nresponse="dfu_axes"\n')
	file.close()
	model.set_live_stats({"speed_attribute": 70.0})
	check(model.profile.load_file("res://tests/movement_test_case.cfg") and model.stat("speed_attribute") == 70.0 and model.profile.values.baseline.speed_attribute == 60.0, "Config reload retains live character override; omitted fields use defaults")
	model.set_live_stats({})
	check(model.stat("speed_attribute") == 60.0, "Clearing live overrides returns to configured baseline")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://tests/movement_test_case.cfg"))

func box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = size
	shape.shape = form
	body.add_child(shape)
	arena.add_child(body)
	body.position = at
	return body

func release_controls() -> void:
	for action in ["forward", "back", "left", "right", "sprint", "jump"]:
		Input.action_release(action)

func reset_player() -> void:
	release_controls()
	player.movement.profile.values = Profile.DEFAULTS.duplicate(true)
	player.movement.set_live_stats({})
	player.movement.set_live_effects({})
	player.movement.modifiers.clear()
	player.position = Vector3(0, 0.05, 0)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.input_axes = Vector2.ZERO
	player.grounded_time = 0.0
	player.controls_active = true
	await frames(30)

func motor_checks() -> void:
	await reset_player()
	check(player.is_on_floor(), "Capsule settles on arena floor")
	Input.action_press("forward")
	await frames(15)
	check(near(-player.velocity.z, 175.0 / 39.5), "Ground motor reaches source-baseline walking speed")
	Input.action_press("right")
	await frames(5)
	check(near(Vector2(player.velocity.x, player.velocity.z).length(), 175.0 / 39.5), "Diagonal movement does not exceed walking speed")
	Input.action_press("sprint")
	await frames(5)
	check(near(Vector2(player.velocity.x, player.velocity.z).length(), 295.0 / 39.5), "Shift applies resolved running speed")
	release_controls()
	await frames(2)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.001, "Instant response stops without residual drift")
	Input.action_press("back")
	await frames(2)
	check(near(player.velocity.z, 175.0 / 39.5), "Instant response reverses immediately")
	await reset_player()
	player.movement.profile.values.locomotion.response = "dfu_axes"
	Input.action_press("forward")
	await frames(3)
	check(player.input_axes.y < -0.15 and player.input_axes.y > -0.6 and absf(player.velocity.z) < 3, "DFU acceleration mode ramps input axes rather than imposing fixed metre acceleration")
	await frames(10)
	check(near(player.input_axes.y, -1.0) and near(-player.velocity.z, 175.0 / 39.5), "DFU axis ramp reaches full input in about a tenth of a second")
	release_controls()
	await frames(10)
	check(near(player.velocity.z, 0.0), "DFU axis friction stops after input release")
	await reset_player()
	player.movement.profile.values.locomotion.response = "smooth"
	player.movement.profile.values.locomotion.ground_acceleration = 6.0
	Input.action_press("forward")
	await frames(10)
	check(absf(player.velocity.z) >= 0.8 and absf(player.velocity.z) <= 1.1, "Optional smooth mode respects configured acceleration")
	player.movement.profile.values.locomotion.ground_braking = 12.0
	release_controls()
	await frames(8)
	check(near(player.velocity.z, 0.0), "Optional smooth mode respects independent braking")
	await reset_player()
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var apex := player.position.y
	var landed := false
	for i in 65:
		await frames(1)
		apex = maxf(apex, player.position.y)
		if player.is_on_floor():
			landed = true
			break
	check(apex > 0.57 and apex < 0.66 and landed, "Baseline physical jump reaches about 0.60 m and lands")
	await reset_player()
	Input.action_press("forward")
	await frames(5)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	release_controls()
	var launch_z := player.velocity.z
	player.rotation.y = PI / 2.0
	Input.action_press("right")
	Input.action_press("sprint")
	await frames(5)
	check(near(player.velocity.x, 0.0) and near(player.velocity.z, launch_z) and launch_z < -4.6 and not player.is_running, "Airborne turn/input/Shift preserve world momentum and takeoff run state")
	await reset_player()
	player.movement.set_live_effects({"enhanced_jumping": true})
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	Input.action_press("right")
	await frames(3)
	check(player.velocity.x > 4.4 and not player.is_on_floor(), "Jump magic enables air steering in motor")
	await reset_player()
	Input.action_press("right")
	Input.action_press("forward")
	await frames(110)
	check(player.position.x < 3.7 and player.position.x > 3.5 and player.position.z < -5, "Capsule collides with wall and continues sliding along it")
	await reset_player()
	var ceiling := box(Vector3(5, 0.2, 5), Vector3(0, 2.1, 0))
	await frames(2)
	Input.action_press("jump")
	await frames(8)
	Input.action_release("jump")
	check(player.position.y < 0.23 and player.velocity.y <= 0, "Low ceiling blocks jump without capsule penetration")
	ceiling.queue_free()
	await reset_player()
	Input.action_press("jump")
	var jumps := 0
	var previous_y := 0.0
	for i in 115:
		await frames(1)
		if player.velocity.y > 4.0 and previous_y <= 0:
			jumps += 1
		previous_y = player.velocity.y
	check(jumps >= 3, "Held jump repeats after grounded delay")
	release_controls()
	await frames(60)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(100, 100000)
	player._unhandled_input(mouse)
	check(near(player.rotation.y, -0.23) and near(player.camera.rotation.x, -deg_to_rad(83.0)), "Mouse sensitivity and pitch limit read from configuration")
	player.movement.profile.values.look.invert_y = true
	player.camera.rotation.x = 0
	mouse.relative = Vector2(0, 10)
	player._unhandled_input(mouse)
	check(near(player.camera.rotation.x, 0.023), "Mouse Y inversion is configurable")
	player.controls_active = false
	player._unhandled_input(mouse)
	check(near(player.camera.rotation.x, 0.023), "Released controls ignore mouse look")

func run() -> void:
	parameter_checks()
	for action in ["forward", "back", "left", "right", "sprint", "jump", "reload_movement", "movement_debug", "release_mouse", "interact", "reset"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	arena = Node3D.new()
	root.add_child(arena)
	box(Vector3(100, 1, 100), Vector3(0, -0.5, 0))
	box(Vector3(0.2, 5, 100), Vector3(4, 2.5, 0))
	player = preload("res://scripts/player.gd").new()
	arena.add_child(player)
	await motor_checks()
	var report := "%d/%d movement checks passed" % [results.size() - failures.size(), results.size()]
	print(report)
	var file := FileAccess.open("res://tests/movement_results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results) + "\n" + report + "\n")
	file.close()
	quit(0 if failures.is_empty() else 1)
