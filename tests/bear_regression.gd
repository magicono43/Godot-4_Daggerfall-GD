extends "res://scripts/main.gd"
## Independent retained species/modal/equipment regression; never normal play.
func _ready() -> void:
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/sections/skeleton_regression.json"))
	var setup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/bear_setup.json"))
	for key in setup:
		definition.prototype[key] = setup[key]
	definition.name = "Retained bear regression over independent skeleton world"
	DirAccess.make_dir_recursive_absolute("res://tests/output")
	section_override_path = "res://tests/output/bear_regression_section.json"
	FileAccess.open(section_override_path, FileAccess.WRITE).store_string(JSON.stringify(definition))
	super._ready()
