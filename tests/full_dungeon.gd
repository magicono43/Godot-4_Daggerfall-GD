extends "res://tests/expansion.gd"
## Expanded normal world: independent source placements plus physical routes.
const SLOT := "res://saves/full_dungeon_test.json"
var deep_destination := Vector3.ZERO
const ACTION_SLOT := "res://tests/output/actions_save.json"
const RAT_SLOT := "res://tests/output/rats_save.json"

func rat_checks() -> void:
	await frames(60)
	check(level.enemies.size() == 17 and level.enemies.filter(func(actor: Node): return actor.creature_name == "Rat").size() == 8 and level.enemies.filter(func(actor: Node): return actor.creature_name == "Skeleton").size() == 3, "Normal dungeon contains eight rats, three skeletons and six bats, no prototype targets")
	check(not level.world_root.has_node("hall_combat_target") and not level.world_root.has_node("placeholder_enemy") and level.enemies.all(func(actor: Node): return not actor.loot_enabled and actor.loot.items.is_empty()), "Retired targets and their loot are absent; rats have no invented loot")
	var start_delta: Vector3 = player.position - level.classic.provenance.start
	check(not level.classic.section.definition.prototype.has("player_start") and Vector2(start_delta.x,start_delta.z).length() < 0.15 and player.is_grounded() and player.inventory.items.size() == 13 and player.health.maximum == 300 and player.magic.maximum() == 150, "Original199:8 start restores cave entry while test equipment/HP/magicka remain")
	await action_capture("rat_start", player.position, level.classic.to_world(level.classic.section.definition.spawn.look_at_native) + Vector3.UP*1.5)
	var first: CharacterBody3D = level.world_root.get_node("s0000999_r32850")
	var second: CharacterBody3D = level.world_root.get_node("s0000999_r32958")
	for other in level.enemies:
		if other not in [first,second]:
			other.set_physics_process(false)
			other.melee.enabled = false
			other.collision_layer = 0
			other.collision_mask = 0
	for actor in [first, second]:
		var selected: Dictionary = level.classic.fixed_enemies.filter(func(entry: Dictionary): return entry.id == actor.name)[0]
		var delta: Vector3 = actor.position - selected.position
		check(Vector2(delta.x,delta.z).length() < 0.001 and absf(delta.y) < 1.2 and actor.is_on_floor(), "Fixed marker %s settles on source floor without horizontal relocation" % actor.name)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = actor.get_child(0).shape
		query.collision_mask = 1
		query.exclude = [actor.get_rid()]
		query.transform = actor.global_transform * actor.get_child(0).transform
		query.transform.origin.y += 0.03
		check(actor.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "Rat capsule clears original geometry at " + String(actor.name))
		check(actor.health.current == 9 and actor.combat_stats.stat("hand_to_hand") == 35 and actor.combat_stats.stat("agility") == 80 and actor.combat_stats.base_armor == 30 and not actor.can_open_doors, "Rat source stats/HP policy and door restriction at " + String(actor.name))
		actor.set_physics_process(false)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/enemies/rat_frames.json"))
	var matching := true
	var count := 0
	for id in fixture:
		var expected: Dictionary = fixture[id]
		var record: Dictionary = first.sprite_payload.corpse if id == "401:1" else first.sprite_payload.records[int(id.split(":")[1])]
		matching = matching and record.frames.size() == int(expected.frames) and record.size_metres.distance_to(Vector2(expected.metres[0],expected.metres[1])) < 0.0001
		for i in record.frames.size():
			matching = matching and digest(record.frames[i].get_image().get_data()) == expected.rgba_sha256[i]
			count += 1
	check(matching and count == 81, "All81 native rat/corpse frames match independent dimensions/RGBA evidence")
	for direction in 8:
		first.mobile.set_state("idle")
		first.mobile.select_view(first.position + first.global_basis * Vector3(-sin(direction*PI/4),0,-cos(direction*PI/4))*5)
		check(first.mobile.orientation == direction and first.mobile.flip_h == (direction in [1,2,3]), "Rat idle direction%d uses native special mirroring" % direction)
	first.mobile.set_state("move")
	first.mobile.tick(7.0/6.0)
	check(first.mobile.source_frame == 7, "Rat movement uses all eight frames rather than skeleton four-frame limit")
	var changed: Dictionary = level.classic.section.definition.duplicate(true)
	changed.fixed_enemies[0].expected_sound_index = 2
	FileAccess.open("res://tests/output/rat_source_case.json",FileAccess.WRITE).store_string(JSON.stringify(changed))
	var data := ClassicData.new()
	check(not data.load_slice("res://tests/output/rat_source_case.json") and "Source enemy mismatch" in data.error, "Wrong fixed-marker source fields reject before scene assembly")
	# Walk the original cave/first-door route with rat motors frozen, then test combat independently.
	player.controls_active = true
	var route := [[512,0,1200],[512,0,1000],[512,0,800],[750,0,768],[850,0,768],"first_door",[960,0,768],[1080,0,768],[1080,0,640],[1040,0,560]]
	for point in route:
		if point is String:
			await open_door(point)
		elif not await walk(point):
			break
	check(player.position.distance_to(first.position) < 2.0, "First rat room is continuously reachable from original new-game spawn")
	await action_capture("rat_encounter", first.position + Vector3(1.5,0,-2.4), first.position + Vector3.UP*0.35)
	# Exercise the production local steering with a nearby visible player.
	player.set_physics_process(false)
	place_actor(first.position + Vector3(0,0,-3.0))
	first.navigation.enabled = true
	first.melee.enabled = false
	first.set_physics_process(true)
	var pursuit_start := first.position
	await frames(45)
	print("RAT_PURSUIT ",pursuit_start," -> ",first.position," state=",first.navigation.state)
	check(first.position.distance_to(pursuit_start) > 0.25 and first.position.distance_to(player.position) < pursuit_start.distance_to(player.position), "Native rat pursues visible player using existing local ground navigation")
	first.set_physics_process(false)
	# Place player beside the rat solely for controlled animation/strike checks.
	place_actor(first.position + Vector3(0,0,1.2))
	player.set_physics_process(false)
	await frames(2)
	first.melee.enabled = true
	first.melee.resolver = preload("res://tests/fixed_combat.gd").new()
	var cues: Array = []
	level.combat_audio.played.connect(func(event: String, ordinal: int, spatial: bool): cues.append([event,ordinal,spatial]))
	first.play_sound("skeleton_move")
	check(cues.back() == ["rat_move",115,true], "Rat voice uses own source ordinal and spatial creature ownership")
	level.combat_audio.stop_creature(first)
	check(level.combat_audio.voices.all(func(voice: Node): return voice.get_meta("creature_owner",0) != first.get_instance_id()), "Stopping rat voice uses shared bounded creature lifecycle")
	check(level.rest_window.rest.refusal().contains("Enemies"), "Living nearby source rat blocks unsafe rest")
	first.melee.cancel()
	first.mobile.set_state("idle")
	var hp: int = player.health.current
	first.melee.tick(first,0.0)
	first.mobile.tick(0.299)
	first.melee.tick(first,0.299)
	check(player.health.current == hp and first.melee.phase == "windup", "Rat strike waits for original0.3s event")
	first.mobile.tick(0.001)
	first.melee.tick(first,0.001)
	var damaged: int = player.health.current
	first.mobile.tick(0.1)
	first.melee.tick(first,0.1)
	check(damaged < hp and player.health.current == damaged, "Rat damage commits once at frame3")
	player.damage_flash = 0.0
	await action_capture("rat_attack", first.position + Vector3(1.5,0,2.4), first.position + Vector3.UP*0.35)
	first.mobile.set_state("attack")
	level.loot_window.open_inventory()
	check(first.melee.phase == "idle" and first.mobile.state != "attack" and player.modal_open, "Shared modal cancels rat pending strike")
	level.loot_window.close()
	first.receive_damage(1)
	check(first.mobile.state == "hurt", "Rat hurt interrupts combat")
	await action_capture("rat_hurt", first.position + Vector3(1.5,0,2.4), first.position + Vector3.UP*0.35)
	first.receive_damage(999)
	check(first.mobile.state == "corpse" and first.collision_layer == 0 and not first.loot_available(), "Rat death leaves native nonblocking corpse without loot")
	await action_capture("rat_corpse", first.position + Vector3(1.5,0,2.4), first.position + Vector3.UP*0.15)
	player.set_physics_process(true)
	player.controls_active = true
	var onward := [[1080,0,640],[720,-256,640],[640,-256,640],[640,-256,512],[704,-256,448],[768,-256,384],[1792,-256,384],[1920,-256,384],[1920,-256,512],[1920,-256,1664],[1792,-256,1664],[1710,-256,1624],[1662,-256,1544],"s0000999_r19796",[1646,-256,1496],[1598,-256,1480],[1485,-256,1400]]
	for point in onward:
		if point is String:
			await open_door(point)
		elif not await walk(point):
			break
	check(player.position.distance_to(second.position) < 2.0, "Second rat encounter is continuously reachable through original stairs/corridor")
	await action_capture("rat_second", player.position, second.position + Vector3.UP*0.35)
	place_actor(player.spawn)
	player.set_physics_process(true)
	player.controls_active = false
	await frames(60)
	level.persistence.slot_path = RAT_SLOT
	print("RAT_SAVE_REFUSAL ",level.persistence.refusal())
	check(level.persistence.save_slot(), "Fixed-rat state saves to isolated slot")
	var saved: Dictionary = level.persistence.read_slot()
	var invalid: Dictionary = saved.duplicate(true)
	invalid.enemies.s0000999_r32958.health = 10
	check(not level.persistence.validate(invalid), "Rat saved health cannot exceed source-backed configured maximum")
	invalid = saved.duplicate(true)
	invalid.enemies["hall_combat_target"] = invalid.enemies.s0000999_r32958
	invalid.enemies.erase("s0000999_r32958")
	check(not level.persistence.validate(invalid), "Retired bear identity cannot replace a selected source rat on load")
	check(await level.persistence.load_slot(), "Fixed-rat state restores through fresh candidate")
	level = current_scene
	player = level.player
	check(level.world_root.get_node("s0000999_r32850").mobile.state == "corpse" and level.world_root.get_node("s0000999_r32958").health.current == 9 and player.inventory.items.size() == 13, "Load retains dead/live source identities and player test equipment")
	print("RAT_CHECKS ",results.size()-failures.size(),"/",results.size())
	FileAccess.open("res://tests/output/rat_results.txt",FileAccess.WRITE).store_string("\n".join(results))

