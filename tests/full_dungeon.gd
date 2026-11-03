extends "res://tests/expansion.gd"
## Expanded normal world: independent source placements plus physical routes.
const SLOT := "res://saves/full_dungeon_test.json"
var deep_destination := Vector3.ZERO

func restore_deep() -> void:
	level.persistence.slot_path = SLOT
	check(await level.persistence.load_slot(), "Expanded deep-room save restores through a fresh validated candidate")
	level = current_scene
	player = level.player
	await frames(10)
	for enemy in level.enemies:
		enemy.melee.enabled = false
	check(player.position.distance_to(deep_destination) < 0.03 and level.doors.size() == 58 and level.doors.all(func(door: Node): return door.opened), "Deep position and all58 door states survive load")
	check(level.billboard_nodes.size() == 137 and player.teleport.anchor.size() == 5, "Decorations/static piles rebuild and deep Teleport anchor persists")
	player.position = level.classic.to_world([960,-512,1024])
	player.velocity = Vector3.ZERO
	check(player.teleport.arrive(player).is_empty() and player.position.distance_to(deep_destination) < 0.03 and player.teleport.anchor.is_empty(), "Saved anchor safely teleports into expanded border room and consumes once")

func vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func asset_checks() -> void:
	var bounds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/full_dungeon_assets/native_dimensions.json"))
	var correct_bounds := true
	for object in level.classic.objects:
		var expected: Dictionary = bounds.models[object.model]
		var mesh: MeshInstance3D = level.model_nodes[object.id].get_child(0)
		var box := mesh.mesh.get_aabb()
		correct_bounds = correct_bounds and box.position.distance_to(vector(expected.min)) < 0.001 and box.size.distance_to(vector(expected.size)) < 0.001
	check(correct_bounds, "Every added model retains independently audited raw ARCH3D bounds")
	var materials: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/full_dungeon_assets/classic_materials.json"))
	var correct_materials: bool = level.classic.texture_count == materials.size()
	for entry in materials:
		var material: StandardMaterial3D = level.classic.material_cache[int(entry.source)]
		var image: Image = material.albedo_texture.get_image()
		correct_materials = correct_materials and int(material.get_meta("resolved_texture")) == int(entry.resolved) and image.get_size() == Vector2i(entry.target_size[0], entry.target_size[1]) and digest(image.get_data()) == entry.rgb_sha256
		correct_materials = correct_materials and level.classic.source_texture_size(int(entry.source)) == Vector2(entry.source_size[0], entry.source_size[1])
	check(correct_materials, "All81 materials match independent Classic identities, source/target dimensions and RGB hashes")
	var flats: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/full_dungeon_assets/billboard_frames.json"))
	var correct_flats := flats.size() == 130
	for id in flats:
		var expected: Dictionary = flats[id]
		var sprite: AnimatedSprite3D = level.billboard_nodes[id]
		correct_flats = correct_flats and sprite.position.distance_to(level.classic.to_world(expected.native_position)) < 0.001 and sprite.original_size.distance_to(Vector2(expected.size_metres[0], expected.size_metres[1])) < 0.001
		for frame in expected.rgba_sha256.size():
			var image := sprite.sprite_frames.get_frame_texture("default", frame).get_image()
			correct_flats = correct_flats and digest(image.get_data()) == expected.rgba_sha256[frame]
	check(correct_flats, "All130 decorative flats retain independent positions, native dimensions and RGBA frames")
	var supported := true
	for entry in level.classic.section.definition.static_loot:
		var sprite: AnimatedSprite3D = level.billboard_nodes[entry.id]
		var bottom: Vector3 = sprite.position - Vector3.UP * sprite.original_size.y * 0.5
		var ray := PhysicsRayQueryParameters3D.create(bottom + Vector3.UP * 0.1, bottom + Vector3.DOWN * 0.1, 1)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
		supported = supported and not hit.is_empty() and absf(hit.position.y - bottom.y) < 0.01 and not sprite.has_method("interact")
	check(supported, "Seven visual-only loot piles rest on source floors without activation or invented contents")

func follow(points: Array, label: String) -> bool:
	Input.action_press("forward")
	var start_health: int = player.health.current
	for i in points.size():
		var target := vector(points[i])
		var arrived := false
		for tick in 180:
			if Vector2(player.position.x - target.x, player.position.z - target.z).length() < 0.17:
				arrived = true
				break
			player.look_at(Vector3(target.x, player.position.y, target.z))
			player.camera.rotation.x = 0
			await frames(1)
		if not arrived:
			Input.action_release("forward")
			print("ROUTE_STUCK ", label, " waypoint=", i, " position=", player.position, " target=", target)
			check(false, label + " continuous traversal")
			return false
	Input.action_release("forward")
	await frames(12)
	check(player.is_grounded() and player.position.distance_to(vector(points[-1])) < 0.4, label + " reaches supported endpoint")
	check(player.health.current == start_health, label + " has no damaging falls")
	return true

