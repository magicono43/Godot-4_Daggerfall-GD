extends RefCounted
## Fixed authored spells using pinned DFU effect coefficients; no spellmaker/level scaling.
const SPELLS := {
	"shield": {"name":"Shield", "school":"alteration", "amount":5, "coefficient":80, "rounds":2, "duration_coefficient":28, "description":"Absorb 5 damage for 2 game minutes. Recast adds duration and tops up only to the original capacity."},
	"heal": {"name":"Heal", "school":"restoration", "amount":25, "coefficient":20, "description":"Restore 25 health, including when already healthy."},
	"light": {"name":"Light", "school":"illusion", "rounds":10, "coefficient":8, "description":"Magical light for 10 game minutes. Recasts add duration."},
	"fire_bolt": {"name":"Fire Bolt", "school":"destruction", "amount":10, "coefficient":20, "element":"fire", "target":"ranged", "description":"10 fire damage to one enemy struck. LMB releases; Esc cancels. No saving throw in this test."},
	"shock_bolt": {"name":"Shock Bolt", "school":"destruction", "amount":10, "coefficient":20, "element":"shock", "target":"ranged", "description":"10 shock damage to one enemy struck. LMB releases; Esc cancels. No saving throw in this test."},
	"burning_touch": {"name":"Burning Touch", "school":"destruction", "amount":10, "coefficient":20, "element":"fire", "target":"touch", "description":"10 fire damage to a nearby enemy. LMB releases on a valid target; Esc cancels."}
}

static func valid_known(value: Variant) -> bool:
	if not value is Array or value.size() > SPELLS.size():
		return false
	var seen := {}
	for id in value:
		if not id is String or not SPELLS.has(id) or seen.has(id):
			return false
		seen[id] = true
	return true

static func cost(id: String, character: RefCounted) -> int:
	if not SPELLS.has(id):
		return 0
	var spell: Dictionary = SPELLS[id]
	var component := int(spell.coefficient) * int(spell.get("amount", spell.get("rounds", 0)))
	component += int(spell.get("duration_coefficient", 0)) * int(spell.get("rounds", 0))
	var points := int(component * (110 - int(character.stat(spell.school))) / 400)
	if spell.get("target", "self") == "ranged":
		points = int(points * 1.5)
	return maxi(5, points)
