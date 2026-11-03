extends SceneTree
var test_slot := "res://tests/swimming_slot.json"
var level: Node3D
var player: CharacterBody3D
var results: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		test_slot = "res://tests/swimming_rendered_slot.json"
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(value: bool, label: String) -> void:
	var entry := ("PASS " if value else "FAIL ") + label
	results.append(entry)
	if not value:
		failures.append(entry)
	print(entry)

func release() -> void:
	for action in ["forward", "back", "left", "right", "jump", "swim_up", "swim_down"]:
		Input.action_release(action)

func place(at: Vector3) -> void:
	release()
	player.swimming.reset()
	player.position = at
	player.climbing.reset()
	player.crouch.reset(player)
	player.falling.reset()
	player.swimming.clear_motion(player)
	player.controls_active = true
	player.health.current = 300
	player.fatigue.current = player.fatigue.maximum()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + label + ".png")

func routed(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await frames(2)
	event = InputEventKey.new()
	event.physical_keycode = code
	root.push_input(event)
	await frames(2)

func bind() -> void:
	level = current_scene
	player = level.player
	# Native mouse motion must not steer deterministic rendered traversal.
	player.movement.profile.values.look.radians_per_pixel = 0.0

func finish() -> void:
	release()
	FileAccess.open("res://tests/swimming_cross_process_results.txt" if "--swimming-read" in OS.get_cmdline_user_args() else "res://tests/swimming_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	print("SWIMMING RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	quit(0 if failures.is_empty() else 1)

func climb_from_water_checks() -> void:
	place(Vector3(194.4, -2.5, -4))
	player.rotation.y = PI / 2
	await frames(3)
	Input.action_press("forward")
	await frames(30)
	check(player.swimming.active and not player.climbing.active, "Water wall contact retains normal climb attachment delay")
	await frames(32)
	release()
	check(player.climbing.active and not player.swimming.active and player.swimming.immersed, "Swimmer attaches to wall with exclusive climb ownership")
	var hold := player.position
	var breath: float = player.swimming.breath_seconds
	await frames(12)
	check(player.position.distance_to(hold) < 0.02 and player.climbing.active and player.swimming.breath_seconds < breath, "Underwater wall hold keeps position and continues breath")
	await routed(KEY_C)
	breath = player.swimming.breath_seconds
	hold = player.position
	await frames(12)
	check(player.modal_open and player.position == hold and player.swimming.breath_seconds == breath, "Modal pauses underwater climbing and breath")
	await routed(KEY_ESCAPE)
	player.controls_active = false
	breath = player.swimming.breath_seconds
	await frames(12)
	check(player.climbing.active and player.position.distance_to(hold) < 0.02 and player.swimming.breath_seconds == breath, "Released controls retain wall hold and pause breath")
	player.controls_active = true
	player.movement.set_modifier("water_climb_test", {"climb":1.25})
	var start := player.position
	Input.action_press("forward")
	await frames(20)
	release()
	check(absf(player.position.y - start.y - float(player.movement.resolve().climb_walk_speed) / 3.0) < 0.06, "Underwater climb consumes live climb speed without simultaneous swim motion")
	player.movement.remove_modifier("water_climb_test")
	await capture("swimming_wall_climb")
	# Continue from the same attachment, through the surface and onto the rim.
	Input.action_press("forward")
	for i in 240:
		await frames(1)
		if not player.climbing.active and not player.swimming.wet and player.is_grounded():
			break
	release()
	print("WATER CLIMB EXIT ", player.position, " climb ", player.climbing.active, " transition ", player.climbing.transition, " swim ", player.swimming.active, " grounded ", player.is_grounded())
	check(player.position.x < 194 and absf(player.position.y) < 0.04 and player.is_grounded() and not player.swimming.wet, "Continuous swim-to-climb ascends past surface and mantles onto dry rim")
	check(player.health.current == 300 and player.swimming.breath_seconds < 0 and player.velocity.length() < 1, "Dry rim handover clears fall/motion safely and restores breath")
	await capture("swimming_wall_exit")
	# An ejection into the basin must resume swimming, not reattach immediately.
	place(Vector3(194.4, -2.5, -4))
	player.rotation.y = PI / 2
	Input.action_press("forward")
	await frames(65)
	release()
	breath = player.swimming.breath_seconds
	Input.action_press("jump")
	await frames(2)
	release()
	check(not player.climbing.active and player.swimming.active and player.climbing.cooldown > 0 and player.swimming.breath_seconds <= breath, "Climb ejection returns to swimming without breath reset or instant reattachment")
	await frames(15)
	check(player.swimming.active and not player.falling.active and player.health.current == 300, "Return to water suspends fall damage and preserves health")
	# Surface exclusions and crouch rules apply equally to water starts.
	level.climb_walls[0].set_meta("climbable", false)
	place(Vector3(194.4, -2, -4))
	player.rotation.y = PI / 2
	Input.action_press("forward")
	await frames(100)
	release()
	check(not player.climbing.active and player.swimming.active, "Excluded water wall never attaches")
	level.climb_walls[0].set_meta("climbable", true)
	place(Vector3(194.4, -2, -4))
	player.rotation.y = PI / 2
	player.crouch.set_height(player, player.crouch.HEIGHT)
	player.crouch.toggled = true
	player.crouch.requested = true
	player.crouch.active = true
	player.crouch.eye_height = player.crouch.EYE
	Input.action_press("forward")
	await frames(100)
	release()
	check(not player.climbing.active and player.crouch.is_low(player), "Crouched swimmer retains posture instead of forcing a standing climb")
	place(player.spawn)
	player.rotation.y = PI
	await frames(6)

func run() -> void:
	level = load("res://fixtures/swimming_pool.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(12)
	bind()
	if "--swimming-read" in OS.get_cmdline_user_args():
		level.persistence.slot_path = test_slot
		check(await level.persistence.load_slot(), "Separate process restores dry pool save")
		bind()
		await frames(6)
		check(not player.swimming.wet and player.swimming.volumes.size() == 1 and level.persistence.slot_path == test_slot, "Separate process reconstructs fixture water registry and isolated slot")
		finish()
		return
	check(level.ready_to_play and player.position.x > 190 and player.is_grounded(), "Opt-in scene starts on supported dry deck")
	check(player.health.maximum == 300 and player.magic.maximum() == 150 and player.inventory.items.size() == 13, "Pool uses accepted player resources and equipment")
	check(level.enemies.is_empty() and level.persistence.slot_path == "res://saves/swimming_pool.json", "Pool is isolated from enemies and manual save slot")
	level.persistence.slot_path = test_slot
	check(InputMap.action_get_events("swim_up")[0].physical_keycode == KEY_PAGEUP and InputMap.action_get_events("swim_down")[0].physical_keycode == KEY_PAGEDOWN, "Only Page Up and Page Down bind vertical swimming")
	check(is_equal_approx(player.swimming.maximum_breath(player), 31.25), "Endurance50 gives25 breath units at1.25 real seconds each")
	var invalid := preload("res://scripts/water_volume.gd").new()
	check(not invalid.configure(AABB(Vector3.ZERO, Vector3(-1, 2, 3))) and not invalid.configure(AABB(Vector3(INF, 0, 0), Vector3.ONE)), "Invalid water bounds reject")
	await capture("swimming_deck_4_3")
	# One continuous walk down the real treads, into water, out over deep basin.
	Input.action_press("forward")
	await frames(420)
	release()
	print("ENTRY POSITION ", player.position, " swim ", player.swimming.active)
	check(player.position.z < -1 and player.swimming.active and player.health.current == 300, "Continuous dry entry descends steps and reaches deep water safely")
	var start := player.position
	Input.action_press("forward")
	await frames(60)
	release()
	var speed := (player.position - start).length()
	check(absf(speed - float(player.movement.resolve().swim_walk_speed)) < 0.06, "Actual swim motion consumes live resolved speed")
	Input.action_press("swim_down")
	await frames(60)
	release()
	check(player.swimming.submerged and player.swimming.breath_seconds > 29 and player.swimming.breath_seconds < 31.25, "Page Down dives and starts real-time breath")
	player.rotation.y = PI
	await capture("swimming_underwater_4_3")
	player.rotation.y = 0
	var hp: int = player.health.current
	await frames(60)
	check(player.health.current == hp, "Breath use causes no gradual health damage")
	var breath: float = player.swimming.breath_seconds
	var clock: float = player.fatigue.game_seconds
	player.controls_active = false
	var frozen := player.position
	await frames(90)
	check(player.position.distance_to(frozen) < 0.001 and player.swimming.breath_seconds == breath and player.fatigue.game_seconds == clock, "Released controls suspend swimming and pause breath/awake clock")
	player.controls_active = true
	await routed(KEY_C)
	frozen = player.position
	breath = player.swimming.breath_seconds
	await frames(60)
	check(player.modal_open and player.position == frozen and player.swimming.breath_seconds == breath, "Character modal freezes swim motion and breath")
	await routed(KEY_I)
	check(level.loot_window.visible and not level.character_sheet.visible, "Underwater modal switches retain single-panel ownership")
	await routed(KEY_ESCAPE)
	check(player.controls_active and not player.modal_open, "Modal close restores captured swim controls")
	check(level.persistence.refusal() == "Leave the water before saving." and level.rest_window.rest.refusal() == "Leave the water before resting.", "Water refuses K and rest regardless of bottom support")
	# Page Up reaches a stable surface, without oscillation or a jump boost.
	Input.action_press("swim_up")
	await frames(180)
	var surface_y := player.position.y
	await frames(120)
	release()
	check(player.swimming.active and not player.swimming.submerged and absf(player.position.y - surface_y) < 0.003 and player.swimming.breath_seconds < 0, "Page Up surfaces stably and restores breath")
	Input.action_press("jump")
	await frames(15)
	release()
	check(absf(player.position.y - surface_y) < 0.003, "Space does not ascend or jump while swimming")
	player.rotation.y = PI
	Input.action_press("forward")
	await frames(720)
	release()
	print("EXIT POSITION ", player.position, " swim ", player.swimming.active)
	check(player.position.z > 9 and not player.swimming.wet and player.is_grounded(), "Continuous return climbs visible steps and exits onto dry deck")
	await climb_from_water_checks()
	# Repeated entry/exit above covers handover; isolated placements test boundaries.
	place(Vector3(200, -2, -2))
	await frames(3)
	player.character.set_live({"swimming":0})
	start = player.position
	Input.action_press("right")
	await frames(30)
	release()
	check(absf((player.position-start).length()*2 - float(player.movement.resolve().swim_walk_speed)) < 0.08, "Swimming0 reaches actual motor speed")
	player.character.set_live({"swimming":100})
	player.movement.set_modifier("swim_test", {"swim":1.5})
	start = player.position
	Input.action_press("forward")
	Input.action_press("right")
	Input.action_press("swim_up")
	await frames(10)
	release()
	check(absf((player.position-start).length()*6 - float(player.movement.resolve().swim_walk_speed)) < 0.12, "Live Swimming100/modifier and3-axis normalization reach actual speed")
	player.character.set_live({})
	player.movement.remove_modifier("swim_test")
	check(player.reload_movement(), "Atomic three-config reload remains available in water")
	player.movement.profile.values.look.radians_per_pixel = 0.0
	# Full capsule contacts at side wall and bottom.
	place(Vector3(205.2, -2, -3))
	Input.action_press("left") # Facing PI: left moves toward +X.
	await frames(90)
	release()
	check(player.position.x < 205.67 and player.position.x > 205.5, "Full capsule stops at pool wall")
	Input.action_press("swim_down")
	await frames(150)
	release()
	check(player.position.y >= -4.01 and player.position.y < -3.9 and player.swimming.active, "Bottom contact preserves swim ownership without floor snap")
	check(not level.persistence.placement_valid(), "Candidate placement rejects underwater bottom")
	var ceiling: StaticBody3D = level.box(Vector3(2, 0.3, 2), Vector3(3, -0.4, -3), Color.GRAY)
	place(Vector3(203, -2.5, -3))
	Input.action_press("swim_up")
	await frames(90)
	release()
	check(player.position.y < -2.33 and player.position.y > -2.4, "Full capsule stops below an underwater ceiling")
	ceiling.queue_free()
	await frames(2)
	player.fatigue.current = player.fatigue.maximum()
	player.fatigue.game_seconds = 0
	player.character.set_live({"swimming":0})
	player.tick_fatigue(5, "swimming")
	check(player.fatigue.current == player.fatigue.maximum() - 44, "Swimming0 failure spends44 raw per game minute")
	player.character.set_live({"swimming":100})
	player.tick_fatigue(5, "swimming")
	check(player.fatigue.current == player.fatigue.maximum() - 55, "Swimming100 success spends11 raw per game minute")
	player.character.set_live({})
	# Teleport preserves breath underwater and refills only on reaching air.
	place(Vector3(200, -2.5, -3))
	await frames(3)
	player.teleport.set_anchor(player)
	var anchor: Dictionary = player.teleport.snapshot()
	player.swimming.breath_seconds = 7.0
	player.position = Vector3(201, -2.5, -3)
	check(player.teleport.arrive(player).is_empty() and player.swimming.active and player.swimming.submerged and player.swimming.breath_seconds == 7, "Underwater Teleport reclassifies immediately without breath reset")
	player.teleport.restore(anchor)
	player.position = player.spawn
	player.swimming.reclassify(player)
	check(not player.swimming.active and player.swimming.breath_seconds < 0, "Dry arrival clears immersion and restores breath")
	player.teleport.set_anchor(player)
	player.position = Vector3(201, -2.5, -3)
	player.swimming.reclassify(player)
	player.swimming.breath_seconds = 4
	check(player.teleport.arrive(player).is_empty() and not player.swimming.wet and player.swimming.breath_seconds < 0, "Actual Teleport into air resets breath")
	player.teleport.restore(anchor)
	check(player.teleport.arrive(player).is_empty() and player.swimming.active and player.swimming.submerged, "Actual Teleport from dry deck into water takes swim ownership")
	# Deep interception protects a fall; shallow floor still receives damage.
	place(Vector3(203, 9, -3))
	await frames(110)
	check(player.health.current == 300 and player.swimming.active and not player.falling.active, "Deep basin intercepts falling player before floor damage")
	place(Vector3(200, 9, 7.25))
	await frames(110)
	check(player.health.current < 300 and not player.swimming.active, "Thin water over shallow tread does not negate solid-floor fall damage")
	place(Vector3(200, 9, 4.25))
	await frames(110)
	check(player.health.current < 300, "Intermediate-depth water also preserves accrued high-fall damage")
	check(player.swimming.fatigue_cost(25, 25) == 11 and player.swimming.fatigue_cost(25, 26) == 44, "Source Swimming roll selects11 or44 raw fatigue")
	# Exhaustion and breath depletion kill immediately through shared health.
	place(Vector3(203, -2.5, -3))
	await frames(3)
	player.spell_effects.shield.cast(5, 120)
	player.swimming.breath_seconds = 0.02
	hp = player.health.current
	await frames(1)
	check(player.health.current == hp, "Positive remaining breath causes no HP loss")
	await frames(2)
	check(player.is_dead() and player.health.current == 0 and player.swimming.death_reason == "You drowned.", "Zero breath instantly kills despite active Shield")
	await routed(KEY_R)
	bind()
	await frames(12)
	check(not player.is_dead() and not player.swimming.wet and player.swimming.breath_seconds < 0 and player.position.distance_to(player.spawn) < 0.15, "R recreates dry pool start and clears breath/transients")
	place(Vector3(203, -2, -3))
	await frames(3)
	player.fatigue.current = 0
	await frames(2)
	check(player.is_dead() and player.swimming.death_reason.contains("exhaustion"), "Exhaustion while swimming causes source-style drowning")
	await routed(KEY_R)
	bind()
	await frames(12)
	level.presentation.set_profile("widescreen")
	await capture("swimming_deck_widescreen")
	place(Vector3(203, -2.5, -3))
	await frames(3)
	await capture("swimming_underwater_widescreen")
	place(player.spawn)
	await frames(12)
	level.persistence.slot_path = test_slot
	var forged: Dictionary = level.persistence.snapshot()
	forged.player.position = [200, -4, -3]
	check(level.persistence.validate(forged), "Structurally valid water position still requires candidate placement validation")
	check(level.persistence.save_slot(), "Dry pool saves use separate slot")
	var saved: Dictionary = level.persistence.read_slot()
	check(saved.version == 9 and level.persistence.validate(saved), "Dry-only pool save keeps schema9")
	await routed(KEY_L)
	bind()
	await frames(6)
	check(not player.swimming.active and not player.swimming.submerged and player.controls_active and level.persistence.slot_path == test_slot and player.spawn.x == 200, "L restores pool scene, water registry and capture from separate slot")
	# Candidate collision/water validation must refuse forged underwater placement.
	var good_path: String = level.persistence.slot_path
	level.persistence.slot_path = test_slot.trim_suffix(".json") + "_invalid.json"
	check(level.persistence.write_slot(forged), "Writes isolated forged placement fixture")
	var old_level := level
	check(not await level.persistence.load_slot() and current_scene == old_level and player.controls_active, "Unsafe underwater load rejects before candidate swap and retains live controls")
	level.persistence.slot_path = good_path
	# Load must also resume a drowned player from the dry slot.
	place(Vector3(203, -2, -3))
	await frames(3)
	player.swimming.breath_seconds = 0.001
	await frames(2)
	await routed(KEY_L)
	bind()
	await frames(6)
	check(not player.is_dead() and not player.swimming.wet and player.controls_active, "L from drowning restores dry player and captured controls")
	var dungeon = load("res://main.tscn").instantiate()
	dungeon.restoring = true
	root.add_child(dungeon)
	await frames(6)
	check(not dungeon.persistence.validate(saved) and dungeon.player.swimming.volumes.is_empty(), "Normal dungeon rejects pool save context and contains no test water")
	dungeon.queue_free()
	finish()

