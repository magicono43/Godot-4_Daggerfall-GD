extends RefCounted
## Focused flight cases invoked by the existing enemy_navigation suite.
const SLOT := "res://tests/output/bat_save.json"
var tree: SceneTree
var level: Node3D
var actor: CharacterBody3D
var player: CharacterBody3D
var results: Array[String] = []
var failures: Array[String] = []

class HitRolls extends "res://scripts/combat_resolver.gd":
	var values: Array[int] = [8, 0, 99, 0, 10]
	func roll(maximum: int) -> int:
		assert(not values.is_empty())
		var value: int = values.pop_front()
		assert(value >= 0 and value < maximum)
		return value

func check(ok: bool, label: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + label)
	print(results.back())
	if not ok:
		failures.append(label)

func frames(count: int) -> void:
	for i in count:
		await tree.physics_frame

func box(size: Vector3, at: Vector3, door: bool = false) -> Node3D:
	var body: Node3D = preload("res://scripts/door.gd").new() if door else StaticBody3D.new()
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
	level.world_root.add_child(body)
	body.position = at
	return body

func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func reset(at: Vector3) -> void:
	actor.position = at
	actor.home = at
	actor.velocity = Vector3.ZERO
	actor.navigation.clear()
	actor.melee.cancel()
	actor.melee.enabled = false
	actor.mobile.set_state("idle")
	player.controls_active = true

func fly_to(at: Vector3, ticks: int) -> void:
	actor.navigation.observe(at)
	actor.navigation.memory_left = 120.0
	for i in ticks:
		actor.navigation.tick(actor, 1.0 / 60.0, false)
		actor.mobile.tick(1.0 / 60.0)
		await frames(1)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var previous := player.position
	var yaw := player.rotation.y
	var pitch: float = player.camera.rotation.x
	var profile: String = level.presentation.profile
	var processing: bool = player.is_physics_processing()
	var captured: bool = player.controls_active
	var actor_processing := {}
	for body in level.enemies:
		actor_processing[body] = body.is_physics_processing()
		body.set_physics_process(false)
	player.set_physics_process(false)
	player.controls_active = true
	var target := actor.position
	if actor.mobile.state == "corpse":
		target.y += actor.sprite_payload.corpse.size_metres.y * 0.5
	var camera_position := target + Vector3(2.5,0.6,4.0)
	var found := false
	var space := actor.get_world_3d().direct_space_state
	for distance in [4.0,2.5,1.5]:
		for direction in 8:
			var candidate := target + Vector3(cos(direction*PI/4)*distance,0.6,sin(direction*PI/4)*distance)
			var ray := PhysicsRayQueryParameters3D.create(candidate,target,1,[actor.get_rid(),player.get_rid()])
			ray.hit_back_faces = true
			if space.intersect_ray(ray).is_empty():
				camera_position = candidate
				found = true
				break
		if found:
			break
	check(found,"Capture has unobstructed source view: " + label)
	player.position = camera_position - Vector3.UP * (player.camera.global_position.y-player.global_position.y)
	player.look_at(Vector3(actor.position.x, player.position.y, actor.position.z))
	player.camera.look_at(target)
	for mode in ["dfu_reference", "widescreen"]:
		level.presentation.set_profile(mode)
		for i in 3:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("res://tests/output/bat_" + label + "_" + mode + ".png")
	player.position = previous
	player.rotation.y = yaw
	player.camera.rotation.x = pitch
	level.presentation.set_profile(profile)
	player.controls_active = captured
	player.set_physics_process(processing)
	for body in actor_processing:
		body.set_physics_process(actor_processing[body])

