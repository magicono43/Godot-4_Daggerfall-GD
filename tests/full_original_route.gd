extends "res://tests/expansion.gd"

func _initialize() -> void:
	entry_scene = "res://main.tscn"
	capture_prefix = "full_"
	results_path = "res://tests/full_original_route_results.txt"
	call_deferred("run")
