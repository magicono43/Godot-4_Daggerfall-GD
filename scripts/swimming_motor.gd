extends RefCounted
## Dungeon swimming owns motion exclusively. No changes to land tuning.
const BREATH_UNIT_SECONDS := 20.0 * 0.0625 # PlayerEntity + GameManager classic ticks.
const SURFACE_MARGIN := 0.04 # Metres of hysteresis against surface oscillation.
var volumes: Array[RefCounted] = []
var volume: RefCounted
var active := false
var immersed := false # Water eligibility is independent of climbing ownership.
var wet := false
var submerged := false
var breath_seconds := -1.0 # Fresh breath on next submersion.
var death_reason := ""
var rng := RandomNumberGenerator.new()

func maximum_breath(actor: CharacterBody3D) -> float:
	return floorf(actor.character.stat("endurance") / 2.0) * BREATH_UNIT_SECONDS

func water_at(at: Vector3) -> RefCounted:
	for water in volumes:
		if water.contains(at):
			return water
	return null

func touching(actor: CharacterBody3D) -> bool:
	return water_at(actor.global_position + Vector3.UP * 0.02) != null

func support(actor: CharacterBody3D, distance: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.08, actor.global_position + Vector3.DOWN * distance, 1, [actor.get_rid()])
	return actor.get_world_3d().direct_space_state.intersect_ray(query)

func classify(actor: CharacterBody3D) -> void:
	volume = water_at(actor.global_position + Vector3.UP * 0.02)
	wet = volume != null
	submerged = wet and actor.global_position.y + actor.crouch.eye_height < volume.surface() - 0.02
	if not wet:
		immersed = false
		active = false
		return
	var height := float(actor.capsule_collision.shape.height)
	var depth: float = volume.surface() - actor.global_position.y
	var floor_hit := support(actor, 0.4)
	# Reachable shallow shelves hand back to the unchanged ground/stair motor.
	var wading: bool = not floor_hit.is_empty() and floor_hit.normal.y >= cos(actor.floor_max_angle) and volume.surface() - floor_hit.position.y <= height * 0.9
	immersed = not wading and depth >= height * 0.7 - (SURFACE_MARGIN if immersed else 0.0)
	active = immersed and not actor.climbing.active

func clear_motion(actor: CharacterBody3D) -> void:
	actor.velocity = Vector3.ZERO
	actor.flight_horizontal = Vector3.ZERO
	actor.input_axes = Vector2.ZERO
	actor.stair_supported = false
	actor.grounded_time = 0.0
	actor.step_camera_offset = 0.0
	actor.last_step = 0.0
	actor.is_running = false
	# Refresh stale engine floor flags without pulling toward the previous floor.
	var snap := actor.floor_snap_length
	actor.floor_snap_length = 0.0
	actor.move_and_slide()
	actor.floor_snap_length = snap

func reclassify(actor: CharacterBody3D) -> void:
	classify(actor)
	if active:
		actor.climbing.reset()
		actor.falling.suspend(actor.global_position)
	if not submerged:
		breath_seconds = -1.0

func reset() -> void:
	active = false
	immersed = false
	wet = false
	submerged = false
	volume = null
	breath_seconds = -1.0

func deep_catch(actor: CharacterBody3D) -> bool:
	if not active:
		return false
	var hit := support(actor, 100.0)
	return not hit.is_empty() and hit.normal.y > 0.5 and volume.surface() - hit.position.y >= actor.STANDING_HEIGHT + actor.CAPSULE_RADIUS and actor.global_position.y - hit.position.y > actor.CAPSULE_RADIUS

func tick(actor: CharacterBody3D, delta: float, input: Vector2, resolved: Dictionary) -> bool:
	var previous := active
	classify(actor)
	if active and not deep_catch(actor) and actor.falling.active:
		# Thin/shallow water cannot erase an already accrued fall. Classification
		# may already have changed after the previous land tick's collision move.
		actor.land(actor.falling.resolve(maxf(0, actor.falling.departure_height - actor.global_position.y)))
	if active != previous:
		clear_motion(actor)
	if not active or actor.is_dead():
		return false
	# Keep the climb contact/delay tracker alive while pushing through water.
	actor.falling.suspend(actor.global_position)
	var vertical := 0.0
	if actor.controls_active:
		vertical = Input.get_action_strength("swim_up") - Input.get_action_strength("swim_down")
	var direction: Vector3 = actor.global_basis * Vector3(input.x, 0, input.y) + Vector3.UP * vertical
	direction = direction.limit_length(1.0)
	actor.velocity = direction * float(resolved.swim_walk_speed)
	# Surface cap prevents repeated land/swim handovers while ascending.
	var ceiling: float = volume.surface() - float(actor.capsule_collision.shape.height) * 0.7 + SURFACE_MARGIN * 0.5
	actor.velocity.y = minf(actor.velocity.y, maxf(0, ceiling - actor.global_position.y) / delta)
	var snap := actor.floor_snap_length
	actor.floor_snap_length = 0.0
	actor.move_and_slide()
	actor.floor_snap_length = snap
	classify(actor)
	actor.tick_fatigue(delta, "swimming")
	resources(actor, delta)
	return true

func resources(actor: CharacterBody3D, delta: float) -> void:
	if actor.modal_open or not actor.controls_active or actor.is_dead():
		return
	if not submerged:
		breath_seconds = -1.0
	else:
		if breath_seconds < 0:
			breath_seconds = maximum_breath(actor)
		breath_seconds = minf(breath_seconds, maximum_breath(actor)) - delta
		if breath_seconds <= 0:
			kill(actor, "You drowned.")
	if immersed and actor.fatigue.exhausted() and not actor.is_dead():
		kill(actor, "You drowned from exhaustion.")

func kill(actor: CharacterBody3D, reason: String) -> void:
	death_reason = reason
	# DFU SetHealth(0): drowning bypasses damage absorption, including Shield.
	actor.health.apply_damage(actor.health.current)

func fatigue_cost(skill: float, roll: int) -> int:
	return 11 if roll <= skill else 44