func assets() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/enemies/bat_frames.json"))
	var matching := true
	var count := 0
	for id in fixture:
		var record: Dictionary = actor.sprite_payload.corpse if id == "401:0" else actor.sprite_payload.records[int(id.split(":")[1])]
		var expected: Dictionary = fixture[id]
		matching = matching and record.frames.size() == int(expected.frames) and record.size_metres.distance_to(Vector2(expected.metres[0],expected.metres[1])) < 0.0001
		for i in record.frames.size():
			matching = matching and digest(record.frames[i].get_image().get_data()) == expected.rgba_sha256[i]
			count += 1
	check(matching and count == 46, "All46 bat live/corpse frames match independent native dimensions and RGBA")
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/enemies/bat_profile.json"))
	var attributes_match := true
	for key in profile.attributes:
		attributes_match = attributes_match and int(profile.attributes[key]) == level.classic.bat_attributes[key]
	check(attributes_match, "Original ENEMY003 career attributes match independent raw record")
	check(actor.health.maximum == 12 and actor.combat_stats.stat("hand_to_hand") == 45 and actor.combat_stats.stat("strength") == 50 and actor.combat_stats.stat("agility") == 70 and actor.combat_stats.stat("luck") == 50 and actor.combat_stats.base_armor == 30, "Bat has deterministic source-minimum12HP, level3 skills45 and native stats/armor")
	check(actor.combat_stats.attack_ranges == [Vector2i(2,12)] and not actor.combat_stats.skeleton and not actor.combat_stats.parry_sounds and not actor.can_open_doors and not actor.loot_enabled, "Bat uses one2..12 damage slot, no skeleton resistance/parry, door opening or loot")
	check(actor.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING and actor.floor_snap_length == 0.0 and actor.get_child(0).position.is_zero_approx() and is_equal_approx(actor.get_child(0).shape.height,2.1), "Flying actor uses native centre origin and2.1m capsule without floor snap")
	for direction in 8:
		actor.mobile.select_view(actor.position + actor.global_basis * Vector3(-sin(direction*PI/4),0,-cos(direction*PI/4))*5)
		check(actor.mobile.orientation == direction and actor.mobile.source_record == [0,1,2,3,4,3,2,1][direction] and actor.mobile.flip_h == (direction > 4), "Bat eight-way flight direction%d uses source bank/mirroring" % direction)
	actor.mobile.set_state("idle")
	actor.mobile.tick(0.1)
	var frame: int = actor.mobile.source_frame
	actor.mobile.set_state("move")
	check(frame == 1 and actor.mobile.source_frame == 1, "No-idle bat flaps at10fps and keeps frame across hover/move")
	actor.mobile.set_state("hurt")
	check(actor.mobile.source_record >= 10 and actor.mobile.source_record <= 14 and actor.mobile.position.y == 0.0, "Bat hurt sprite remains centred instead of moving its feet")

func audio_checks() -> void:
	var cues: Array = []
	level.combat_audio.played.connect(func(event: String, ordinal: int, spatial: bool): cues.append([event,ordinal,spatial]))
	for event in ["move", "bark", "attack"]:
		for i in 20:
			actor.play_sound("skeleton_" + event)
			if not cues.is_empty() and cues.back()[0] == "bat_" + event:
				break
		var ordinal: int = {"move":124,"bark":125,"attack":126}[event]
		check(not cues.is_empty() and cues.back() == ["bat_"+event,ordinal,true], "Bat " + event + " plays its own source ordinal spatially")
	var voice: Node3D = level.combat_audio.voices.back()
	check(voice.global_position.distance_to(actor.global_position) < 0.001 and voice.get_meta("creature_owner") == actor.get_instance_id(), "Bat audio is emitted at flight centre with creature ownership")
	level.combat_audio.stop_creature(actor)
	check(level.combat_audio.voices.all(func(node: Node): return node.get_meta("creature_owner",0) != actor.get_instance_id()), "Bat-owned voices stop independently of unrelated samples")
	if DisplayServer.get_name() != "headless":
		var bus_capture := AudioEffectCapture.new()
		AudioServer.add_bus_effect(0,bus_capture)
		level.combat_audio.play("bat_bark",actor,1.0,player.camera.global_position + Vector3(0,0,-5))
		await tree.process_frame
		OS.delay_msec(350)
		await tree.process_frame
		var peak := 0.0
		for sample in bus_capture.get_buffer(bus_capture.get_frames_available()):
			peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		check(peak > 0.001,"Original bat voice produces actual mixer output")
		AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)