func place_actor(at: Vector3) -> void:
	player.position = at
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.climbing.reset()
	player.falling.reset()
	player.stair_supported = false
	player.step_camera_offset = 0.0

func action_capture(label: String, at: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var previous := player.position
	var previous_yaw := player.rotation.y
	var previous_pitch: float = player.camera.rotation.x
	var profile: String = level.presentation.profile
	place_actor(at)
	player.look_at(Vector3(target.x, at.y, target.z))
	player.camera.look_at(target)
	player.set_physics_process(false)
	for mode in ["dfu_reference","widescreen"]:
		level.presentation.set_profile(mode)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/output/" + label + "_" + mode + ".png")
	level.presentation.set_profile(profile)
	place_actor(previous)
	player.rotation.y = previous_yaw
	player.camera.rotation.x = previous_pitch
	player.set_physics_process(true)
	await frames(3)

func action_checks() -> void:
	var previous_count := results.size()
	var previous_failures := failures.size()
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	var controller: Node = level.actions
	var action_sounds: Array[int] = []
	level.combat_audio.played.connect(func(event: String, ordinal: int, _spatial: bool):
		if event == "action":
			action_sounds.append(ordinal))
	var lectern := "s0000999_r27790"
	var lever := "s0000999_r32273"
	var book: Node3D = level.model_nodes.s0000999_r27861
	var platform: Node3D = level.model_nodes.s0000999_r32083
	var throne: Node3D = level.model_nodes.s0000999_r32131
	var book_start := book.transform
	var platform_start := platform.position
	var throne_start := throne.position
	check(controller.groups.size() == 2 and controller.entries.size() == 5, "Only five checked model actions form two source-linked mechanisms")
	var changed: Dictionary = level.classic.section.definition.duplicate(true)
	for entry in changed.models:
		if entry.has("expected_action"):
			entry.expected_action.magnitude += 1
			break
	var temporary := FileAccess.open("res://tests/output/action_source_case.json",FileAccess.WRITE)
	temporary.store_string(JSON.stringify(changed))
	temporary.close()
	var checked := preload("res://scripts/classic_data.gd").new()
	check(not checked.load_slice("res://tests/output/action_source_case.json") and "Source action mismatch" in checked.error, "Source action parameters are checked against original bytes before scene construction")
	place_actor(level.classic.to_world([736,-1280,1740]))
	await frames(12)
	var target: Node3D = level.model_nodes[lectern]
	var mesh: MeshInstance3D = target.get_child(0)
	# The lectern's AABB centre is empty space beneath its slanted reading top.
	var faces := mesh.mesh.get_faces()
	for index in range(0, faces.size(), 3):
		var point := (faces[index] + faces[index+1] + faces[index+2]) / 3.0
		player.camera.look_at(target.transform * point)
		await frames(2)
		if player.interact_target == target:
			break
	check(player.interact_target == target, "Original lectern is acquired by the existing obstructed E interaction ray")
	if player.interact_target == target:
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = true
		Input.parse_input_event(event)
		await frames(2)
		Input.action_release("interact")
	else:
		target.interact()
	await frames(120)
	check(controller.groups[lectern].raised and not controller.moving() and book.basis.is_equal_approx(book_start.basis * Basis(Vector3.UP, -472.0 * TAU / 2048.0)), "Lectern rotates the source bookcase by83degrees around its original pivot")
	for point in [[500,-1280,1922],[400,-1280,1922],[330,-1280,1922],[320,-1280,1960],[320,-1280,2000]]:
		if not await walk(point):
			break
	for point in [[320,-1280,1960],[330,-1280,1922],[400,-1280,1922],[500,-1280,1922],[736,-1280,1740]]:
		if not await walk(point):
			break
	await action_capture("bookcase_open", level.classic.to_world([640,-1280,1850]), level.classic.to_world([340,-1320,1980]))
	# Closing through the player must pause without changing collision ownership.
	var book_mesh: MeshInstance3D = book.get_child(0)
	var centre := book.transform * book_mesh.mesh.get_aabb().get_center()
	place_actor(Vector3(centre.x,32.001,centre.z))
	controller.activate(lectern)
	await frames(5)
	check(controller.groups[lectern].busy and controller.groups[lectern].blocked, "Bookcase pauses when its next pose overlaps the full player capsule")
	place_actor(level.classic.to_world([736,-1280,1740]))
	await frames(120)
	check(not controller.moving() and book.transform.is_equal_approx(book_start), "Clearing the bookcase lets it return exactly to its source pose")
	await action_capture("bookcase_closed",level.classic.to_world([640,-1280,1850]),level.classic.to_world([340,-1320,1980]))
	place_actor(level.classic.to_world([1695,-1024,1096]))
	await frames(12)
	target = level.model_nodes[lever]
	mesh = target.get_child(0)
	player.camera.look_at(target.transform * mesh.mesh.get_aabb().get_center())
	await frames(2)
	check(player.interact_target == target, "Original hall lever is acquired by E interaction ray")
	# Isolated ride setup; subsequent displacement must be produced by the lift.
	place_actor(platform_start + Vector3(-0.9,0.401,0.8))
	await frames(15)
	var ride_start := player.position
	# A temporary ceiling exercises the real capsule headroom guard on a rider.
	var ceiling := StaticBody3D.new()
	var ceiling_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5,0.2,1.5)
	ceiling_shape.shape = box
	ceiling.add_child(ceiling_shape)
	ceiling.position = ride_start + Vector3.UP * 2.15
	level.world_root.add_child(ceiling)
	await frames(2)
	controller.activate(lever)
	controller.activate(lever)
	await frames(45)
	check(controller.groups[lever].busy and controller.groups[lever].forward and controller.groups[lever].blocked and player.health.current == 300, "Repeated E cannot reverse a moving lift; rider headroom stops the whole chain safely")
	ceiling.queue_free()
	await frames(2)
	await frames(90)
	check(level.combat_audio.archive.ordinal_for_id(70) == 326 and level.combat_audio.archive.ordinal_for_id(72) == 328 and level.combat_audio.archive.ordinal_for_id(42) == 40 and action_sounds == [326,326,328,40], "Source sound IDs resolve and play once per accepted toggle, with no repeat on busy E")
	var elapsed: float = controller.groups[lever].elapsed
	var pose_before := platform.position
	level.character_sheet.open()
	await frames(20)
	check(platform.position.is_equal_approx(pose_before) and is_equal_approx(controller.groups[lever].elapsed,elapsed), "Shared modal pauses mechanism progress")
	level.character_sheet.close()
	player.controls_active = false
	await frames(12)
	check(platform.position.is_equal_approx(pose_before), "Released controls pause mechanisms")
	player.controls_active = true
	check("mechanism" in level.persistence.refusal(), "K refuses saving while any linked mechanism is moving")
	check("mechanism" in level.rest_window.rest.refusal(), "Rest refuses an unsettled mechanism")
	await frames(300)
	check(not controller.moving() and platform.position.distance_to(platform_start + Vector3.UP*5.6) < 0.001 and throne.position.distance_to(throne_start + Vector3.UP*5.6) < 0.001, "Platform and throne rise5.6metres together over source timing")
	print("RIDE_UP ", ride_start, " -> ", player.position)
	check(absf(player.position.y - ride_start.y - 5.6) < 0.06 and player.is_grounded(), "Full player capsule rides the original platform upward without motor retuning")
	await action_capture("throne_raised",level.classic.to_world([1450,-1024,1000]),throne.position + Vector3.UP*0.6)
	var raised_player := player.position
	controller.activate(lever)
	await frames(340)
	check(platform.position.distance_to(platform_start) < 0.001 and throne.position.distance_to(throne_start) < 0.001, "Second lever toggle lowers both objects to exact source positions")
	print("RIDE_DOWN ", raised_player, " -> ", player.position)
	check(player.position.distance_to(ride_start) < 0.08 and player.health.current == 300, "Player rides downward without separation or fall damage")
	await action_capture("throne_lowered",level.classic.to_world([1450,-1024,1000]),throne.position + Vector3.UP*0.6)
	# Persist raised states, restoring collision before candidate placement checks.
	controller.activate(lever)
	await frames(340)
	place_actor(level.classic.to_world([736,-1280,1740]))
	controller.activate(lectern)
	await frames(120)
	place_actor(platform_start + Vector3(-0.9,6.001,0.8))
	await frames(15)
	level.persistence.slot_path = ACTION_SLOT
	check(level.persistence.save_slot(), "Settled mechanism states save in an isolated slot")
	var data: Dictionary = level.persistence.snapshot()
	data.actions[lever] = "raised"
	check(not level.persistence.validate(data), "Save validation rejects malformed mechanism state")
	data = level.persistence.snapshot()
	data.actions.erase(lectern)
	check(not level.persistence.validate(data), "Save validation requires all selected mechanism IDs")
	check(await level.persistence.load_slot(), "Fresh candidate restores both mechanism states before player clearance")
	level = current_scene
	player = level.player
	await frames(12)
	check(level.actions.snapshot() == {lectern:true,lever:true}, "Load preserves raised throne and open bookcase without replaying motion")
	check(player.is_grounded() and absf(player.position.y-platform_start.y-6.0)<0.03, "Candidate restores elevated platform support before validating the saved rider")
	var file := FileAccess.open("res://tests/output/actions_results.txt",FileAccess.WRITE)
	file.store_string("\n".join(results))
	print("ACTION_CHECKS ",results.size()-previous_count-failures.size()+previous_failures,"/",results.size()-previous_count)

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
	check(level.enemies.size() == 17 and player.inventory.items.size() == 13 and player.health.maximum == 300, "Original fixed population/13items/300HP baseline retained")
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
	DirAccess.make_dir_recursive_absolute("res://tests/output")
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
	if "--rats-only" in OS.get_cmdline_user_args():
		await rat_checks()
		quit(0 if failures.is_empty() else 1)
		return
	if "--rats-read" in OS.get_cmdline_user_args():
		level.persistence.slot_path = RAT_SLOT
		check(await level.persistence.load_slot(), "Fresh process restores isolated rat slot")
		level = current_scene
		check(level.enemies.size() == 17 and level.world_root.get_node("s0000999_r32850").mobile.state == "corpse" and level.world_root.get_node("s0000999_r32958").health.current == 9, "Fresh process preserves dead/live rats without respawn or reroll")
		var delta: Vector3 = level.player.position - level.classic.provenance.start
		check(Vector2(delta.x,delta.z).length() < 0.15 and level.player.inventory.items.size() == 13, "Fresh process preserves cave start and owned items")
		quit(0 if failures.is_empty() else 1)
		return
	for enemy in level.enemies:
		enemy.melee.enabled = false
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
		enemy.collision_mask = 0
	if "--actions-only" in OS.get_cmdline_user_args():
		await action_checks()
		quit(0 if failures.is_empty() else 1)
		return
	if "--actions-read" in OS.get_cmdline_user_args():
		level.persistence.slot_path = ACTION_SLOT
		check(await level.persistence.load_slot(), "Separate process restores the isolated mechanism slot")
		level = current_scene
		player = level.player
		await frames(12)
		check(level.actions.snapshot() == {"s0000999_r27790":true,"s0000999_r32273":true} and player.is_grounded() and absf(player.position.y-32.1)<0.03, "Separate process restores both endpoints and elevated rider support")
		check(level.combat_audio.voices.all(func(voice: Node): return not voice.get_meta("action_voice",false)), "Restoring a mechanism does not replay its activation sound")
		print("ACTION_RELOAD ",results.size()-failures.size(),"/",results.size())
		quit(0 if failures.is_empty() else 1)
		return
	if "--full-dungeon-read" in OS.get_cmdline_user_args():
		var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dungeon_floor_audit.json"))
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SLOT))
		deep_destination = vector(saved.player.position)
		check(deep_destination.distance_to(vector(routes.routes["B0000003.RDB"][-1])) < 0.2, "Separate-process slot records the physically reached border-room endpoint")
		await restore_deep()
		print("FULL_DUNGEON_RELOAD ", results.size() - failures.size(), "/", results.size())
		quit(0 if failures.is_empty() else 1)
		return
	# These retained border/gallery routes are seeded in the hall. Cave-to-hall
	# traversal is covered by full_original_route and the source-rat checks.
	place_actor(level.classic.to_world([800,-512,1024]) + Vector3.UP*0.1)
	await frames(15)
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
		await action_checks()
	var file := FileAccess.open("res://tests/output/full_dungeon_results.txt", FileAccess.WRITE)
	file.store_string("\n".join(results))
	print("FULL_DUNGEON_CHECKS ", results.size() - failures.size(), "/", results.size())
	quit(0 if failures.is_empty() else 1)

