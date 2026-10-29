extends Node3D
const Data = preload("res://scripts/classic_data.gd")
const Player = preload("res://scripts/player.gd")
const Door = preload("res://scripts/door.gd")
const Enemy = preload("res://scripts/enemy.gd")
var classic := Data.new()
var player: CharacterBody3D
var door: AnimatableBody3D
var enemy: CharacterBody3D
var prompt: Label
var status: Label
var encounter := false
var door_used := false
var ready_to_play := false

func _ready() -> void:
	configure_input()
	var config := ConfigFile.new()
	if config.load("res://data_source.cfg") == OK:
		classic.arena_path = config.get_value("classic", "arena2", classic.arena_path)
	create_environment()
	create_hud()
	if not classic.load_slice():
		status.text = "ORIGINAL DATA UNAVAILABLE\n" + classic.error + "\nSet arena2 in data_source.cfg, then press R to retry."
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	for item in classic.objects:
		var mesh := classic.build_mesh(item.model)
		var body: PhysicsBody3D
		if item.offset == 11579:
			body = AnimatableBody3D.new()
			body.set_script(Door)
			body.sync_to_physics = false
			door = body
		else:
			body = StaticBody3D.new()
		body.name = "Classic_%s_%d" % [item.model, item.offset]
		add_child(body)
		body.transform = item.transform
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		body.add_child(instance)
		var collision := CollisionShape3D.new()
		var trimesh := mesh.create_trimesh_shape()
		trimesh.backface_collision = true
		collision.shape = trimesh
		body.add_child(collision)
		if body == door:
			door.closed_basis = door.basis
	add_boundary(Vector3(1027, 63, -640) * Data.SCALE - Data.ORIGIN, PI / 2)
	player = CharacterBody3D.new()
	player.set_script(Player)
	player.name = "Player"
	add_child(player)
	player.spawn = classic.provenance.start + Vector3.UP * 0.1
	player.position = player.spawn
	player.look_at(Vector3(-1, player.position.y, 20))
	door.player = player
	door.used.connect(func(): door_used = true)
	enemy = CharacterBody3D.new()
	enemy.set_script(Enemy)
	enemy.name = "PlaceholderEnemy"
	enemy.player = player
	enemy.position = Vector3(1120, 4, -768) * Data.SCALE - Data.ORIGIN
	add_child(enemy)
	enemy.encountered.connect(func(): encounter = true)
	add_light(Vector3(0, 3.5, 3), 1.8, 18)
	add_light(Vector3(-1, 2.1, 16), 1.2, 12)
	add_light(Vector3(10, 2, 22.6), 1.0, 12)
	ready_to_play = true
	print("CLASSIC_SLICE ", classic.provenance, " triangles=", classic.triangle_count, " textures=", classic.texture_count)
	if "--capture" in OS.get_cmdline_user_args():
		capture_preview()

func configure_input() -> void:
	var keys := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E, "release_mouse": KEY_ESCAPE, "reset": KEY_R}
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
	add_child(world)

func add_light(pos: Vector3, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_energy = energy
	light.omni_range = radius
	light.light_color = Color(1, 0.75, 0.46)
	add_child(light)

func add_boundary(pos: Vector3, yaw: float) -> void:
	var body := StaticBody3D.new()
	body.name = "GreyboxSliceBoundary"
	body.add_to_group("slice_boundaries")
	body.position = pos
	body.rotation.y = yaw
	add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.2, 3.5, 0.35)
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
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
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
	controls.text = "WASD  Move    Mouse  Look    Shift  Run    Space  Jump    E  Door    Esc  Mouse    R  Restart"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(29, -42)
	controls.add_theme_font_size_override("font_size", 15)
	root.add_child(controls)

func _process(_delta: float) -> void:
	if not ready_to_play:
		return
	prompt.text = "E  |  " + ("Close door" if door.opened else "Open door") if player.interact_target else ""
	if not player.controls_active:
		prompt.text = "Mouse released | Click to resume"
	status.text = "Starting room > Door %s > Enemy %s\nS0000999.RDB  |  %d original triangles  |  %d textures" % ["opened" if door_used else "waiting", "encountered" if encounter else "unseen", classic.triangle_count, classic.texture_count]
	if encounter:
		status.text += "\nPlaceholder enemy has noticed you. Combat is outside this experiment."

func capture_preview() -> void:
	for i in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/playable_preview.png")



func _unhandled_input(event: InputEvent) -> void:
	if not ready_to_play and event.is_action_pressed("reset"):
		get_tree().reload_current_scene()