func run(owner: SceneTree) -> bool:
	tree = owner
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	if "--bats-placements" in OS.get_cmdline_user_args():
		return await placements()
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sections/privateers_hold_opening.json"))
	definition.name = "Isolated flying bat validation"
	definition.fixed_enemies = [{"id":"s0000999_r33030","block":"S0000999.RDB","record_offset":33030,"expected_archive":199,"expected_record":16,"expected_mobile_id":3,"expected_flags":0,"expected_sound_index":2,"expected_action":0,"expected_next":0}]
	FileAccess.open("res://tests/output/bat_section.json",FileAccess.WRITE).store_string(JSON.stringify(definition))
	level = load("res://tests/bat_regression.tscn").instantiate()
	tree.root.add_child(level)
	tree.current_scene = level
	await frames(5)
	check(level.ready_to_play,"Bat fixture builds from checked source marker")
	if not level.ready_to_play:
		print(level.classic.error)
		return false
	player = level.player
	actor = level.enemies[0]
	actor.set_physics_process(false)
	player.controls_active = false
	level.persistence.slot_path = SLOT
	if "--bats-read" in OS.get_cmdline_user_args():
		check(await level.persistence.load_slot(),"Fresh process restores bat slot")
		level = tree.current_scene
		actor = level.enemies[0]
		check(actor.health.current == 0 and actor.mobile.state == "corpse" and actor.collision_layer == 0 and actor.mobile.source_record == 0,"Fresh process retains dead original bat without respawn or death sound")
		return finish()
	player.set_physics_process(false)
	var original: Vector3 = level.classic.fixed_enemies[0].position
	box(Vector3(40,1,40),Vector3(200,49.5,200))
	var light := OmniLight3D.new()
	light.position = Vector3(200,56,200)
	light.omni_range = 20
	light.light_energy = 2.0
	level.world_root.add_child(light)
	player.position = Vector3(220,50,220)
	reset(Vector3(200,54,200))
	assets()
	await capture("hover")
	await audio_checks()
	actor.mobile.set_state("idle")
	var before := actor.position
	for i in 120:
		actor.navigation.tick(actor,1.0/60.0,false)
		await frames(1)
	check(actor.position.distance_to(before) < 0.001,"Unalerted bat hovers without gravity or grounded support")
	await fly_to(Vector3(205,54,200),120)
	check(actor.position.x > 204.5 and absf(actor.position.y-54) < 0.02,"Flight crosses unsupported horizontal space at steady altitude")
	await fly_to(Vector3(205,59,200),120)
	check(actor.position.y > 58.5,"Flight ascends to an elevated remembered target")
	await capture("elevated")
	await fly_to(Vector3(205,50.9,200),240)
	check(actor.position.y >= 51.0 and actor.position.y < 51.5,"Flight descends while respecting capsule floor clearance")
	var ceiling := box(Vector3(20,0.2,20),Vector3(200,58,200))
	reset(Vector3(200,54,200))
	await frames(2)
	for i in 60:
		actor.navigation.move(actor,Vector3.UP*20,1.0/60.0)
		await frames(1)
	check(actor.position.y < 57.0,"Full flight capsule stops below a ceiling even under direct upward motion")
	ceiling.queue_free()
	var wall := box(Vector3(0.2,20,20),Vector3(205,56,200),true)
	reset(Vector3(200,54,200))
	await frames(2)
	for i in 60:
		actor.navigation.move(actor,Vector3.RIGHT*20,1.0/60.0)
		await frames(1)
	check(actor.position.x < 204.6 and not wall.opened,"Flight capsule cannot pass through or open a closed door")
	for i in 90:
		actor.navigation.move(actor,Vector3.DOWN*20,1.0/60.0)
		await frames(1)
	check(actor.position.y > 51.0,"Direct downward flight cannot penetrate the floor")
	wall.queue_free()
	# A low lintel interrupts the direct descent toward a target across the door.
	var lintel := box(Vector3(12,5,0.3),Vector3(200,54.9,200))
	var jamb := box(Vector3(5,2.4,0.3),Vector3(196.8,51.2,200))
	var other_jamb := box(Vector3(5,2.4,0.3),Vector3(203.2,51.2,200))
	var leaf := box(Vector3(1.4,2.4,0.12),Vector3(199.3,50,200),true)
	leaf.sync_to_physics = false
	for child in leaf.get_children():
		child.position = Vector3(0.7,1.2,0)
	# Match the production leaf's hinge-relative mesh bounds.
	var leaf_mesh: MeshInstance3D = leaf.get_child(1)
	var mesh_tool := SurfaceTool.new()
	mesh_tool.append_from(leaf_mesh.mesh, 0, leaf_mesh.transform)
	leaf_mesh.mesh = mesh_tool.commit()
	leaf_mesh.position = Vector3.ZERO
	leaf.move_child(leaf_mesh, 0)
	leaf.opened = true
	leaf.rotation.y = PI / 2
	actor.navigation.doors.append(leaf)
	reset(Vector3(200.35,53,203))
	await frames(2)
	await fly_to(Vector3(200,51.3,197),240)
	check(actor.position.z < 198.0,"Bat aligns with a low open doorway and flies through it")
	actor.navigation.doors.erase(leaf)
	for fixture in [leaf,lintel,jamb,other_jamb]:
		fixture.queue_free()
	var obstacle := box(Vector3(2,5,2),Vector3(200,54,200))
	reset(Vector3(200,54,205))
	await frames(2)
	await fly_to(Vector3(200,54,195),480)
	check(actor.position.distance_to(Vector3(200,54,195)) < 0.5,"Local3D steering detours around an isolated solid obstacle")
	actor.navigation.memory_left = 0.01
	for i in 30:
		actor.navigation.tick(actor,1.0/60.0,false)
		await frames(1)
	before = actor.position
	for i in 30:
		actor.navigation.tick(actor,1.0/60.0,false)
		await frames(1)
	check(actor.position.distance_to(before) < 0.001 and actor.navigation.state == "hovering","Lost-target memory expiry stops flight without ground gravity")
	obstacle.queue_free()
	reset(Vector3(200,54,200))
	player.position = Vector3(200,53.1,203)
	await frames(2)
	for i in 25:
		actor._physics_process(1.0/60.0)
		await frames(1)
	check(actor.position.z > 200.5 and actor.noticed,"Production sensing and flight approach a visible player")
	player.controls_active = false
	before = actor.position
	for i in 30:
		actor._physics_process(1.0/60.0)
		await frames(1)
	check(actor.position.distance_to(before) < 0.001 and actor.navigation.memory_left == 0,"Released controls stop flight without falling and clear pursuit")
	player.controls_active = true
	player.position = actor.position + Vector3(0,-0.9,1.2)
	await frames(2)
	actor.melee.enabled = true
	actor.melee.resolver = HitRolls.new()
	actor.mobile.set_state("idle")
	var hp: int = player.health.current
	actor.melee.tick(actor,0)
	actor.mobile.tick(0.199)
	actor.melee.tick(actor,0.199)
	check(actor.melee.phase == "windup" and player.health.current == hp,"Bat attack waits until original frame2/0.2s")
	actor.mobile.tick(0.001)
	actor.melee.tick(actor,0.001)
	check(player.health.current == hp-12 and actor.melee.phase == "recovery","Frame2 resolves native2..12 damage through real combat formulas")
	actor.mobile.tick(0.1)
	actor.melee.tick(actor,0.1)
	check(player.health.current == hp-12,"Bat strike cannot repeat in its attack tail")
	player.damage_flash = 0.0
	await capture("attack")
	player.position.y -= 4.0
	await frames(2)
	check(not actor.melee.can_reach(actor),"Flying melee rejects player on another elevation outside3D reach")
	player.position = actor.position + Vector3(0,-0.9,1.2)
	var blocker := box(Vector3(4,5,0.1),actor.position+Vector3(0,0,0.6))
	await frames(2)
	check(not actor.melee.can_reach(actor),"Flying melee refuses damage through an intervening wall")
	blocker.queue_free()
	actor.melee.cancel()
	actor.mobile.set_state("attack")
	level.loot_window.open_inventory()
	before = actor.position
	actor._physics_process(0.5)
	check(actor.melee.phase == "idle" and actor.mobile.state != "attack" and actor.position == before,"Shared modal cancels bat strike and freezes flight")
	level.loot_window.close()
	actor.receive_damage(1)
	check(actor.mobile.state == "hurt" and actor.melee.phase == "idle","Hurt interrupts bat attack without replacing its attributes")
	await capture("hurt")
	actor.mobile.tick(0.3)
	actor.position = original
	actor.navigation.clear()
	player.position = player.spawn
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	player.controls_active = false
	await frames(60)
	check(level.persistence.save_slot(),"Live airborne bat can be saved with player safely grounded")
	check(await level.persistence.load_slot(),"Live bat restores through fresh validated candidate")
	level = tree.current_scene
	actor = level.enemies[0]
	player = level.player
	actor.set_physics_process(false)
	check(actor.position.distance_to(original) < 0.001 and actor.health.current == 11 and actor.flying and actor.velocity.is_zero_approx(),"Load preserves flight altitude and hurt health without drift/reroll")
	actor.receive_damage(999)
	check(actor.mobile.state == "corpse" and actor.mobile.source_record == 0 and actor.collision_layer == 0 and not actor.loot_available() and actor.position.y < original.y,"Airborne death grounds native401:0 corpse without collision or loot")
	# Inspect the corpse in an unobstructed test area; retain the actual source
	# ground position for persistence. A camera offset in a small dungeon room
	# can otherwise end up behind its wall.
	var source_ground := actor.position
	var corpse_floor := box(Vector3(20,1,20),Vector3(200,49.5,200))
	actor.position = Vector3(200,50,200)
	var corpse_light := OmniLight3D.new()
	corpse_light.position = Vector3(200,54,200)
	corpse_light.omni_range = 15
	corpse_light.light_energy = 2
	level.world_root.add_child(corpse_light)
	await capture("corpse")
	actor.position = source_ground
	corpse_floor.queue_free()
	corpse_light.queue_free()
	await frames(30)
	print("BAT_SAVE_REFUSAL ", level.persistence.refusal())
	check(level.persistence.save_slot(),"Grounded bat corpse saves without combat transients")
	check(await level.persistence.load_slot(),"Dead bat restores silently without respawn")
	level = tree.current_scene
	check(level.enemies[0].health.current == 0 and level.enemies[0].mobile.state == "corpse","Reload retains dead bat identity")
	return finish()

