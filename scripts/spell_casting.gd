extends RefCounted
## Self spells commit immediately. Only the visual occupies time, freezing weapon timing.
const Catalog = preload("res://scripts/spell_catalog.gd")
const SEQUENCE := [0, 1, 2, 3, 4, 5, 0]
const FRAME_SECONDS := 0.04 # Pinned DFU renderer; not an audited vanilla frame rate.
var elapsed := -1.0
var feedback := ""
var feedback_time := 0.0
var view: Control

func setup(actor: CharacterBody3D) -> void:
	view = preload("res://scripts/spell_view.gd").new()
	view.actor = actor
	actor.combat.weapon.get_parent().add_child(view)

func active() -> bool:
	return elapsed >= 0

func request(actor: CharacterBody3D, recast := false, book_activation := false) -> bool:
	# An explicit book activation may cast while preserving a released mouse preference.
	if active() or actor.modal_open or actor.is_dead() or (not actor.controls_active and not book_activation):
		return false
	var id: String = actor.magic.last_cast if recast else actor.magic.selected
	actor.magic.sync_capacity()
	if id.is_empty() or id not in actor.magic.known:
		return reject("No previous spell." if recast else "B opens your spellbook.")
	var cost := Catalog.cost(id, actor.character)
	if actor.magic.current < cost:
		return reject("Not enough magicka.")
	if actor.fatigue.exhausted():
		return reject("You are exhausted. T opens rest.")
	# No benefit checks: casting at full health still spends the full cost.
	actor.magic.current -= cost
	actor.spell_effects.apply(id, actor)
	if is_instance_valid(actor.combat_audio):
		actor.combat_audio.play("cast_magic")
	actor.magic.last_cast = id
	elapsed = 0.0
	feedback = "%s (-%d magicka)" % [Catalog.SPELLS[id].name, cost]
	feedback_time = 1.5
	return true

func reject(message: String) -> bool:
	feedback = message
	feedback_time = 1.5
	return false

func tick(actor: CharacterBody3D, delta: float) -> void:
	feedback_time = maxf(0, feedback_time - delta)
	if actor.is_dead() or actor.modal_open or not actor.controls_active:
		cancel()
		return
	if active():
		elapsed += delta
		if elapsed + 0.000001 >= FRAME_SECONDS * SEQUENCE.size():
			cancel()

func cancel() -> void:
	elapsed = -1.0