func source_checks() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dungeon_layout_inventory.json"))
	var expected: Dictionary = {}
	for block in fixture.blocks:
		for object in block.objects:
			if object.kind != 1:
				continue
			var key := "%s:%d" % [block.name, object.offset]
			expected[key] = {"block": block, "object": object}
	var matches := true
	for object in level.classic.objects:
		var key := "%s:%d" % [object.block, object.offset]
		if not expected.has(key):
			matches = false
			continue
		var entry: Dictionary = expected[key]
		var position: Array = entry.object.position_native
		var native := [position[0] + entry.block.x * 2048, position[1], position[2] + entry.block.z * 2048]
		matches = matches and object.model == entry.object.model and object.transform.origin.distance_to(level.classic.to_world(native)) < 0.001
		expected.erase(key)
	check(matches and expected.is_empty() and level.model_nodes.size() == 365, "All365 source model identities and MAPS grid transforms match independent inventory")
	check(level.doors.size() == 58 and level.door == level.model_nodes.first_door, "All58 original hinged doors load; primary alias retains authored order")
	check(level.billboard_nodes.size() == 137 and level.classic.section.definition.static_loot.size() == 7, "130 original decorative flats plus seven static marker piles load")
	check(level.classic.section.definition.prototype.boundaries.is_empty(), "All11 former branch caps are removed")
	check(level.enemies.size() == 2 and player.inventory.items.size() == 13 and player.health.maximum == 300, "Accepted bear/passive chamber/13items/300HP baseline retained")
	var exits: Array = level.model_nodes.values().filter(func(body: Node): return body.get_meta("section_role") == "exit")
	check(exits.size() == 1 and exits[0].has_method("interaction_prompt"), "Original exit is present with explicit exterior boundary interaction")
	exits[0].interact()
	check("not implemented" in exits[0].interaction_prompt(), "Exit activation explains unavailable exterior travel")
	var validator := preload("res://scripts/classic_section.gd").new()
	var changed: Dictionary = level.classic.section.definition.duplicate(true)
	changed.models[-1].block = "B0000999.RDB"
	check(not validator.validate(changed), "Unknown per-record block rejected")
	changed = level.classic.section.definition.duplicate(true)
	changed.source.blocks[1].x = 0
	check(not validator.validate(changed), "Duplicate block grid cell rejected")
	changed = level.classic.section.definition.duplicate(true)
	changed.source.blocks[1].x = -2
	var file := FileAccess.open("res://tests/full_dungeon_invalid.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(changed))
	file.close()
	var data := preload("res://scripts/classic_data.gd").new()
	check(not data.load_slice("res://tests/full_dungeon_invalid.json") and "block layout" in data.error, "Authored neighboring coordinates must match actual MAPS placements")
	DirAccess.remove_absolute("res://tests/full_dungeon_invalid.json")

func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var begin := Time.get_ticks_msec()
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(10)
	check(level.ready_to_play, "Expanded normal dungeon builds")
	if not level.ready_to_play:
		print(level.classic.error)
		quit(1)
		return
	player = level.player
	player.movement.profile.values.look.radians_per_pixel = 0.0
	for enemy in level.enemies:
		enemy.melee.enabled = false
		enemy.set_physics_process(false)
	if "--full-dungeon-read" in OS.get_cmdline_user_args():
		var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dungeon_floor_audit.json"))
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SLOT))
		deep_destination = vector(saved.player.position)
		check(deep_destination.distance_to(vector(routes.routes["B0000003.RDB"][-1])) < 0.2, "Separate-process slot records the physically reached border-room endpoint")
		await restore_deep()
		print("FULL_DUNGEON_RELOAD ", results.size() - failures.size(), "/", results.size())
		quit(0 if failures.is_empty() else 1)
		return
	source_checks()
	asset_checks()
	print("FULL_DUNGEON_IMPORT_MS ", Time.get_ticks_msec() - begin)
	# Exercise each real hinge with attached collision before route traversal.
	var opened := true
	var safe := true
	var home := player.position
	for door in level.doors:
		door.request_open(player)
	await frames(45)
	for door in level.doors:
		opened = opened and door.opened and not door.busy
		player.position = door.position
		door.interact()
		safe = safe and door.opened
	player.position = home
	check(opened, "Every selected door opens with its original leaf mesh and attached collider")
	check(safe, "Every door refuses unsafe closing beside the player")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dungeon_floor_audit.json"))
	for block in fixture.routes:
		var points: Array = fixture.routes[block]
		if not await follow(points, block + " outbound"):
			break
		if block == "B0000003.RDB":
			deep_destination = player.position
			player.teleport.set_anchor(player)
			level.persistence.slot_path = SLOT
			check(level.persistence.save_slot(), "Deep expanded border room saves to isolated test slot")
		if DisplayServer.get_name() != "headless":
			var behind := vector(points[maxi(0, points.size() - 8)])
			player.look_at(Vector3(behind.x, player.position.y, behind.z))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/full_" + block + ".png")
		var reverse := points.duplicate()
		reverse.reverse()
		if not await follow(reverse, block + " return"):
			break
	if failures.is_empty():
		if DisplayServer.get_name() != "headless":
			level.presentation.set_profile("widescreen")
		var stairs := [[960,-512,1024],[1560,-1024,1024],[1664,-1024,768],[1664,-1024,384],[1550,-1024,384],[1200,-1280,384]]
		for point in stairs:
			if not await walk(point):
				break
		if failures.is_empty():
			for name in fixture.upper_routes:
				var points: Array = fixture.upper_routes[name]
				if not await follow(points, "Upper " + name + " outbound"):
					break
				var reverse := points.duplicate()
				reverse.reverse()
				if not await follow(reverse, "Upper " + name + " return"):
					break
		if failures.is_empty():
			stairs.reverse()
			for point in stairs:
				if not await walk(point):
					break
	if failures.is_empty():
		await restore_deep()
	var file := FileAccess.open("res://tests/full_dungeon_results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results))
	print("FULL_DUNGEON_CHECKS ", results.size() - failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)
