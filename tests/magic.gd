extends "res://tests/character_sheet.gd"
const Catalog = preload("res://scripts/spell_catalog.gd")
const PATH := "res://tests/magic_slot.json"
var cast_events: Array[int] = []

func double_click_spell(index: int) -> void:
	var book: Control = level.spellbook
	var at: Vector2 = book.list.global_position + book.list.get_item_rect(index).get_center()
	# The first click is a normal selection; the second press carries the native double-click flag.
	await mouse_click(at)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.double_click = pressed
		root.push_input(event, true)
		await process_frame

func book_audio_checks() -> void:
	level.spellbook.close()
	player.set_physics_process(false)
	player.controls_active = true
	player.casting.cancel()
	player.combat.cancel()
	player.magic.current = 150
	player.spell_effects.clear()
	var audio: Node = level.combat_audio
	audio.played.connect(func(event, id, _spatial):
		if event == "cast_magic": cast_events.append(id))
	var source := preload("res://scripts/classic_archive.gd").new()
	source.open(level.classic.arena_path.path_join("DAGGER.SND"))
	check(source.record("349") == source.record_at(81) and source.record_at(81) != source.record_at(349), "DFU uint magic sound ID349 resolves to ordinal81, not ordinal349 thunder")
	var sample: AudioStreamWAV = audio.cache[81]
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(sample.data)
	check(sample.mix_rate == 11025 and sample.data.size() == 18284 and context.finish().hex_encode() == "fda727922c071cecb6e7fa8b51e704e8300e39043b002c91b21ffc92e93987f7", "Magic casting sound ID349/ordinal81 matches independent ordinal PCM audit")
	level.spellbook.open()
	await frames(2)
	var at: Vector2 = level.spellbook.list.global_position + level.spellbook.list.get_item_rect(1).get_center()
	await mouse_click(at)
	check(player.magic.selected == "light" and level.spellbook.visible and player.magic.current == 150 and cast_events.is_empty(), "Single spell click selects without casting or sound")
	# A genuine double-click on the other row exercises selection and activation together.
	await double_click_spell(0)
	check(not level.spellbook.visible and not player.modal_open and player.controls_active and player.magic.current == 75, "Double-click selects Heal, closes book and spends once immediately")
	check(cast_events == [81] and player.magic.last_cast == "heal" and player.combat.elapsed < 0, "Double-click plays one source cast cue without attack/click-through")
	check(player.casting.active() and not player.casting.request(player) and cast_events.size() == 1, "Repeat during hands cannot duplicate casting audio")
	var first: AudioStreamPlayer = audio.voices.back()
	player.casting.tick(player, 0.28)
	await frames(18)
	player.magic.select("light")
	check(player.casting.request(player) and cast_events == [81,81], "Next accepted cast starts its own sound without throttle")
	var second: AudioStreamPlayer = audio.voices.back()
	check(is_instance_valid(first) and first != second and first.playing and second.playing, "Back-to-back source cast sounds overlap on independent playing voices")
	check(first.stream == sample and second.stream == sample and is_equal_approx(second.volume_linear, audio.master_volume * audio.effects_volume), "Overlapping player-local cast cues share cached PCM and effects gains")
	player.casting.cancel()
	player.magic.current = 0
	level.spellbook.open()
	await frames(2)
	await double_click_spell(1)
	check(not level.spellbook.visible and player.magic.current == 0 and cast_events.size() == 2 and not player.casting.active(), "Insufficient double-click closes with feedback but no sound/effect/charge")
	check(player.casting.feedback == "Not enough magicka.", "Rejected book activation uses normal cast feedback")
	player.magic.current = 150
	player.controls_active = false
	level.spellbook.open()
	await frames(2)
	await double_click_spell(1)
	check(not player.modal_open and not player.controls_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.magic.current == 138 and cast_events.size() == 3, "Explicit book activation casts while preserving previously released capture")
	player.casting.cancel()
	var spent: int = player.magic.current
	level.spellbook.activate_spell(1)
	check(player.magic.current == spent and cast_events.size() == 3, "Stale hidden-book activation cannot cast or play sound")
	player.health.current = 0
	level.spellbook.activate_spell(1)
	check(player.magic.current == spent and cast_events.size() == 3, "Dead actor cannot activate book spell")
	player.health.current = player.health.maximum
	player.controls_active = true

func bind_magic() -> void:
	level = current_scene
	player = level.player
	window = level.loot_window
	hall = level.enemies[1]
	for enemy in level.enemies:
		enemy.melee.enabled = false
		enemy.navigation.enabled = false
	level.persistence.slot_path = PATH

