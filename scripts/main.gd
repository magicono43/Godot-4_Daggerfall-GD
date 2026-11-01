extends Node3D
const Data = preload("res://scripts/classic_data.gd")
const Player = preload("res://scripts/player.gd")
const Door = preload("res://scripts/door.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Presentation = preload("res://scripts/classic_presentation.gd")
const Billboard = preload("res://scripts/classic_billboard.gd")
var section_path := Data.DEFAULT_SECTION
var model_nodes: Dictionary = {}
var billboard_nodes: Dictionary = {}
var doors: Array[AnimatableBody3D] = []
var enemies: Array[CharacterBody3D] = []
var presentation: Node
var world_root: Node3D
var classic := Data.new()
var player: CharacterBody3D
var door: AnimatableBody3D
var enemy: CharacterBody3D
var prompt: Label
var status: Label
var player_status: Label
var damage_overlay: ColorRect
var movement_status: Label
var encounter := false
var door_used := false
var ready_to_play := false
var use_original_start := false
var enemy_navigation_enabled := true
var combat_audio: Node

func _ready() -> void:
	configure_input()
	presentation = Presentation.new()
	add_child(presentation)
	world_root = presentation.world_root
	var config := ConfigFile.new()
	if config.load("res://data_source.cfg") == OK:
		classic.arena_path = config.get_value("classic", "arena2", classic.arena_path)
		section_path = config.get_value("classic", "section", section_path)
	create_environment()
	create_hud()
	if not classic.load_slice(section_path):
		status.text = "SECTION COULD NOT LOAD\n" + classic.error + "\nCheck section/data_source.cfg, then press R to retry."
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	combat_audio = preload("res://scripts/combat_audio.gd").new()
	world_root.add_child(combat_audio)
	if not combat_audio.load_bank(classic.arena_path):
		push_warning("Combat audio unavailable: " + combat_audio.error)
	for item in classic.objects:
		var mesh := classic.build_mesh(item.model)
		var body: PhysicsBody3D
		if item.role == "door":
			body = AnimatableBody3D.new()
			body.set_script(Door)
			body.sync_to_physics = false
			doors.append(body)
		else:
			body = StaticBody3D.new()
		body.name = "Classic_%s_%d" % [item.model, item.offset]
		body.set_meta("section_id", item.id)
		body.set_meta("section_role", item.role)
		world_root.add_child(body)
		body.transform = item.transform
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		body.add_child(instance)
		model_nodes[item.id] = body
		if item.collision:
			var collision := CollisionShape3D.new()
			var trimesh := mesh.create_trimesh_shape()
			trimesh.backface_collision = true
			collision.shape = trimesh
			body.add_child(collision)
		if item.role == "door":
			body.closed_basis = body.basis
	# The primary milestone door follows authored section order, not RDB
	# linked-list traversal order, which changes as more doors are selected.
	for entry in classic.section.definition.models:
		if entry.role == "door":
			door = model_nodes[entry.id]
			break
	for payload in classic.billboards:
		var sprite := AnimatedSprite3D.new()
		sprite.set_script(Billboard)
		sprite.configure(payload)
		world_root.add_child(sprite)
		billboard_nodes[payload.id] = sprite
	var definition: Dictionary = classic.section.definition
	for entry in definition.prototype.boundaries:
		add_boundary(classic.to_world(entry.position_native), deg_to_rad(entry.yaw_degrees), Vector3(entry.size_metres[0], entry.size_metres[1], entry.size_metres[2]), entry.id)
	player = CharacterBody3D.new()
	player.set_script(Player)
	player.vertical_fov = presentation.vertical_fov
	player.weapon_payload = classic.dagger_frames
	player.combat_audio = combat_audio
	player.name = "Player"
	world_root.add_child(player)
	player.spawn = classic.provenance.start + Vector3.UP * 0.1
	player.position = player.spawn
	# Face the centre of the original cave opening from the original enter marker.
	var opening := classic.to_world(definition.spawn.look_at_native)
	if definition.prototype.has("player_start") and not use_original_start:
		var start: Dictionary = definition.prototype.player_start
		player.spawn = classic.to_world(start.position_native) + Vector3.UP * 0.1
		player.position = player.spawn
		opening = classic.to_world(start.look_at_native)
	player.look_at(Vector3(opening.x, player.position.y, opening.z))
	for interactive_door in doors:
		interactive_door.player = player
		interactive_door.used.connect(func(): door_used = true)
	for entry in definition.prototype.enemies:
		var placeholder := CharacterBody3D.new()
		placeholder.set_script(Enemy)
		placeholder.approach_enabled = entry.get("approach_enabled", true)
		placeholder.navigation.enabled = enemy_navigation_enabled and entry.get("navigation_enabled", false)
		placeholder.melee.enabled = entry.get("attack_enabled", false)
		placeholder.sprite_payload = classic.enemy_visuals.get(entry.get("visual", "greybox"), {})
		placeholder.combat_audio = combat_audio
		placeholder.name = entry.id
		placeholder.player = player
		placeholder.position = classic.to_world(entry.position_native)
		world_root.add_child(placeholder)
		placeholder.encountered.connect(func(): encounter = true)
		enemies.append(placeholder)
	enemy = enemies[0] if not enemies.is_empty() else null
	for entry in definition.prototype.lights:
		add_light(classic.to_world(entry.position_native), entry.energy, entry.range_metres)
	ready_to_play = true
	print("CLASSIC_SLICE ", classic.provenance, " triangles=", classic.triangle_count, " textures=", classic.texture_count)
	if "--capture" in OS.get_cmdline_user_args():
		capture_preview()

func configure_input() -> void:
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("attack", click)
	var keys := {"ready_weapon": KEY_Z, "crouch": KEY_CTRL, "forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E, "release_mouse": KEY_ESCAPE, "reset": KEY_R, "toggle_view": KEY_F2, "reload_movement": KEY_F3, "movement_debug": KEY_F4}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)

func create_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.027, 0.033)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.46, 0.55)
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	world_root.add_child(world)

