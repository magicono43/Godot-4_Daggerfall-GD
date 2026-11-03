extends "res://scripts/combat_resolver.gd"
## Legacy geometry/timing suites inject fixed outcomes, never change production RNG.
func weapon_attack(_attacker: CharacterBody3D, _target: CharacterBody3D, item: Dictionary, _record: int) -> Dictionary:
	return finish({"outcome": "hit", "damage": 15 if item.definition == "mace" else 10})

func enemy_attack(_attacker: CharacterBody3D, _target: CharacterBody3D) -> Dictionary:
	return finish({"outcome": "hit", "damage": 10})
