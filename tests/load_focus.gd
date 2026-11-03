extends SceneTree
## Route events through the root viewport; direct _input calls miss the handoff.
var level: Node
var results: Array[String] = []
var failures: Array[String] = []
var watch_capture := false
var capture_interrupted := false

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
		if watch_capture and DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			capture_interrupted = true

func check(condition: bool, label: String) -> void:
	results.append(("PASS " if condition else "FAIL ") + label)
	print(results.back())
	if not condition:
		failures.append(label)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func mouse(button: MouseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = Vector2(640, 400)
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)

func bind() -> void:
	level = current_scene
	level.persistence.slot_path = "res://saves/focus_test.json"
	for enemy in level.enemies:
		enemy.melee.enabled = false

func load_once() -> void:
	var before = current_scene
	key(KEY_L)
	await frames(8)
	bind()
	check(current_scene != before and not level.restoring and not level.player.modal_open, "One routed L completes scene replacement")

func run() -> void:
	level = load("res://tests/skeleton_regression.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	bind()
	await frames(12)
	key(KEY_K)
	check(level.persistence.error.contains("complete"), "Routed K creates isolated test slot")
	var saved_position: Vector3 = level.player.position
	level.player.position.x += 0.5
	watch_capture = true
	await load_once()
	watch_capture = false
	check(not capture_interrupted, "Captured load never releases mouse during candidate initialization")
	check(level.player.controls_active, "One L immediately resumes captured gameplay without another click/load")
	check(level.player.position.distance_to(saved_position) < 0.03, "First L restores player position")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Rendered load retains native mouse capture")
	var yaw: float = level.player.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(25, 0)
	motion.position = Vector2(640, 400)
	root.push_input(motion, true)
	check(not is_equal_approx(yaw, level.player.rotation.y), "Mouse look reaches restored player after first L")
	var before_move: Vector3 = level.player.position
	Input.action_press("back")
	await frames(8)
	Input.action_release("back")
	check(level.player.position.distance_to(before_move) > 0.1, "Movement works after first L")
	check(level.player.combat.elapsed < 0, "Load does not start a weapon attack")
	level.loot_window.open_inventory()
	await load_once()
	check(level.player.controls_active and not level.loot_window.visible, "Loading from captured inventory restores gameplay controls")
	key(KEY_ESCAPE)
	check(not level.player.controls_active, "Escape deliberately releases controls")
	await load_once()
	check(not level.player.controls_active, "Load preserves deliberately released controls")
	mouse(MOUSE_BUTTON_RIGHT)
	check(level.player.controls_active and level.player.combat.elapsed < 0, "Single recapture click restores controls without attack")
	key(KEY_ESCAPE)
	level.loot_window.open_inventory()
	await load_once()
	check(not level.player.controls_active, "Loading from released inventory keeps prior released preference")
	mouse(MOUSE_BUTTON_LEFT)
	level.player.health.current = 0
	level.player.die()
	await load_once()
	check(level.player.controls_active and not level.player.is_dead(), "Loading from death resumes living gameplay immediately")
	print("LOAD FOCUS RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	FileAccess.open("res://tests/load_focus_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)


