extends RefCounted
## A bounded, interruptible rest session. Actor ownership stays in player/health.
const SECONDS_PER_HOUR := 0.75
const MAX_HOURS := 24
var level: Node3D
var active := false
var until_recovered := false
var hours_left := 0
var hours_completed := 0
var elapsed := 0.0
var observed_health := 0
var message := "Choose a rest duration."

func nearby_threat() -> bool:
	var player: CharacterBody3D = level.player
	for enemy in level.enemies:
		# The intentionally passive chamber fixture is not a hostile encounter.
		if enemy.health.current <= 0 or not (enemy.melee.enabled or enemy.navigation.enabled):
			continue
		var distance: float = enemy.global_position.distance_to(player.global_position)
		# Conservative 12m proximity rule, including a foe behind a nearby door.
		if distance <= 12.0:
			return true
		if distance <= 20.0:
			var query := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 0.5, player.global_position + Vector3.UP * float(player.capsule_collision.shape.height) * 0.5, 3, [enemy.get_rid()])
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider == player:
				return true
	return false

func refusal() -> String:
	var player: CharacterBody3D = level.player
	if player.is_dead():
		return "You cannot rest while dead. L loads your save."
	if level.actions.moving():
		return "Wait for the mechanism to stop."
	if player.swimming.touching(player):
		return "Leave the water before resting."
	if player.climbing.active or not player.is_grounded():
		return "Stand on supported ground before resting."
	var support_query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.1, player.global_position + Vector3.DOWN * 0.25, 1)
	var support := player.get_world_3d().direct_space_state.intersect_ray(support_query)
	if support.is_empty() or support.normal.y < 0.7 or support.collider.get_meta("section_role", "") not in ["geometry", "prop"]:
		return "No safe surface for resting."
	if Vector2(player.velocity.x, player.velocity.z).length() > 0.03 or absf(player.velocity.y) > 1.0:
		return "Stop moving before opening rest."
	var low: bool = player.crouch.is_low(player)
	var eye: float = player.crouch.EYE if low else player.EYE_HEIGHT
	if player.crouch.toggled != low or absf(player.crouch.eye_height - eye) > 0.002:
		return "Wait for your posture to settle before resting."
	for door in level.doors:
		if door.busy:
			return "Wait for the door to stop."
	if nearby_threat():
		return "Enemies are nearby. Find a safer place to rest."
	return ""

func recovered() -> bool:
	var player: CharacterBody3D = level.player
	player.fatigue.sync_capacity()
	player.magic.sync_capacity()
	return player.magic.current == player.magic.maximum() and player.health.current == player.health.maximum and player.fatigue.current == player.fatigue.maximum()

func start(hours: int, full := false) -> bool:
	message = refusal()
	if not message.is_empty():
		return false
	if hours < 1 or hours > MAX_HOURS:
		message = "Choose between 1 and 24 hours."
		return false
	if recovered():
		message = "You are already fully recovered."
		return false
	observed_health = level.player.health.current
	active = true
	until_recovered = full
	hours_left = hours
	hours_completed = 0
	elapsed = 0.0
	message = "Resting..."
	return true

func stop(reason := "Rest stopped. Completed hours are kept.") -> void:
	active = false
	elapsed = 0.0
	message = reason

func tick(delta: float) -> void:
	if not active or not is_finite(delta) or delta <= 0:
		return
	if level.player.health.current < observed_health:
		stop("Rest interrupted by damage.")
		return
	var reason := refusal()
	if not reason.is_empty():
		stop(reason)
		return
	elapsed += delta
	while active and elapsed >= SECONDS_PER_HOUR:
		# Recheck before every recovery award, including large frame deltas.
		reason = refusal()
		if not reason.is_empty():
			stop(reason)
			return
		elapsed -= SECONDS_PER_HOUR
		level.player.fatigue.rest_hour(level.player.health)
		level.player.magic.rest_hour()
		level.player.spell_effects.advance(3600.0)
		observed_health = level.player.health.current
		hours_left -= 1
		hours_completed += 1
		if recovered():
			stop("You are fully recovered.")
		elif hours_left == 0:
			stop("Rest finished." if not until_recovered else "24-hour rest limit reached. You can rest again.")
