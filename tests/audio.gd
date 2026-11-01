extends "res://tests/climbing.gd"
var events: Array[String] = []

func check(ok: bool, label: String) -> void:
	results.append(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)
	print(results[-1])

func run() -> void:
	var level = load("res://main.tscn").instantiate()
	level.enemy_navigation_enabled = false
	root.add_child(level)
	await frames(5)
	player = level.player
	var hall = level.world_root.get_node("hall_combat_target")
	hall.melee.enabled = false
	hall.set_physics_process(false)
	player.set_physics_process(false)
	var audio = level.combat_audio
	audio.played.connect(func(event, _id, _spatial): events.append(event))
	check(audio.error.is_empty() and audio.cache.size() == 13, "All thirteen selected original samples load")
	check(level.presentation.viewport.audio_listener_enable_3d, "World viewport enables spatial audio listener")
	var pcm := ClassicData.decode_sound(PackedByteArray([0, 127, 128, 255]))
	check(pcm.data == PackedByteArray([128, 255, 0, 127]), "Unsigned source PCM converts to signed Godot PCM")
	check(pcm.mix_rate == 11025 and not pcm.stereo and pcm.format == AudioStreamWAV.FORMAT_8_BITS, "Original mono sample rate and bit depth retained")
	check(ClassicData.decode_sound(PackedByteArray()) == null, "Empty sound rejects decode")
	var source := preload("res://scripts/classic_archive.gd").new()
	check(source.open(level.classic.arena_path.path_join("DAGGER.SND")), "Original sound archive opens read-only")
	var raw := source.record_at(377)
	var decoded: PackedByteArray = audio.cache[377].data
	var matches := decoded.size() == raw.size()
	for i in raw.size():
		if decoded[i] != (raw[i] ^ 128):
			matches = false
	check(matches, "Complete draw sample preserves every original PCM sample")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/audio_samples.json"))
	check(source.ordered_entries.size() == int(fixture.count) and source.entries.size() == int(fixture.unique_ids), "Ordinal directory preserves duplicate sound IDs")
	var audit_matches := true
	for item in fixture.records:
		var stream := ClassicData.decode_sound(source.record_at(int(item.index)))
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(stream.data)
		if stream.data.size() != int(item.size) or context.finish().hex_encode() != item.pcm_sha256:
			audit_matches = false
		if audio.cache.has(int(item.index)) and audio.cache[int(item.index)].data != stream.data:
			audit_matches = false
	check(audit_matches, "Independent raw-directory hashes pin duplicate records, dagger draw and terrain clip")
	check(source.record_at(-1).is_empty() and source.record_at(459).is_empty(), "Invalid ordinal lookup returns no sound")
	player.combat.toggle_sheath()
	check(events.is_empty(), "Sheathing does not invent a draw sound")
	player.combat.toggle_sheath()
	check(events == ["draw"], "Drawing emits one original draw sound")
	check(audio.voices.back() is AudioStreamPlayer and is_equal_approx(audio.voices.back().volume_linear, audio.master_volume * audio.effects_volume * audio.draw_gain), "Dagger draw is listener-relative with dedicated gain")
	events.clear()
	player.position = hall.position + Vector3(-1.5, 0.02, 0)
	player.camera.look_at(hall.global_position + Vector3.UP)
	await frames(3)
	player.combat.request_attack(player)
	player.combat.cancel()
	check(events.is_empty(), "Cancelled windup emits no strike sound")
	player.combat.request_attack(player)
	player.combat.tick(player, player.combat.windup + 0.001)
	check(events == ["impact"] and hall.health.current == 20, "Actual strike emits one impact with damage")
	var impact_voice: AudioStreamPlayer3D = audio.voices.back()
	check(impact_voice.global_position.distance_to(player.camera.global_position) < 3.0, "Impact voice uses contact position")
	player.combat.tick(player, 0.02)
	check(events.size() == 1, "Continued attack frame never repeats impact")
	events.clear()
	hall.sound_wait = 0.0
	hall._physics_process(0.01)
	check(events.size() == 1 and events[0] in ["skeleton_move", "skeleton_bark"], "Nearby live skeleton emits periodic attract sound")
	check(hall.sound_wait >= 3 and hall.sound_wait <= 9 and hall.sound_wait == floorf(hall.sound_wait), "Ambient cue schedules integer three-to-nine-second delay")
	check(audio.voices.back().max_distance == 24.0, "Creature voice uses extended configured range")
	events.clear()
	hall._physics_process(2.9)
	check(events.is_empty(), "Ambient cue cannot repeat before minimum delay")
	events.clear()
	hall.sound_wait = 0.0
	player.controls_active = false
	hall._physics_process(0.01)
	check(events.is_empty(), "Mouse release suspends skeleton attract audio")
	player.controls_active = true
	player.combat.cancel()
	player.camera.rotation = Vector3(-0.3, PI, 0)
	player.combat.request_attack(player)
	player.combat.tick(player, player.combat.windup + 0.001)
	check(events.back() == "miss" and audio.voices.back() is AudioStreamPlayer, "Air swing produces listener-relative miss sound")
	player.combat.cancel()
	player.camera.look_at(hall.global_position + Vector3.UP)
	arena = level.world_root
	var wall := box(Vector3(0.1, 3, 3), player.position.lerp(hall.position, 0.5) + Vector3.UP)
	await frames(3)
	player.combat.request_attack(player)
	player.combat.tick(player, player.combat.windup + 0.001)
	check(events.back() == "wall" and hall.health.current == 20, "Wall blocks damage and produces positional impact")
	var door := preload("res://scripts/door.gd").new()
	var door_shape := CollisionShape3D.new()
	door_shape.shape = wall.get_child(0).shape.duplicate()
	door.add_child(door_shape)
	door.position = wall.position
	arena.add_child(door)
	wall.queue_free()
	await frames(3)
	player.combat.cancel()
	player.combat.request_attack(player)
	player.combat.tick(player, player.combat.windup + 0.001)
	check(events.back() == "door" and audio.voices.back().stream == audio.cache[7] and hall.health.current == 20, "Door obstruction uses distinct original bash sound without damage")
	door.queue_free()
	player.combat.cancel()
	await frames(3)
	events.clear()
	hall.melee.enabled = true
	hall.mobile.set_state("idle")
	hall.sound_rng.seed = 42
	hall.melee.tick(hall, 0.01)
	check(hall.melee.phase == "windup", "Skeleton attack still commits independently of growl probability")
	events.clear()
	hall.sound_rng.seed = 42
	var expected := RandomNumberGenerator.new()
	expected.seed = 42
	var expected_count := 0
	for i in 100:
		if expected.randf() > 0.5:
			expected_count += 1
		hall.play_sound("skeleton_attack")
	check(events.size() == expected_count and expected_count > 0 and expected_count < 100, "Attack growls follow seeded fifty-percent chance rather than every attack")
	hall.melee.cancel()
	player.receive_damage(10)
	check(events.back() == "player_hit", "Accepted player damage emits nonvoice feedback")
	var count := events.size()
	player.receive_damage(0)
	check(events.size() == count, "Rejected damage emits no sound")
	var owned: Array[Node] = []
	for voice in audio.voices:
		if voice.get_meta("creature_owner", 0) == hall.get_instance_id():
			owned.append(voice)
	var other = level.enemy
	audio.play("skeleton_bark", other)
	var other_voice: Node = audio.voices.back()
	audio.play("impact", hall)
	var hit_voice: Node = audio.voices.back()
	hall.receive_damage(100)
	check(events.back() == "death", "Skeleton death emits body fall")
	var stopped := not owned.is_empty()
	for voice in owned:
		stopped = stopped and not voice.playing and not audio.voices.has(voice)
	check(stopped and audio.voices.has(other_voice) and other_voice.playing and hit_voice.playing, "Death immediately stops own creature voices, preserving other enemies and impacts")
	count = events.size()
	hall.receive_damage(10)
	check(events.size() == count, "Corpse cannot repeat death audio")
	hall.sound_wait = 0.0
	hall._physics_process(0.01)
	check(events.size() == count, "Corpse emits no periodic attract audio")
	# Inspect actual mixer output; this verifies playback, not listening quality.
	for voice in audio.voices:
		voice.stop()
		voice.queue_free()
	audio.voices.clear()
	OS.delay_msec(100)
	await process_frame
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, capture)
	audio.play("skeleton_attack", player, 1.0, player.camera.global_position + Vector3(0, 0, -20))
	await process_frame
	await process_frame
	OS.delay_msec(350)
	await process_frame
	var mixed := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in mixed:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(peak > 0.001, "Creature sample reaches mixer twenty metres away beyond old cutoff")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	var broken = preload("res://scripts/combat_audio.gd").new()
	root.add_child(broken)
	check(not broken.load_bank("res://tests/no_audio_archive") and broken.cache.is_empty(), "Missing archive leaves audio safely disabled")
	broken.play("draw")
	check(broken.voices.is_empty(), "Unavailable bank cannot create broken playback voices")
	broken.queue_free()
	audio.master_volume = 0.0
	audio.play("draw")
	check(audio.voices.back().volume_linear == 0.0, "Zero master volume fully mutes new voices")
	for i in 40:
		audio.play("draw")
	check(audio.voices.size() == audio.MAX_VOICES, "One-shot voice count stays bounded")
	var old_audio: WeakRef = weakref(audio)
	level.queue_free()
	await frames(3)
	# The mixer runs in wall time even when physics tests run at fixed FPS.
	OS.delay_msec(150)
	await process_frame
	check(old_audio.get_ref() == null, "Scene teardown frees bank and all voices")
	print("AUDIO RESULTS: ", results.size() - failures.size(), "/", results.size())
	FileAccess.open("res://tests/audio_results.txt", FileAccess.WRITE).store_string("\n".join(results))
	quit(0 if failures.is_empty() else 1)
