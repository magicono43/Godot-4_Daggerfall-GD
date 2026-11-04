extends "res://tests/magic.gd"
const Shield = preload("res://scripts/shield_effect.gd")
const SHIELD_PATH := "res://tests/shield_slot.json"
var damage_sounds: Array[String] = []

func finish_shield() -> void:
	print("SHIELD RESULTS: %d/%d" % [results.size()-failures.size(),results.size()])
	var report := "res://tests/shield_cross_process_results.txt" if "--shield-read" in OS.get_cmdline_user_args() else "res://tests/shield_results.txt"
	FileAccess.open(report,FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	level = load("res://tests/bear_regression.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	bind_magic()
	level.persistence.slot_path = SHIELD_PATH
	if "--shield-read" in OS.get_cmdline_user_args():
		check(await level.persistence.load_slot(), "Separate process loads depleted timed Shield")
		bind_magic()
		player.set_physics_process(false)
		level.persistence.slot_path = SHIELD_PATH
		var data: Dictionary = level.persistence.read_slot()
		var shield: RefCounted = player.spell_effects.shield
		check(shield.capacity == 5 and shield.current == 2 and is_equal_approx(shield.remaining + player.fatigue.game_seconds, float(data.player.shield.seconds) + float(data.player.fatigue.game_seconds)), "Cross-process load preserves original capacity, depleted pool and exact expiry clock")
		check(player.character.stat("alteration") == 65 and player.magic.known.has("shield") and not player.casting.active(), "Cross-process Shield knowledge/Alteration restore without replaying cast")
		finish_shield()
		return
	player.set_physics_process(false)
	var shield: RefCounted = player.spell_effects.shield
	level.combat_audio.played.connect(func(event,_id,_spatial):damage_sounds.append(event))
	check(player.inventory.items.size() == 13 and player.health.maximum == 300 and player.magic.maximum() == 150 and hall.health.current == 30, "Shield preserves accepted equipment/health/magicka/bear baseline")
	check(player.magic.known.size() == 7 and player.magic.known.has("shield") and player.character.stat("alteration") == 50, "Authored Shield grant and shared Alteration50 available")
	check(Catalog.cost("shield",player.character) == 68, "Shield combines source magnitude80 and duration28 costs with Alteration50")
	player.character.set_live({"alteration":100})
	check(Catalog.cost("shield",player.character) == 11 and player.reload_movement() and player.character.stat("alteration") == 100, "Live Alteration affects real cost and survives atomic F3")
	player.character.set_live({})
	player.controls_active = true
	player.magic.select("shield")
	await routed(KEY_Q)
	check(shield.current == 5 and shield.capacity == 5 and shield.remaining == 120 and player.magic.current == 82, "Routed self Shield commits immediately at full health and spends68")
	check(damage_sounds == ["cast_magic"] and player.casting.element == "magic", "Shield uses accepted magic hands and correct casting cue")
	player.casting.cancel()
	player.damage_flash = 0
	damage_sounds.clear()
	check(player.receive_damage(3) and player.health.current == 300 and shield.current == 2, "Shield absorbs partial incoming damage before health")
	check(player.damage_flash == 0 and damage_sounds.is_empty(), "Fully absorbed hit causes no HP injury flash or pain cue")
	shield.advance(20)
	await routed(KEY_F)
	check(player.magic.current == 14 and shield.current == 5 and shield.capacity == 5 and shield.remaining == 220, "Recast adds duration and tops up depleted pool only to initial capacity")
	player.casting.cancel()
	check(not player.casting.request(player) and shield.current == 5 and shield.remaining == 220, "Unaffordable recast cannot refresh Shield for free")
	var before: Dictionary = shield.snapshot()
	check(not player.receive_damage(0) and not player.receive_damage(-2) and shield.snapshot() == before, "Zero/negative damage cannot consume or replenish Shield")
	check(player.receive_damage(5) and not shield.active() and shield.capacity == 0 and shield.remaining == 0 and player.health.current == 300, "Exact depletion ends effect immediately without HP overflow")
	shield.cast(5,120)
	damage_sounds.clear()
	check(player.receive_damage(8) and player.health.current == 297 and not shield.active(), "Oversized hit consumes remaining5 and sends only3 to health")
	check(damage_sounds == ["player_hit"] and player.damage_flash > 0, "Overflow uses normal HP damage feedback once")
	shield.cast(5,120)
	shield.advance(119.5)
	check(shield.active() and shield.current == 5, "Unused pool remains until duration actually expires")
	shield.advance(0.5)
	check(not shield.active() and shield.current == 0 and shield.capacity == 0, "Duration expiry discards unused absorption pool")
	player.receive_damage(2)
	check(player.health.current == 295, "Damage after expiry passes directly to health")
	shield.cast(5,120)
	shield.absorb(4)
	shield.cast(2,60)
	check(shield.current == 3 and shield.capacity == 5 and shield.remaining == 180, "Smaller recast adds its magnitude but retains original capacity")
	shield.cast(20,60)
	check(shield.current == 5 and shield.capacity == 5 and shield.remaining == 240, "Larger recast cannot raise incumbent starting capacity")
	shield.clear()
	shield.cast(8,60)
	check(shield.capacity == 8 and shield.current == 8, "After effect ends a new cast establishes a fresh capacity")
	shield.clear()
	shield.cast(5,120)
	player.controls_active = false
	player.tick_fatigue(10,"normal")
	check(shield.remaining == 120, "Released controls pause Shield on shared elapsed game clock")
	player.controls_active = true
	level.character_sheet.open()
	player.tick_fatigue(10,"normal")
	check(shield.remaining == 120 and level.character_sheet.details.text.contains("Shield: 5 / 5"), "Character modal shows real Shield and pauses duration")
	await capture("shield_character_4_3")
	level.presentation.set_profile("widescreen")
	await frames(2)
	await capture("shield_character_widescreen")
	level.character_sheet.close()
	player.tick_fatigue(1,"normal")
	check(is_equal_approx(shield.remaining,108), "Shield consumes the same12x awake clock as Light")
	player.spell_effects.apply("light",player)
	player.spell_effects.advance(108)
	check(not shield.active() and player.spell_effects.remaining == 492 and player.spell_effects.light.visible, "Shield expiry is independent of remaining Light state")
	shield.cast(5,120)
	player.health.current = 300
	player.damage_flash = 0
	damage_sounds.clear()
	player.land({"kind":"damage","damage":3,"distance":5.6})
	check(player.health.current == 300 and shield.current == 2 and damage_sounds == ["fall_damage"], "Shield absorbs fall damage while preserving exactly one landing cue")
	check(player.fall_feedback.contains("0 fall damage") and player.fall_feedback.contains("3 shielded"), "Fall feedback distinguishes shielded amount from actual HP damage")
	player.land({"kind":"damage","damage":7,"distance":6.4})
	check(player.health.current == 295 and not shield.active(), "Fall overflow passes remaining damage through health")
	# Real bear strike routes its already-resolved damage through Shield.
	player.health.current = 300
	shield.cast(100,120)
	player.position = hall.position + Vector3(0,0,1.5)
	player.camera.look_at(hall.global_position + Vector3.UP*0.4)
	hall.look_at(player.global_position)
	hall.melee.enabled = true
	hall.melee.cancel()
	hall.melee.tick(hall,0.01)
	await frames(30)
	check(player.health.current == 300 and shield.current < 100, "Actual bear strike consumes shield through shared player damage entry")
	hall.melee.enabled = false
	hall.melee.cancel()
	# Safely return to authored hall support before save/rest.
	player.position = player.spawn
	player.velocity = Vector3.ZERO
	player.flight_horizontal = Vector3.ZERO
	player.falling.reset()
	player.set_physics_process(true)
	await frames(5)
	player.set_physics_process(false)
	hall.health.apply_damage(1000)
	shield.clear()
	shield.cast(5,120)
	player.health.current = 280
	level.rest_window.open()
	check(level.rest_window.rest.start(1), "Safe rest starts with Shield active")
	level.rest_window.rest.tick(0.75)
	check(not shield.active(), "Completed rest hour expires Shield using existing clock policy")
	level.rest_window.close()
	player.magic.current = 150
	player.magic.select("shield")
	await routed(KEY_B)
	await double_click_spell(5)
	check(shield.current == 5 and player.magic.current == 82 and not player.modal_open, "Spellbook double-click casts Shield immediately and closes")
	player.casting.cancel()
	player.receive_damage(3)
	var base: Dictionary = player.character.base.duplicate()
	base.alteration = 65
	player.character.set_base(base)
	var data: Dictionary = level.persistence.snapshot()
	check(data.version == 9 and data.player.shield.current == 2 and level.persistence.validate(data), "Schema8 records partially depleted Shield and remaining time")
	for kind in ["missing","negative","fraction","overflow","infinite","expired","empty","extra","old"]:
		var bad := data.duplicate(true)
		match kind:
			"missing":bad.player.erase("shield")
			"negative":bad.player.shield.current = -1
			"fraction":bad.player.shield.capacity = 3.5
			"overflow":bad.player.shield.current = bad.player.shield.capacity+1
			"infinite":bad.player.shield.seconds = INF
			"expired":bad.player.shield.seconds = 0
			"empty":bad.player.shield.current = 0
			"extra":bad.player.shield.foo = 1
			"old":bad.version = 7
		check(not level.persistence.validate(bad), "Malformed Shield save rejects before swap: "+kind)
	check(level.persistence.write_slot(data), "Shield saves to isolated slot without overwriting manual")
	player.character.set_live({"alteration":100})
	await routed(KEY_C)
	await routed(KEY_L)
	bind_magic()
	player.set_physics_process(false)
	level.persistence.slot_path = SHIELD_PATH
	shield = player.spell_effects.shield
	check(shield.current == 2 and shield.capacity == 5 and shield.remaining > 118 and player.character.stat("alteration") == 65 and player.character.live.is_empty(), "L restores depleted Shield without refilling; clears live override")
	check(player.controls_active and not player.modal_open and not player.casting.active(), "Load from sheet resumes capture without replaying Shield cast")
	player.health.current = 1
	player.receive_damage(100)
	check(player.is_dead() and not shield.active() and player.spell_effects.remaining == 0, "Fatal overflow clears Shield/Light through existing death ownership")
	check(not player.receive_damage(1) and shield.current == 0, "Dead actor cannot consume effects or revive")
	await routed(KEY_L)
	bind_magic()
	check(not player.is_dead() and player.spell_effects.shield.current == 2, "L after death restores persisted Shield")
	await routed(KEY_R)
	bind_magic()
	check(not player.spell_effects.shield.active() and player.magic.known.has("shield") and player.magic.current == 150, "R restores authored Shield knowledge without active buff")
	player.set_physics_process(false)
	player.magic.select("shield")
	player.casting.request(player)
	player.casting.cancel()
	await frames(2)
	check(level.player_status.text.contains("Shield: 5 / 5"), "HUD shows current pool/capacity and duration")
	await capture("shield_hud_4_3")
	finish_shield()