func add_light(pos: Vector3, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_energy = energy
	light.omni_range = radius
	light.light_color = Color(1, 0.75, 0.46)
	world_root.add_child(light)

func add_boundary(pos: Vector3, yaw: float, dimensions: Vector3, section_id: String) -> void:
	var body := StaticBody3D.new()
	body.name = "GreyboxSliceBoundary"
	body.add_to_group("slice_boundaries")
	body.set_meta("section_id", section_id)
	body.position = pos
	body.rotation.y = yaw
	world_root.add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.25, 0.28)
	instance.material_override = mat
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	body.add_child(shape)

func create_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	presentation.hud = root
	presentation.update_layout()
	damage_overlay = ColorRect.new()
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_overlay)
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(0.7, 0.02, 0.02, 0)
	player_status = Label.new()
	root.add_child(player_status)
	player_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	player_status.position += Vector2(-260, 24)
	player_status.size = Vector2(230, 60)
	player_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_status.add_theme_font_size_override("font_size", 20)
	var title := Label.new()
	title.text = "PRIVATEER'S HOLD"
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(0.92, 0.81, 0.6)
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "EXPERIMENT 01  /  Original dungeon geometry"
	subtitle.position = Vector2(29, 55)
	subtitle.add_theme_font_size_override("font_size", 14)
	root.add_child(subtitle)
	status = Label.new()
	status.position = Vector2(29, 85)
	status.add_theme_font_size_override("font_size", 15)
	root.add_child(status)
	movement_status = Label.new()
	movement_status.position = Vector2(29, 180)
	movement_status.add_theme_font_size_override("font_size", 14)
	movement_status.visible = false
	root.add_child(movement_status)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.position += Vector2(-200, 25)
	prompt.size = Vector2(400, 40)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position -= Vector2(5, 13)
	root.add_child(crosshair)
	var controls := Label.new()
	controls.text = "WASD Move  |  Ctrl Toggle crouch  |  Shift Run  |  Space Jump  |  E Door  |  RMB Attack  |  Z Draw/Sheath  |  Esc Mouse  |  R Restart\nClimb: W into wall or S over ledge  |  W/S Up/Down  |  A/D Along wall  |  Space Eject\nF2 View  |  F3 Reload movement  |  F4 Movement diagnostics"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(29, -82)
	controls.add_theme_font_size_override("font_size", 14)
	root.add_child(controls)

func _process(_delta: float) -> void:
	if not ready_to_play:
		return
	prompt.text = "E  |  " + ("Close door" if player.interact_target.opened else "Open door") if player.interact_target else ""
	if not player.controls_active:
		prompt.text = "Mouse released | Click to resume"
	status.text = "Starting room > Door %s > Enemy %s\n%s  |  %d triangles  |  %d materials  |  %d billboards" % ["opened" if door_used else "waiting", "encountered" if encounter else "unseen", classic.provenance.block, classic.triangle_count, classic.texture_count, billboard_nodes.size()]
	status.text += "\nView: %s  |  %.0f vertical FOV  |  Eye height %.2f m" % [presentation.profile, player.camera.fov, player.camera.position.y]
	if encounter:
		status.text += "\nEnemy has noticed you."
	if player.combat.feedback_time > 0 and player.controls_active:
		prompt.text = player.combat.feedback
	for target in enemies:
		if target.name == "hall_combat_target":
			status.text += "\nHall target: %d / %d HP%s" % [target.health.current, target.health.maximum, " - defeated (R to restart)" if target.health.current == 0 else ""]
	player_status.text = "Health: %d / %d" % [player.health.current, player.health.maximum]
	player_status.modulate = Color(1, 0.45, 0.35) if player.damage_flash > 0 else Color.WHITE
	damage_overlay.color.a = 0.28 * player.damage_flash / 0.3
	if player.is_dead():
		prompt.text = "You have died | R to restart"
		player_status.text += "\nDEAD"
		damage_overlay.color.a = 0.16
	# Status grows when targets/encounters are shown; diagnostics follow its height.
	movement_status.position.y = status.position.y + status.get_minimum_size().y + 12.0
	movement_status.visible = player.show_movement_debug or not player.movement.profile.error.is_empty()
	if movement_status.visible:
		movement_status.text = player.movement_debug_text()
		for target in enemies:
			if target.navigation.enabled:
				movement_status.text += "\nSkeleton: %s | detour %.2f s" % [target.navigation.state, target.navigation.detour_left]

func capture_preview() -> void:
	for i in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/playable_preview.png")



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view"):
		presentation.set_profile("widescreen" if presentation.profile == "dfu_reference" else "dfu_reference")
		get_viewport().set_input_as_handled()
	elif ready_to_play:
		# World rendering uses a separate viewport; keyboard/mouse events must follow it.
		presentation.viewport.push_input(event, true)

func _unhandled_input(event: InputEvent) -> void:
	if not ready_to_play and event.is_action_pressed("reset"):
		get_tree().reload_current_scene()
