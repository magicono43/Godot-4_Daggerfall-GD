extends RefCounted
## One timed effect, driven by the existing elapsed game clock, including rest.
const MAX_LIGHT_SECONDS := 86400.0
var remaining := 0.0
var shield := preload("res://scripts/shield_effect.gd").new()
var light: OmniLight3D

func setup(camera: Camera3D) -> void:
	light = OmniLight3D.new()
	light.name = "SpellLight"
	light.light_color = Color(0.8, 0.9, 1.0)
	light.light_energy = 1.0
	light.omni_range = 14.0
	light.visible = false
	camera.add_child(light)

func apply(id: String, actor: CharacterBody3D) -> void:
	if id == "heal":
		actor.health.restore(25)
	elif id == "shield":
		shield.cast(5, 120.0)
	elif id == "light":
		remaining = minf(MAX_LIGHT_SECONDS, remaining + 600.0)
		light.visible = true

func advance(seconds: float) -> void:
	shield.advance(seconds)
	remaining = maxf(0.0, remaining - maxf(0.0, seconds))
	light.visible = remaining > 0

func clear() -> void:
	shield.clear()
	remaining = 0
	if is_instance_valid(light):
		light.visible = false

func valid(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= MAX_LIGHT_SECONDS

func restore(value: float) -> void:
	remaining = value
	light.visible = remaining > 0
