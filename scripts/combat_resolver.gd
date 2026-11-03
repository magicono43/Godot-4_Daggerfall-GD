extends RefCounted
## Pure supported subset of pinned DFU FormulaHelper. Geometry stays with callers.
const Catalog = preload("res://scripts/item_catalog.gd")
const BODY_PARTS := [0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 6]
const REGIONS := ["Head", "Right arm", "Left arm", "Chest", "Hands", "Legs", "Feet"]
# WeaponBasics records 1..6: down, down-left, left, right, down-right, up.
const SWINGS := {1: [-10, 4], 2: [-5, 2], 3: [0, 0], 4: [0, 0], 5: [5, -2], 6: [10, -4]}
var rng := RandomNumberGenerator.new()
var last: Dictionary = {}

func _init() -> void:
	rng.randomize()

func roll(maximum: int) -> int:
	return rng.randi_range(0, maximum - 1)

func divide(value: int, divisor: int) -> int:
	# C# integer division truncates toward zero, including negative differences.
	return int(float(value) / float(divisor))

func chance(attacker: CharacterBody3D, target: CharacterBody3D, skill: int, material: int, swing: int, region: int, critical_roll: int) -> Dictionary:
	var a = attacker.combat_stats
	var d = target.combat_stats
	var stats := divide(a.stat("agility") - d.stat("agility"), 10) + divide(a.stat("luck") - d.stat("luck"), 10)
	var dodge := -divide(d.stat("dodging"), 4)
	var critical := divide(a.stat("critical_strike"), 10) if critical_roll < a.stat("critical_strike") else 0
	var armor: int = d.armor(target, region)
	var adjustment := 40 if d.monster else 0
	var total := skill + material + swing + armor + stats + dodge + critical + adjustment - 50
	return {"chance": clampi(total, 3, 97), "unclamped": total, "skill": skill, "material": material, "swing": swing, "armor": armor, "stats": stats, "dodging": dodge, "critical": critical, "monster": adjustment, "region": region}

func weapon_attack(attacker: CharacterBody3D, target: CharacterBody3D, item: Dictionary, record: int) -> Dictionary:
	var profile := Catalog.weapon_profile(item)
	if profile.is_empty():
		return finish({"outcome": "invalid", "damage": 0})
	var material: int = Catalog.MATERIALS[item.material].rank
	if target.combat_stats.minimum_material > material:
		return finish({"outcome": "ineffective", "damage": 0})
	var region: int = BODY_PARTS[roll(BODY_PARTS.size())]
	var swing: Array = SWINGS.get(record, [0, 0])
	var bonus: int = Catalog.MATERIALS[item.material].modifier
	var result := chance(attacker, target, attacker.combat_stats.stat(profile.skill), bonus * 10, int(swing[0]), region, roll(100))
	result.roll = roll(100)
	result.damage = 0
	result.outcome = "miss"
	if result.roll < result.chance:
		var base: int = int(profile.minimum) + roll(int(profile.maximum) - int(profile.minimum) + 1)
		var damage := base + int(swing[1])
		# Preserve DFU order: skeleton edged penalty/silver before STR/material.
		if target.combat_stats.skeleton:
			if not profile.blunt:
				damage = divide(damage, 2)
			if item.material == "silver":
				damage *= 2
		var strength := int(floor(float(attacker.combat_stats.stat("strength") - 50) / 5.0))
		result.base_damage = base
		result.strength = strength
		result.damage = maxi(0, damage + strength + bonus)
		result.outcome = "hit" if result.damage > 0 else "no_damage"
	return finish(result)

func enemy_attack(attacker: CharacterBody3D, target: CharacterBody3D) -> Dictionary:
	var region: int = BODY_PARTS[roll(BODY_PARTS.size())]
	var result := {"outcome": "miss", "damage": 0, "region": region, "reflex_skipped": true}
	var total := 0
	var components: Array[Dictionary] = []
	# FormulaHelper resolves each nonzero monster slot once at the single event.
	for damage_range in attacker.combat_stats.attack_ranges:
		if roll(100) >= 50 - 10 * (target.combat_stats.stat("reflexes") - 2):
			components.append({"damage": 0, "reflex_skipped": true})
			continue
		result = chance(attacker, target, attacker.combat_stats.stat("hand_to_hand"), 0, 0, region, roll(100))
		result.roll = roll(100)
		result.damage = 0
		if result.roll < result.chance:
			result.damage = damage_range.x + roll(damage_range.y - damage_range.x + 1)
		total += int(result.damage)
		components.append(result.duplicate())
	result.damage = total
	result.outcome = "hit" if total > 0 else "miss"
	result.components = components
	return finish(result)
func finish(result: Dictionary) -> Dictionary:
	last = result
	return result

func diagnostic() -> String:
	if last.is_empty():
		return "Last strike: none"
	return "Last strike: %s | %s | chance %d%% roll %d | damage %d\nHit mods: skill %d material %d swing %d armor %d stats %d dodge %d crit %d monster %d -50" % [last.outcome, REGIONS[int(last.get("region", 0))], last.get("chance", 0), last.get("roll", -1), last.damage, last.get("skill", 0), last.get("material", 0), last.get("swing", 0), last.get("armor", 0), last.get("stats", 0), last.get("dodging", 0), last.get("critical", 0), last.get("monster", 0)]

