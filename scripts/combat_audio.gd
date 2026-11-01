extends Node
## Cached external samples and bounded one-shot voices, owned by this scene.
signal played(event: String, sound_id: int, spatial: bool)
const EVENTS := {
	"draw": [377], "miss": [106], "impact": [108, 109, 110, 111, 112],
	"wall": [433], "door": [7], "player_hit": [110, 111], "death": [15],
	"skeleton_move": [160], "skeleton_bark": [161], "skeleton_attack": [162],
}
const MAX_VOICES := 24
var archive := preload("res://scripts/classic_archive.gd").new()
var cache: Dictionary = {}
var voices: Array[Node] = []
var rng := RandomNumberGenerator.new()
var master_volume := 0.8
var effects_volume := 0.8
var draw_gain := 1.5
var enemy_range := 24.0
var error := ""

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	voices.clear()

func load_bank(arena_path: String) -> bool:
	rng.randomize()
	var config := ConfigFile.new()
	if config.load("res://audio.cfg") == OK:
		master_volume = clampf(float(config.get_value("volume", "master", 0.8)), 0.0, 1.0)
		effects_volume = clampf(float(config.get_value("volume", "effects", 0.8)), 0.0, 1.0)
		draw_gain = clampf(float(config.get_value("volume", "draw_gain", 1.5)), 0.0, 2.0)
		enemy_range = clampf(float(config.get_value("spatial", "enemy_range_metres", 24.0)), 1.0, 100.0)
	cache.clear()
	if not archive.open(arena_path.path_join("DAGGER.SND")):
		error = archive.error
		return false
	# SoundClips IDs index directory order, not BSA record names/IDs.
	for ids in EVENTS.values():
		for id in ids:
			if id >= archive.ordered_entries.size():
				error = "Missing DAGGER.SND sound index %d" % id
				cache.clear()
				return false
			if not cache.has(id):
				var stream := preload("res://scripts/classic_data.gd").decode_sound(archive.record_at(id))
				if stream == null:
					error = "Empty DAGGER.SND sound index %d" % id
					cache.clear()
					return false
				cache[id] = stream
	error = ""
	return true

func stop_creature(emitter: Node3D) -> void:
	# Impacts and the new body-fall cue are separate from the creature's voice.
	for voice in voices.duplicate():
		if voice.get_meta("creature_owner", 0) == emitter.get_instance_id():
			voices.erase(voice)
			voice.stop()
			voice.stream = null
			voice.queue_free()

func play(event: String, emitter: Node3D = null, gain: float = 1.0, at: Vector3 = Vector3.INF) -> void:
	if not EVENTS.has(event) or cache.is_empty():
		return
	var ids: Array = EVENTS[event]
	var id: int = ids[rng.randi_range(0, ids.size() - 1)]
	if not cache.has(id):
		return
	# Bound overlapping voices and reclaim explicitly on completion/restart.
	if voices.size() >= MAX_VOICES:
		var oldest: Node = voices.pop_front()
		oldest.stop()
		oldest.stream = null
		oldest.queue_free()
	var voice: Node
	if is_instance_valid(emitter):
		var source := AudioStreamPlayer3D.new()
		source.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		source.max_distance = enemy_range if event.begins_with("skeleton_") or event == "death" else 16.0
		add_child(source)
		source.global_position = emitter.global_position + Vector3.UP * 0.8
		if at.is_finite():
			source.global_position = at
		voice = source
	else:
		voice = AudioStreamPlayer.new()
		add_child(voice)
	voice.stream = cache[id]
	voice.volume_linear = master_volume * effects_volume * clampf(gain, 0.0, 1.0) * (draw_gain if event == "draw" else 1.0)
	if event.begins_with("skeleton_") and is_instance_valid(emitter):
		voice.set_meta("creature_owner", emitter.get_instance_id())
	voices.append(voice)
	voice.finished.connect(func():
		voices.erase(voice)
		voice.queue_free())
	voice.play()
	played.emit(event, id, is_instance_valid(emitter))