func placements() -> bool:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	tree.root.add_child(level)
	tree.current_scene = level
	await frames(5)
	check(level.ready_to_play,"Normal dungeon with six bats loads")
	if not level.ready_to_play:
		return false
	player = level.player
	player.controls_active = false
	player.set_physics_process(false)
	var bats: Array = level.enemies.filter(func(body: Node): return body.creature_name == "Bat")
	check(bats.size() == 6 and level.enemies.size() == 17,"Normal population is six fixed bats, eight accepted rats and three skeletons")
	for bat in bats:
		actor = bat
		actor.set_physics_process(false)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = actor.get_child(0).shape
		query.transform = actor.global_transform
		query.collision_mask = 1
		query.exclude = [actor.get_rid(),player.get_rid()]
		check(actor.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Original bat marker has full capsule clearance: " + String(actor.name))
		var entry: Dictionary = level.classic.fixed_enemies.filter(func(v: Dictionary): return v.id == actor.name)[0]
		var recovery: Vector3 = actor.position-entry.position
		print("BAT_MARKER_RECOVERY ",actor.name," ",recovery)
		check(Vector2(recovery.x,recovery.z).length() < 0.001 and recovery.y >= -0.001 and recovery.y < 0.05,"Bat retains native X/Z with only bounded vertical capsule contact recovery: " + String(actor.name))
		if actor.name in ["s0000999_r33030","s0000999_r33498"]:
			await capture(String(actor.name))
	return finish()

func finish() -> bool:
	print("BAT_CHECKS ",results.size()-failures.size(),"/",results.size())
	FileAccess.open("res://tests/output/bat_results.txt",FileAccess.WRITE).store_string("\n".join(results))
	return failures.is_empty()
