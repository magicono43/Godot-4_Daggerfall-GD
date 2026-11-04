extends SceneTree

func _initialize() -> void:
	var data := preload("res://scripts/classic_data.gd").new()
	var success := data.load_slice()
	print("DUNGEON_LOAD ", success, " error=", data.error, " objects=", data.objects.size(), " billboards=", data.billboards.size(), " fixed_enemies=", data.fixed_enemies.size())
	if success:
		var kinds := {}
		for entry in data.fixed_enemies:
			kinds[entry.visual] = kinds.get(entry.visual, 0) + 1
		print("FIXED_ENEMY_TYPES ", kinds)
	quit(0 if success else 1)
