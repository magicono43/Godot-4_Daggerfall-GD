extends "res://tests/magic.gd"
var system: Node3D
var cast_events_off: Array[String] = []
var event_ids: Array[int] = []

func check_frame(texture: Texture2D, expected: Dictionary, label: String) -> void:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(texture.get_image().get_data())
	check(texture.get_size() == Vector2(expected.pixels[0],expected.pixels[1]) and context.finish().hex_encode() == expected.rgba_sha256, label)

func aim_fixture(distance := 8.0) -> void:
	hall.health.current = 30
	player.position = Vector3(200,60,distance)
	player.camera.look_at(hall.global_position + Vector3.UP * 0.4)
	player.casting.cancel()
	player.combat.cancel()
	player.magic.current = 150
	player.fatigue.current = player.fatigue.maximum()
	player.controls_active = true
	system.clear()
	cast_events_off.clear()
	event_ids.clear()

func fire(id: String) -> Node3D:
	player.magic.select(id)
	player.casting.request(player)
	player.casting.release(player)
	player.casting.tick(player,0.2)
	return system.effects[-1] if not system.effects.is_empty() else null

func finish_offensive() -> void:
	print("OFFENSIVE MAGIC RESULTS: %d/%d" % [results.size()-failures.size(),results.size()])
	FileAccess.open("res://tests/offensive_magic_results.txt",FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	bind_magic()
	player.set_physics_process(false)
	hall.set_physics_process(false)
	system = player.casting.projectiles
	system.set_physics_process(false)
	arena = level.world_root
	var normal_start: Vector3 = player.position
	var normal_target: Vector3 = hall.position
	var floor_fixture := box(Vector3(40,0.2,60),Vector3(200,59.9,0))
	hall.position = Vector3(200,60,0)
	level.combat_audio.played.connect(func(event,id,_spatial):
		cast_events_off.append(event)
		event_ids.append(id))
	check(player.magic.known.size() == 6 and player.character.stat("destruction") == 50, "Normal authored grants include two bolts/touch and explicit Destruction50")
	check(Catalog.cost("fire_bolt",player.character) == 45 and Catalog.cost("shock_bolt",player.character) == 45 and Catalog.cost("burning_touch",player.character) == 30, "Source damage costs include1.5 ranged multiplier and unchanged touch cost")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/offensive_frames.json"))
	for element_key in ["fire","shock"]:
		for frame in 6:
			check_frame(player.spell_payloads[element_key][frame].texture,fixture.hands[element_key][frame],"%s hands frame%d matches independent source audit" % [element_key,frame])
		for record in 2:
			var payload: Dictionary = system.payloads[element_key].projectile if record == 0 else system.payloads[element_key].impact
			var expected: Dictionary = fixture.sprites["%s:%d" % [element_key,record]]
			check(payload.size_metres.is_equal_approx(Vector2(expected.metres[0],expected.metres[1])),"%s record%d preserves native sprite size" % [element_key,record])
			for frame in payload.frames.size():
				check_frame(payload.frames[frame],expected.frames[frame],"%s record%d frame%d RGBA matches source" % [element_key,record,frame])
	aim_fixture()
	player.magic.select("fire_bolt")
	await routed(KEY_Q)
	check(player.casting.ready_id == "fire_bolt" and not player.casting.active() and player.magic.current == 150 and player.magic.last_cast == "", "Q readies without charging/casting/history change")
	await frames(2)
	check(not player.combat.weapon.visible and not player.casting.view.visible and not player.combat.request_attack(player), "Readied state hides weapon and hands and prevents melee")
	check(cast_events_off.is_empty() and not system.busy(), "Readying emits no cast sound or projectile")
	await mouse_click(Vector2(640,400),MOUSE_BUTTON_RIGHT)
	check(player.combat.elapsed < 0 and player.magic.current == 150, "Routed RMB cannot melee while offensive spell is readied")
	await routed(KEY_Z)
	check(not player.combat.sheathed, "Readying prevents weapon sheath toggle")
	await routed(KEY_ESCAPE)
	check(player.casting.ready_id.is_empty() and player.magic.current == 150 and player.controls_active, "Esc cancels unspent readied spell while keeping controls captured")
	player.casting.request(player)
	level.spellbook.open()
	check(player.casting.ready_id.is_empty() and player.magic.current == 150, "Opening modal cancels readied spell without minting/refunding resource")
	level.spellbook.close()
	player.casting.request(player)
	check(not level.persistence.refusal().is_empty(), "K refuses readied spell")
	await mouse_click(Vector2(640,400))
	check(player.magic.current == 105 and player.casting.active() and player.casting.ready_id.is_empty(), "Root-routed LMB spends snapshotted cost and starts fire hands")
	check(cast_events_off == ["cast_fire"] and event_ids == [84], "Fire release uses ordinal84 (source ID352), not magic/thunder")
	check(player.casting.element == "fire" and system.effects.is_empty(), "Fire hands precede once-only release-frame missile event")
	player.casting.tick(player,0.19)
	check(system.effects.is_empty(), "No missile before source frame5 release")
	player.casting.tick(player,0.01)
	check(system.effects.size() == 1, "Exactly one projectile appears on release frame5")
	player.casting.tick(player,0.01)
	check(system.effects.size() == 1 and player.magic.current == 105, "Animation event cannot duplicate projectile or cost")
	var missile: Node3D = system.effects[0]
	var old: Vector3 = missile.global_position
	system.tick(0.1)
	check(is_equal_approx(missile.global_position.distance_to(old),2.5), "Projectile moves source25m/s without teleporting to target")
	var health_before: int = hall.health.current
	system.tick(0.3)
	check(missile.impacted and hall.health.current == health_before-10 and system.hits == 1, "Swept landed fire hit always applies10 damage without save/armor RNG")
	check(cast_events_off.count("impact_fire") == 1 and event_ids.back() == 89, "Fire impact emits its own original impact cue once")
	check(missile.glow.visible and missile.glow.light_color.is_equal_approx(system.COLORS.fire), "Impact has scoped fire-colored light")
	var impact_health: int = hall.health.current
	system.tick(0.01)
	check(hall.health.current == impact_health, "Impact animation never repeats damage")
	system.tick(10)
	check(not system.busy(), "Impact sprite and light retire together at animation end")
	hall.health.current = 30
	aim_fixture()
	missile = fire("shock_bolt")
	check(player.casting.element == "shock" and cast_events_off == ["cast_shock"] and event_ids == [83], "Shock selects separate hands and source ID351/ordinal83 cast sound")
	system.tick(0.5)
	check(missile.impacted and hall.health.current == 20 and cast_events_off.count("impact_shock") == 1 and event_ids.back() == 88, "Shock hits with distinct original impact sound and deterministic10 damage")
	check(missile.glow.light_color.is_equal_approx(system.COLORS.shock) and missile.sprite.texture == system.payloads.shock.impact.frames[0], "Shock impact art and colored light are element-specific")
	# Thin obstacles exercise continuous full-volume sweeps, not end-position overlap.
	hall.health.current = 30
	aim_fixture()
	var wall := box(Vector3(3,4,0.02),Vector3(200,62,4))
	await frames(2)
	missile = fire("fire_bolt")
	system.tick(0.8)
	check(missile.impacted and hall.health.current == 30 and missile.position.z > 3.5, "Large-tick sweep stops at thin wall rather than tunnelling to enemy")
	check(cast_events_off.count("impact_fire") == 1, "Wall contact plays elemental impact instead of melee/terrain sound")
	system.clear()
	wall.queue_free()
	await frames(2)
	aim_fixture()
	missile = fire("fire_bolt")
	missile.direction = Vector3.UP
	system.tick(4.0)
	check(not system.busy() and cast_events_off.count("impact_fire") == 0, "Missed projectile retires at bounded100m range without an invented impact")
	# Touch no-target and obstruction refusal must retain readiness and resource.
	aim_fixture()
	player.magic.select("burning_touch")
	player.casting.request(player)
	check(not player.casting.release(player) and player.magic.current == 150 and player.casting.ready_id == "burning_touch" and cast_events_off.is_empty(), "Out-of-range touch remains ready without cost or sounds")
	aim_fixture(2)
	wall = box(Vector3(3,4,0.02),Vector3(200,62,1))
	await frames(2)
	player.magic.select("burning_touch")
	player.casting.request(player)
	check(not player.casting.release(player) and player.magic.current == 150, "Touch cannot hit enemy through nearby wall")
	wall.queue_free()
	await frames(2)
	player.casting.cancel()
	player.casting.request(player)
	check(player.casting.release(player) and player.magic.current == 120, "Touch releases on valid nearby enemy and spends30")
	player.casting.tick(player,0.2)
	check(hall.health.current == 20 and not system.busy() and cast_events_off.count("cast_fire") == 1 and cast_events_off.count("impact_fire") == 1, "Touch damages with cast plus impact sounds but no projectile/impact sprite/light")
	player.casting.tick(player,0.02)
	check(hall.health.current == 20 and cast_events_off.count("impact_fire") == 1, "Touch event is once-only")
	hall.health.current = 30
	aim_fixture(2)
	player.magic.select("burning_touch")
	player.casting.request(player)
	player.casting.release(player)
	hall.position.z = -10
	await frames(2)
	player.casting.tick(player,0.2)
	check(hall.health.current == 30 and cast_events_off.count("impact_fire") == 0, "Touch rechecks target at release frame; moved-away enemy is not hit")
	hall.position.z = 0
	aim_fixture()
	player.magic.select("shock_bolt")
	player.casting.request(player)
	player.character.set_live({"intelligence":0})
	check(not player.casting.release(player) and player.magic.current == 0, "Capacity loss while readied cannot release unaffordable spell")
	player.casting.cancel()
	check(player.magic.current == 0, "Cancelling after capacity change never mints magicka")
	player.character.set_live({})
	aim_fixture()
	player.controls_active = false
	level.spellbook.open()
	await frames(2)
	await double_click_spell(2)
	player.casting.tick(player,0.1)
	check(player.casting.ready_id == "fire_bolt" and not player.controls_active and player.magic.current == 150, "Book activation keeps targeted spell ready under previously released capture preference")
	await mouse_click(Vector2(640,400))
	check(player.controls_active and player.casting.ready_id == "fire_bolt" and player.magic.current == 150, "First recapture click does not accidentally release readied spell")
	await mouse_click(Vector2(640,400))
	check(player.casting.active() and player.magic.current == 105, "Next explicit click releases after recapture")
	player.casting.cancel()
	aim_fixture()
	missile = fire("fire_bolt")
	old = missile.global_position
	level.character_sheet.open()
	system.tick(1)
	check(missile.global_position == old and hall.health.current == 30, "Modal freezes in-flight missile and damage")
	level.character_sheet.close()
	player.controls_active = false
	system.tick(1)
	check(missile.global_position == old, "Released controls pause in-flight missile")
	player.controls_active = true
	player.casting.cancel()
	check(not level.persistence.refusal().is_empty(), "K refuses transient flying projectile")
	player.receive_damage(10000)
	check(not system.busy() and not player.casting.owns_weapon(), "Player death clears all missiles/impact lights and cast state")
	# Restore an alive isolated actor for source-art captures and persistence checks.
	player.health.current = player.health.maximum
	player.damage_flash = 0.0
	player.controls_active = true
	aim_fixture()
	missile = fire("shock_bolt")
	system.tick(0.2)
	var data: Dictionary = level.persistence.snapshot()
	check(data.version == 8 and level.persistence.validate(data) and data.player.character.destruction == 50, "Schema8 validates shared Destruction and five known IDs")
	var bad := data.duplicate(true)
	bad.version = 6
	check(not level.persistence.validate(bad), "Schema6 explicitly rejects before candidate swap")
	# Original hall captures, without introducing fixture geometry to gameplay.
	system.clear()
	player.casting.cancel()
	floor_fixture.queue_free()
	hall.position = normal_target
	player.position = normal_start
	player.camera.look_at(hall.global_position + Vector3.UP*0.4)
	player.magic.current = 150
	player.magic.select("fire_bolt")
	player.casting.request(player)
	await frames(2)
	check(level.player_status.get_global_rect().end.x <= level.presentation.hud.get_global_rect().end.x, "Readied HUD stays within calibrated display bounds")
	await capture("offensive_ready_4_3")
	player.casting.release(player)
	player.casting.tick(player,0.08)
	await frames(2)
	await capture("offensive_fire_hands")
	player.casting.tick(player,0.12)
	missile = system.effects[0]
	system.tick(0.05)
	await frames(2)
	await capture("offensive_fire_projectile")
	missile.impact(null,hall.position+Vector3.UP,Vector3.BACK)
	missile.tick(0.12)
	await frames(2)
	await capture("offensive_fire_impact")
	system.clear()
	player.casting.cancel()
	player.magic.current = 150
	missile = fire("shock_bolt")
	# fire() preserves current original hall aim; capture matching shock impact.
	missile.impact(null,hall.position+Vector3.UP,Vector3.BACK)
	missile.tick(0.12)
	level.presentation.set_profile("widescreen")
	await frames(2)
	await capture("offensive_shock_impact_widescreen")
	system.clear()
	player.casting.cancel()
	# Ready state is transient; source knowledge and last successful cast persist.
	level.persistence.slot_path = "res://tests/offensive_slot.json"
	var base: Dictionary = player.character.base.duplicate()
	base.destruction = 65
	player.character.set_base(base)
	data = level.persistence.snapshot()
	check(level.persistence.write_slot(data), "Isolated schema7 save preserves expanded magic state")
	player.magic.select("fire_bolt")
	player.casting.request(player)
	await routed(KEY_L)
	bind_magic()
	system = player.casting.projectiles
	check(not player.casting.owns_weapon() and not system.busy() and player.magic.known.size() == 6, "L discards readied/in-flight state while restoring owned spells")
	check(player.character.stat("destruction") == 65, "Load restores persisted shared Destruction rather than config baseline")
	await routed(KEY_B)
	await double_click_spell(2)
	check(player.casting.ready_id == "fire_bolt" and player.magic.current == data.player.magic.current, "Book double-click readies ranged spell without auto-firing or spending")
	player.set_physics_process(false)
	system.set_physics_process(false)
	player.casting.cancel()
	for i in 3:
		player.magic.current = 150
		player.casting.cancel()
		var killing_missile := fire("fire_bolt")
		killing_missile.impact(hall,hall.position+Vector3.UP,Vector3.BACK)
		killing_missile.impact(hall,hall.position+Vector3.UP,Vector3.BACK)
	check(hall.health.current == 0 and hall.collision_layer == 0 and hall.loot_available(), "Three once-only spell impacts kill original bear and retain nonblocking lootable corpse")
	await routed(KEY_R)
	bind_magic()
	check(not player.casting.owns_weapon() and not player.casting.projectiles.busy() and player.magic.current == 150, "R clears ready/projectile state and restores full authored magicka")
	finish_offensive()