func finish_magic() -> void:
	print("MAGIC RESULTS: %d/%d" % [results.size() - failures.size(), results.size()])
	var report := "res://tests/magic_cross_process_results.txt" if "--magic-read" in OS.get_cmdline_user_args() else "res://tests/magic_results.txt"
	FileAccess.open(report, FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	level = load("res://tests/bear_regression.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	current_scene = level
	await frames(12)
	bind_magic()
	if "--magic-read" in OS.get_cmdline_user_args():
		check(await level.persistence.load_slot(), "Separate process restores magic slot")
		bind_magic()
		player.set_physics_process(false)
		var data: Dictionary = level.persistence.read_slot()
		check(player.magic.known == data.player.magic.known and player.magic.selected == data.player.magic.selected and player.magic.last_cast == data.player.magic.last_cast and player.magic.current == int(data.player.magic.current) and is_equal_approx(player.spell_effects.remaining + player.fatigue.game_seconds, float(data.player.light_seconds) + float(data.player.fatigue.game_seconds)), "Cross-process knowledge, selection, recast, magicka and effect restore")
		check(not player.casting.active() and player.inventory.items.size() == 13 and player.health.maximum == 300, "Cross-process restore retains accepted baseline and clears casting")
		finish_magic()
		return
	check(player.health.maximum == 300 and hall.health.current == 30, "Accepted300HP and bear30HP remain")
	check(player.inventory.items.size() == 13 and player.inventory.armor_slots.values().count(0) == 7 and player.inventory.has_dagger(), "Thirteen instances, seven unequipped armor pieces and dagger unchanged")
	check(player.magic.known == ["heal", "light", "fire_bolt", "shock_bolt", "burning_touch", "shield", "teleport"] and player.magic.selected == "heal" and player.magic.last_cast == "", "Authored spell grants/select default; no last cast initially")
	check(player.magic.maximum() == 150 and player.magic.current == 150 and player.magic.recovery() == 18, "Explicit3x Intelligence capacity and source hourly recovery")
	check(Catalog.cost("heal", player.character) == 75 and Catalog.cost("light", player.character) == 12, "Pinned Heal/Light coefficients and school50 yield75/12 costs")
	check(not player.magic.select("unknown") and not Catalog.valid_known(["heal", "heal"]), "Unknown selection and duplicate grant rejected")
	var definition: Dictionary = level.classic.section.definition.duplicate(true)
	definition.prototype.player_test.known_spells = ["unknown"]
	check(not preload("res://scripts/classic_section.gd").new().validate(definition), "Section rejects unknown authored grant")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/magic_frames.json"))
	check(player.spell_payload.size() == 6, "All six external casting frames decode")
	for i in 6:
		var image: Image = player.spell_payload[i].texture.get_image()
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(image.get_data())
		check(image.get_size() == Vector2i(fixture.records[i].pixels[0], fixture.records[i].pixels[1]) and context.finish().hex_encode() == fixture.records[i].rgba_sha256, "Casting frame%d matches independent RGBA audit" % i)
	var decoder := preload("res://scripts/classic_data.gd").new()
	decoder.palette = level.classic.palette
	check(decoder.decode_spell_cif(PackedByteArray([1,2,3])).is_empty(), "Truncated casting data rejects safely")
	player.set_physics_process(false)
	player.controls_active = true
	check(not player.casting.request(player, true) and player.magic.current == 150, "Recast without history spends nothing")
	check(player.casting.request(player) and player.health.current == 300 and player.magic.current == 75, "Full-health heal commits immediately and spends75")
	check(not player.casting.request(player) and player.magic.current == 75, "Repeat while hands animate cannot double-charge")
	check(player.magic.last_cast == "heal" and player.casting.active(), "Successful cast remembers spell and starts hands")
	player.casting.tick(player, 0.28)
	check(not player.casting.active(), "Hands finish after seven40ms frames; no extra cooldown")
	player.health.current = 290
	check(player.casting.request(player, true) and player.health.current == 300 and player.magic.current == 0, "Immediate recast clamps healing and spends exactly once")
	player.casting.cancel()
	check(not player.casting.request(player) and player.magic.current == 0 and player.health.current == 300, "Insufficient-magicka cast has no effect/charge")
	player.magic.current = 150
	player.magic.select("light")
	check(player.casting.request(player) and player.spell_effects.remaining == 600 and player.spell_effects.light.visible, "Light starts immediately as separate scoped light")
	player.casting.cancel()
	check(player.casting.request(player) and player.spell_effects.remaining == 1200, "Light recast adds duration")
	player.casting.cancel()
	var spent: int = player.magic.current
	player.magic.select("heal")
	check(player.casting.request(player, true) and player.magic.last_cast == "light" and player.magic.current == spent-12, "Recast uses last successful cast independently of selection")
	player.casting.cancel()
	player.spell_effects.advance(1800)
	check(player.spell_effects.remaining == 0 and not player.spell_effects.light.visible, "Game-clock expiry removes only spell illumination")
	player.magic.current = 150
	player.character.set_live({"restoration":100, "intelligence":40})
	player.magic.sync_capacity()
	check(Catalog.cost("heal", player.character) == 12 and player.magic.current == 120, "Live school affects real cost and Intelligence clamps resource")
	player.character.set_live({"restoration":100, "intelligence":100})
	player.magic.sync_capacity()
	check(player.magic.maximum() == 300 and player.magic.current == 120, "Capacity increases never mint magicka")
	check(player.reload_movement() and player.character.stat("restoration") == 100 and player.magic.current == 120, "F3 retains overrides and depleted pool")
	var base: Dictionary = player.character.base.duplicate()
	player.magic_profile_path = "res://tests/missing_magic.cfg"
	check(not player.reload_movement() and player.character.base == base and player.magic.current == 120, "Invalid magic profile rejects entire combined reload atomically")
	player.magic_profile_path = "res://magic.cfg"
	player.character.set_live({})
	player.reload_movement()
	player.magic.current = 150
	player.magic.select("light")
	player.combat.request_attack(player)
	player.combat.tick(player, 0.05)
	var swing_elapsed: float = player.combat.elapsed
	var swing_frame: int = player.combat.weapon.source_frame
	check(player.casting.request(player), "Cast allowed in middle of melee swing")
	player._physics_process(0.1)
	check(player.combat.elapsed == swing_elapsed and player.combat.weapon.source_frame == swing_frame, "Casting freezes weapon frame and damage clock")
	check(not player.combat.request_attack(player), "New melee cannot compete with casting hands")
	await frames(2)
	check(not player.combat.weapon.visible and player.casting.view.visible, "Hands replace weapon HUD")
	await capture("magic_hands_4_3")
	level.presentation.set_profile("widescreen")
	await frames(2)
	await capture("magic_hands_widescreen")
	level.presentation.set_profile("dfu_reference")
	player.casting.tick(player, 0.3)
	player._physics_process(0.01)
	check(player.combat.elapsed > swing_elapsed, "Interrupted melee resumes original swing after hands finish")
	player.combat.cancel()
	player.climbing.active = true
	check(player.casting.request(player), "Self spell casts while climbing owns movement")
	player.casting.cancel()
	player.climbing.reset()
	player.combat.sheathed = true
	player.crouch.active = true
	check(player.casting.request(player), "Sheathed crouched casting allowed")
	player.casting.cancel()
	player.crouch.reset(player)
	player.position.y += 2.0
	player.falling.reset()
	player.casting.cancel()
	check(player.casting.request(player), "Airborne self cast commits without grounded gate")
	player.casting.cancel()
	player.position.y -= 2.0
	player.falling.reset()
	player.combat.sheathed = false
	player.fatigue.current = 0
	check(not player.casting.request(player), "Existing exhaustion policy gates casts")
	player.fatigue.current = player.fatigue.maximum()
	player.controls_active = false
	check(not player.casting.request(player), "Released controls cannot cast")
	player.controls_active = true
	player.casting.request(player)
	var committed: int = player.magic.current
	await routed(KEY_B)
	check(level.spellbook.visible and player.modal_open and not player.casting.active(), "B opens shared modal and clears hands")
	check(player.magic.current == committed and player.spell_effects.remaining > 0, "Cancelling committed hands never refunds or removes effect")
	check(level.spellbook.details.text.contains("Magicka") and level.spellbook.list.item_count == 7, "Book shows actual known state/resource")
	level.spellbook.choose(0)
	check(player.magic.selected == "heal" and player.magic.current == committed, "Book selection is harmless")
	await routed(KEY_Q)
	check(player.magic.current == committed, "Q in modal cannot cast/click through")
	var paused: float = player.spell_effects.remaining
	player.tick_fatigue(10, "normal")
	check(player.spell_effects.remaining == paused, "Modal pauses spell duration with world clock")
	await routed(KEY_I)
	check(window.visible and not level.spellbook.visible and level.modal.previous_capture, "I switches book to inventory preserving capture")
	await routed(KEY_B)
	check(window.source == null and level.world_loot.session_pile == null and not window.visible, "Book transition clears inventory source/drop session")
	await routed(KEY_C)
	check(level.character_sheet.visible and level.character_sheet.details.text.contains("Magicka:"), "C switches to sheet with magicka/schools")
	await routed(KEY_T)
	check(level.rest_window.visible and not level.character_sheet.visible, "T switches to common rest modal")
	await routed(KEY_B)
	check(not level.rest_window.rest.active and not level.rest_window.visible, "Switching to book stops rest")
	await routed(KEY_ESCAPE)
	check(player.controls_active and not player.modal_open, "Closing restores captured controls")
	player.controls_active = false
	await routed(KEY_B)
	await routed(KEY_B)
	check(not player.controls_active, "Book preserves already released preference")
	player.controls_active = true
	player.magic.current = 150
	player.magic.select("light")
	await routed(KEY_Q)
	check(player.magic.current == 138 and player.casting.active(), "Root-routed Q commits immediately")
	player.casting.cancel()
	player.magic.select("heal")
	await routed(KEY_F)
	check(player.magic.current == 126 and player.magic.last_cast == "light", "Root-routed F recasts last spell")
	player.casting.cancel()
	player.spell_effects.advance(player.spell_effects.remaining)
	player.spell_effects.apply("light",player)
	var clock: float = player.fatigue.game_seconds
	player.tick_fatigue(1, "normal")
	check(is_equal_approx(player.spell_effects.remaining,588) and player.fatigue.game_seconds == clock+12, "Effect duration consumes existing12x active game clock")
	player.magic.current = 0
	player.health.current = player.health.maximum
	player.fatigue.current = player.fatigue.maximum()
	check(not level.rest_window.rest.recovered(), "Full-rest completion includes depleted magicka")
	player.magic.no_regen = true
	player.magic.rest_hour()
	check(player.magic.current == 0, "No-regen policy disables hourly resource recovery")
	player.magic.no_regen = false
	# Actual rest pipeline on accepted hall support; remove nearby threat first.
	hall.health.apply_damage(1000)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await frames(5)
	player.set_physics_process(false)
	level.rest_window.open()
	check(level.rest_window.rest.start(24,true), "Full rest starts when only magicka needs recovery")
	level.rest_window.rest.tick(0.75)
	check(player.magic.current == 18 and player.spell_effects.remaining == 0, "Completed rest hour restores source amount and expires light")
	level.rest_window.rest.tick(18)
	check(player.magic.current == 150 and not level.rest_window.rest.active and level.rest_window.rest.hours_completed == 9, "Full rest ends when all resources recovered within24h cap")
	level.rest_window.close()
	player.magic.current = 60
	player.magic.select("light")
	player.casting.request(player)
	player.casting.cancel()
	player.magic.select("heal")
	var data: Dictionary = level.persistence.snapshot()
	check(data.version == 9 and level.persistence.validate(data), "Schema9 validates resource/knowledge/effect snapshot")
	for kind in ["unknown", "duplicate", "selection", "last", "negative", "fraction", "nan", "duration", "missing", "old"]:
		var bad := data.duplicate(true)
		match kind:
			"unknown": bad.player.magic.known = ["unknown"]
			"duplicate": bad.player.magic.known = ["heal","heal"]
			"selection": bad.player.magic.selected = "unknown"
			"last": bad.player.magic.last_cast = "unknown"
			"negative": bad.player.magic.current = -1
			"fraction": bad.player.magic.current = 1.5
			"nan": bad.player.magic.current = NAN
			"duration": bad.player.light_seconds = INF
			"missing": bad.player.erase("magic")
			"old": bad.version = 5
		check(not level.persistence.validate(bad), "Invalid magic save rejects: "+kind)
	check(level.persistence.write_slot(data), "Writes isolated magic slot without touching manual save")
	await routed(KEY_B)
	await routed(KEY_L)
	bind_magic()
	player.set_physics_process(false)
	check(player.magic.snapshot() == data.player.magic and player.spell_effects.remaining > 599 and not player.casting.active(), "L from book restores magic/effect and clears transient hands")
	check(player.controls_active and not player.modal_open, "Load from book resumes captured controls")
	player.magic.current = 150
	player.magic.select("light")
	player.casting.request(player)
	player.receive_damage(10000)
	check(player.is_dead() and not player.casting.active() and player.spell_effects.remaining == 0 and not player.spell_effects.light.visible, "Death clears hands/light without revival")
	await routed(KEY_L)
	bind_magic()
	check(not player.is_dead() and player.controls_active and player.magic.current == data.player.magic.current, "L from death restores resource and controls")
	await routed(KEY_B)
	await routed(KEY_R)
	bind_magic()
	check(player.magic.current == 150 and player.magic.last_cast == "" and player.spell_effects.remaining == 0 and not player.casting.active(), "R from book restores authored magic and clears all transient state")
	await routed(KEY_B)
	await capture("magic_book_4_3")
	level.presentation.set_profile("widescreen")
	await frames(2)
	await capture("magic_book_widescreen")
	await book_audio_checks()
	finish_magic()
