extends SceneTree
var level: Node3D
var results: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	results.append(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures.append(label)
	print(results[-1])

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func walk_to(point: Vector3, limit: int = 360) -> void:
	var player: CharacterBody3D = level.player
	player.look_at(Vector3(point.x, player.position.y, point.z))
	Input.action_press("forward")
	for i in limit:
		await physics_frame
		if Vector2(player.position.x - point.x, player.position.z - point.z).length() < 0.18:
			break
	Input.action_release("forward")
	await frames(12)

func screenshot(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func try_section(definition: Dictionary) -> RefCounted:
	var file := FileAccess.open("res://tests/section_test_case.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(definition))
	file.close()
	var data := preload("res://scripts/classic_data.gd").new()
	data.arena_path = level.classic.arena_path
	data.load_slice("res://tests/section_test_case.json")
	return data

func section_checks() -> void:
	var original: Dictionary = level.classic.section.definition
	var validator := preload("res://scripts/classic_section.gd").new()
	check(validator.validate(original), "Section JSON schema accepts current definition")
	var changed: Dictionary = original.duplicate(true)
	changed.models.pop_back()
	changed.billboards.pop_back()
	changed.prototype.enemies.clear()
	var alternate := try_section(changed)
	check(alternate.error.is_empty() and alternate.objects.size() == 8 and alternate.billboards.size() == 2, "Alternate section selects fewer original objects without code edits")
	changed = original.duplicate(true)
	changed.models[1].id = changed.models[0].id
	check(not validator.validate(changed) and "duplicate" in validator.error, "Duplicate section IDs rejected")
	changed = original.duplicate(true)
	changed.models[1].record_offset = changed.models[0].record_offset
	check(not validator.validate(changed) and "record_offset" in validator.error, "Duplicate original record offsets rejected")
	changed = original.duplicate(true)
	changed.origin_native = [0, 0]
	check(not validator.validate(changed), "Malformed native coordinate vector rejected")
	changed = original.duplicate(true)
	changed.billboards[0].expected_archive = 199
	check(not validator.validate(changed), "Editor markers cannot be selected as visible decoration")
	changed = original.duplicate(true)
	changed.schema_version = 99
	check(not validator.validate(changed), "Unsupported section schema rejected")
	changed = original.duplicate(true)
	changed.models[0].expected_model = "60201"
	var wrong_model := try_section(changed)
	check("expected model 60201, found 60200" in wrong_model.error, "Original model mismatch reports expected and actual IDs")
	changed = original.duplicate(true)
	changed.models[0].record_offset = 99999999
	var missing_record := try_section(changed)
	check("opening_cave" in missing_record.error and "missing" in missing_record.error, "Missing source record identifies section entry")
	changed = original.duplicate(true)
	changed.billboards[0].expected_record = 6
	var wrong_flat := try_section(changed)
	check("expected texture 206:6, found 206:5" in wrong_flat.error, "Billboard identity mismatch reports archive and record")
	changed = original.duplicate(true)
	changed.spawn.record_offset = 33966
	var wrong_spawn := try_section(changed)
	check("spawn" in wrong_spawn.error, "Wrong original spawn record rejected")
	check(not validator.load_file("res://tests/no_such_section.json"), "Missing section file reports failure")
	var malformed := FileAccess.open("res://tests/section_test_case.json", FileAccess.WRITE)
	malformed.store_string("{ invalid json")
	malformed.close()
	check(not validator.load_file("res://tests/section_test_case.json") and "Invalid JSON" in validator.error, "Malformed section JSON reports parse error")
	DirAccess.remove_absolute("res://tests/section_test_case.json")

func decoration_checks() -> void:
	check(level.billboard_nodes.size() == 3 and level.classic.billboards.size() == 3, "Three original decorative flats selected")
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/decorations/billboard_frames.json"))
	for id in fixtures:
		var expected: Dictionary = fixtures[id]
		var sprite: AnimatedSprite3D = level.billboard_nodes[id]
		check(sprite.position.distance_to(level.classic.to_world(expected.native_position)) < 0.001, id + " preserves original RDB centre")
		check(sprite.original_size.distance_to(Vector2(expected.size_metres[0], expected.size_metres[1])) < 0.001 and sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, id + " uses original dimensions and yaw-facing billboard")
		check(sprite.sprite_frames.get_frame_count("default") == expected.rgba_sha256.size(), id + " has all original frames")
		for frame in expected.rgba_sha256.size():
			var image: Image = sprite.sprite_frames.get_frame_texture("default", frame).get_image()
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(image.get_data())
			check(image.get_format() == Image.FORMAT_RGBA8 and hash.finish().hex_encode() == expected.rgba_sha256[frame], "%s frame %d matches independent transparent RGBA decode" % [id, frame])
		check(sprite.get_child_count() == 0, id + " has no blocking collision children")
	var fire: AnimatedSprite3D = level.billboard_nodes.cave_fire
	var previous := fire.frame
	await frames(7)
	check(fire.is_playing() and fire.frame != previous, "Original fire animation advances")
	for id in ["chamber_prop_north", "chamber_prop_south"]:
		var body: StaticBody3D = level.model_nodes[id]
		var bounds: AABB = body.get_child(0).mesh.get_aabb()
		var center: Vector3 = body.transform * bounds.get_center()
		var query := PhysicsRayQueryParameters3D.create(center - Vector3.RIGHT * 1.8, center, 1)
		var hit: Dictionary = level.world_root.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider == body, id + " original 3D prop has working mesh collision")

func run() -> void:
	level = load("res://main.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(90)
	check(level.ready_to_play, "Original source loads")
	if not level.ready_to_play:
		print("LOAD ERROR: ", level.classic.error)
		quit(1)
		return
	check(level.classic.provenance.block == "S0000999.RDB", "MAPS resolves original starting block")
	check(level.classic.provenance.location_id == 50049, "Privateer's Hold location ID")
	check(level.classic.objects.size() == 9 and level.classic.triangle_count == 354, "Nine original RDB placements and 354 ARCH3D triangles")
	check(level.classic.texture_count == 21, "All 21 original slice materials decoded")
	section_checks()
	await decoration_checks()
	check(level.classic.provenance.dungeon_id == 50050, "Texture seed uses dungeon ID, not exterior ID")
	check(level.classic.provenance.climate == 231 and level.classic.provenance.map_pixel == Vector2i(109, 158), "Original climate PAK resolves Privateer's Hold woodlands")
	check(level.classic.dungeon_textures.table == [23, 22, 19, 22, 20, 368], "Classic texture table matches Privateer's Hold reference")
	var climate_cases := preload("res://scripts/classic_dungeon_textures.gd").new()
	var climate_swaps_valid := true
	for pair in [[224, 74], [226, 174], [228, 474], [231, 374], [229, 74]]:
		climate_cases.configure(50050, pair[0])
		climate_swaps_valid = climate_swaps_valid and climate_cases.resolve(74) == pair[1]
	check(climate_swaps_valid, "Door climate bases follow DFU, including subtropical desert")
	var material_fixture: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/texture_fidelity/classic_materials.json"))
	for case in material_fixture:
		var material: StandardMaterial3D = level.classic.material_cache[int(case.source)]
		var pixels: Image = material.albedo_texture.get_image()
		var source_size: Vector2 = level.classic.source_texture_size(int(case.source))
		var valid: bool = int(material.get_meta("resolved_texture")) == int(case.resolved)
		valid = valid and pixels.get_size() == Vector2i(case.target_size[0], case.target_size[1])
		valid = valid and source_size == Vector2(case.source_size[0], case.source_size[1])
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(pixels.get_data())
		valid = valid and hash.finish().hex_encode() == case.rgb_sha256
		check(valid, "Classic material %d matches expected archive, record, dimensions and decoded pixels" % int(case.source))
	# Material swaps must leave native vertex positions and tiling unchanged.
	var raw := preload("res://scripts/classic_data.gd").new()
	raw.arena_path = level.classic.arena_path
	assert(raw.load_slice(level.section_path))
	raw.dungeon_textures.table.assign([119, 120, 122, 123, 124, 168])
	raw.dungeon_textures.climate_base = 0
	for item in level.classic.objects:
		var original: ArrayMesh = raw.build_mesh(item.model)
		var body: Node3D = level.world_root.get_node("Classic_%s_%d" % [item.model, item.offset])
		var themed: ArrayMesh = body.get_child(0).mesh
		var unchanged := original.get_surface_count() == themed.get_surface_count()
		for surface in original.get_surface_count():
			var source_arrays := original.surface_get_arrays(surface)
			var target_arrays := themed.surface_get_arrays(surface)
			unchanged = unchanged and source_arrays[Mesh.ARRAY_VERTEX] == target_arrays[Mesh.ARRAY_VERTEX]
			unchanged = unchanged and source_arrays[Mesh.ARRAY_TEX_UV] == target_arrays[Mesh.ARRAY_TEX_UV]
		check(unchanged, "Model %s retains vertex and UV buffers after texture swaps" % item.model)
	check(level.player.is_on_floor() and absf(level.player.position.y) < 0.08, "Player rests on original floor")
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/scale_calibration/native_dimensions.json"))
	var capsule: CapsuleShape3D = level.player.get_child(0).shape
	check(is_equal_approx(capsule.height, audit.player.height) and is_equal_approx(capsule.radius, audit.player.radius), "Player capsule matches DFU dimensions")
	check(is_equal_approx(level.player.camera.position.y, audit.player.eye_height), "Standing eye height matches DFU")
	check(is_equal_approx(level.player.camera.fov, audit.camera.vertical_fov) and level.player.camera.keep_aspect == Camera3D.KEEP_HEIGHT, "75-degree vertical camera convention matches evidence")
	var initial_profile: String = level.presentation.profile
	level.presentation.set_profile("dfu_reference")
	await frames(3)
	check(level.presentation.viewport.size == Vector2i(640, 400), "DFU reference renders 16:10 before presentation")
	var projection: Projection = level.player.camera.get_camera_projection()
	check(absf(projection.y.y / projection.x.x - 1.6) < 0.001, "Camera projection retains DFU 16:10 aspect")
	check(absf(level.presentation.display_rect.size.aspect() - 4.0 / 3.0) < 0.002, "Retro image presents at corrected 4:3 aspect")
	for item in level.classic.objects:
		var body: Node3D = level.world_root.get_node("Classic_%s_%d" % [item.model, item.offset])
		var bounds: AABB = body.get_child(0).mesh.get_aabb()
		var expected: Dictionary = audit.models[item.model]
		var low := Vector3(expected.min[0], expected.min[1], expected.min[2])
		var size := Vector3(expected.size[0], expected.size[1], expected.size[2])
		check(bounds.position.distance_to(low) < 0.001 and bounds.size.distance_to(size) < 0.001, "Model %s dimensions agree with independent raw-point audit" % item.model)
	var original_position: Vector3 = level.player.position
	var toggle := InputEventAction.new()
	toggle.action = "toggle_view"
	toggle.pressed = true
	Input.parse_input_event(toggle)
	Input.action_release("toggle_view")
	await frames(3)
	check(level.presentation.profile == "widescreen" and level.presentation.viewport.size == Vector2i(root.get_visible_rect().size), "F2 switches to full-window widescreen")
	check(level.player.position.distance_to(original_position) < 0.01, "Changing presentation preserves player/world position")
	level.presentation.set_profile(initial_profile)
	var movement_event := InputEventKey.new()
	movement_event.physical_keycode = KEY_F4
	movement_event.pressed = true
	Input.parse_input_event(movement_event)
	await frames(3)
	check(level.player.show_movement_debug and level.movement_status.visible and "Walk" in level.movement_status.text, "F4 reaches separate world viewport and displays movement diagnostics")
	await screenshot("res://tests/movement_debug.png")
	movement_event.pressed = false
	Input.parse_input_event(movement_event)
	level.player.show_movement_debug = false
	level.player.movement.set_live_stats({"speed_attribute": 70.0})
	level.player.movement.profile.values.physics.gravity = 7.0
	movement_event = InputEventKey.new()
	movement_event.physical_keycode = KEY_F3
	movement_event.pressed = true
	Input.parse_input_event(movement_event)
	await frames(3)
	var movement_file := ConfigFile.new()
	movement_file.load("res://movement.cfg")
	check(level.player.movement.profile.values.physics.gravity == movement_file.get_value("physics", "gravity", 20.0) and level.player.movement.stat("speed_attribute") == 70.0 and level.player.position.distance_to(original_position) < 0.01, "F3 reloads tuning without resetting character overrides or world position")
	movement_event.pressed = false
	Input.parse_input_event(movement_event)
	level.player.movement.set_live_stats({})
	await screenshot("res://tests/start_room.png")
	var center: Vector3
	# Use actual imported mesh bounds to locate the opening rather than guessed coordinates.
	var instance: MeshInstance3D = level.door.get_child(0)
	center = level.door.transform * instance.mesh.get_aabb().get_center()
	var normal := Vector3(-1, 0, 0)
	var inside := center + normal * 1.2
	inside.y = 0.02
	print("DOOR center=", center, " player=",level.player.position)
	for waypoint in [Vector3(512, 0, -1200), Vector3(512, 0, -1000), Vector3(512, 0, -800), Vector3(750, 0, -768)]:
		await walk_to(waypoint * 0.025 - level.classic.origin)
		print("WAYPOINT ",level.player.position)
	await walk_to(inside)
	check(level.player.position.distance_to(inside) < 0.6, "Walk from original start to door")
	level.player.look_at(Vector3(center.x - normal.x * 2, level.player.position.y, center.z - normal.z * 2))
	Input.action_press("forward")
	await frames(90)
	Input.action_release("forward")
	await frames(12)
	check((level.player.position - center).dot(normal) > 0.18, "Closed original door blocks capsule")
	level.player.camera.look_at(center)
	await frames(3)
	check(level.player.interact_target == level.door, "Look ray acquires nearby door")
	check(not level.enemy.noticed, "Closed door occludes enemy sight")
	var use_event := InputEventAction.new()
	use_event.action = "interact"
	use_event.pressed = true
	Input.parse_input_event(use_event)
	await frames(2)
	Input.action_release("interact")
	await frames(60)
	check(level.door.opened and not level.door.busy, "E interaction opens animated collidable door")
	level.player.camera.rotation.x = 0
	var beyond := center - normal * 2.5
	beyond.y = 0.02
	await walk_to(beyond, 180)
	print("AFTER DOOR player=",level.player.position," target=",beyond," enemy=",level.enemy.position)
	check((level.player.position - center).dot(normal) < -1.2, "Walk through open door onto original corridor")
	check(level.player.is_on_floor(), "Corridor floor supports player")
	await frames(90)
	check(level.encounter and level.enemy.noticed, "Enemy detects player through open passage")
	level.player.camera.look_at(level.enemy.global_position + Vector3.UP * 0.5)
	await screenshot("res://tests/enemy_encounter.png")
	# Test caps at the original openings, using physics rays across each boundary.
	for pair in [[Vector3(1080, 60, -640), Vector3(980, 60, -640)]]:
		var query := PhysicsRayQueryParameters3D.create(pair[0] * 0.025 - level.classic.origin, pair[1] * 0.025 - level.classic.origin, 1)
		var hit: Dictionary = level.world_root.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider.is_in_group("slice_boundaries"), "Greybox passage cap blocks boundary ray")
	level.player.position = center + normal * 0.5
	level.player.position.y = 0.01
	level.door.interact()
	check(level.door.opened, "Door refuses unsafe close beside player")
	level.player.position = center + normal * 3.0
	level.player.position.y = 0.01
	level.door.interact()
	await frames(60)
	check(not level.door.opened and not level.door.busy, "Door closes again when clear")
	var missing := preload("res://scripts/classic_data.gd").new()
	missing.arena_path = "res://tests/absent_arena2"
	check(not missing.load_slice() and not missing.error.is_empty(), "Missing original data produces explicit failure")
	# Moving into the room wall must stop, independent of the door collider.
	level.player.position = Vector3(0, 0.05, 0)
	await frames(15)
	await walk_to(Vector3(30, 0.05, 0), 360)
	check(level.player.position.x < 7 and level.player.is_on_floor(), "Original room wall blocks player")
	var file := FileAccess.open("res://tests/results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results) + "\n")
	print("TESTS ", results.size() - failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)






