extends RefCounted
## Self effects commit immediately; targeted spells own a separate ready/release lifecycle.
const Catalog = preload("res://scripts/spell_catalog.gd")
const SEQUENCE := [0, 1, 2, 3, 4, 5, 0]
const FRAME_SECONDS := 0.04 # Pinned DFU renderer; not an audited vanilla frame rate.
var ready_id := ""
var ready_cost := 0
var animation_spell: Dictionary = {}
var released := false
var projectiles: Node3D
var element := "magic"
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

func owns_weapon() -> bool:
	return active() or not ready_id.is_empty()

func request(actor: CharacterBody3D, recast := false, book_activation := false) -> bool:
	# An explicit book activation may cast while preserving a released mouse preference.
	if owns_weapon() or actor.modal_open or actor.is_dead() or (not actor.controls_active and not book_activation):
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
	var spell: Dictionary = Catalog.SPELLS[id]
	if spell.get("target", "self") != "self":
		ready_id = id
		ready_cost = cost
		feedback = "%s ready | LMB release | Esc cancel" % spell.name
		feedback_time = 1.5
		return true
	# No benefit checks: casting at full health still spends the full cost.
	actor.magic.current -= cost
	actor.spell_effects.apply(id, actor)
	if is_instance_valid(actor.combat_audio):
		actor.combat_audio.play("cast_magic")
	actor.magic.last_cast = id
	element = "magic"
	animation_spell = {}
	elapsed = 0.0
	feedback = "%s (-%d magicka)" % [Catalog.SPELLS[id].name, cost]
	feedback_time = 1.5
	if id == "teleport":
		actor.teleport_requested.emit()
	return true

func release(actor: CharacterBody3D) -> bool:
	if ready_id.is_empty() or active() or actor.modal_open or actor.is_dead() or not actor.controls_active:
		return false
	actor.magic.sync_capacity()
	if actor.fatigue.exhausted():
		return reject("You are exhausted. T opens rest.")
	if actor.magic.current < ready_cost:
		return reject("Not enough magicka.")
	var spell: Dictionary = Catalog.SPELLS[ready_id]
	if spell.target == "touch" and projectiles.touch_target().is_empty():
		return reject("No enemy within touch range.")
	actor.magic.current -= ready_cost
	actor.magic.last_cast = ready_id
	animation_spell = spell.duplicate()
	element = spell.element
	feedback = "%s (-%d magicka)" % [spell.name, ready_cost]
	feedback_time = 1.5
	ready_id = ""
	ready_cost = 0
	released = false
	elapsed = 0.0
	if is_instance_valid(actor.combat_audio):
		actor.combat_audio.play("cast_" + element)
	return true

func reject(message: String) -> bool:
	feedback = message
	feedback_time = 1.5
	return false

func tick(actor: CharacterBody3D, delta: float) -> void:
	feedback_time = maxf(0, feedback_time - delta)
	if actor.is_dead() or actor.modal_open:
		cancel()
		return
	if not actor.controls_active:
		# Book activation preserves prior mouse preference. Keep a readied spell
		# until recapture, but discard any already-committed hands/release event.
		if active():
			cancel()
		return
	if active():
		elapsed += delta
		if not animation_spell.is_empty() and not released and elapsed + 0.000001 >= FRAME_SECONDS * 5:
			released = true
			if animation_spell.target == "touch":
				projectiles.touch(animation_spell)
			else:
				projectiles.launch(animation_spell)
		if elapsed + 0.000001 >= FRAME_SECONDS * SEQUENCE.size():
			cancel()

func cancel() -> void:
	ready_id = ""
	ready_cost = 0
	animation_spell = {}
	released = false
	elapsed = -1.0
