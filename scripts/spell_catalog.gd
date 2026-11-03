extends RefCounted
## Fixed authored self spells using pinned DFU effect coefficients; no spellmaker/level scaling.
const SPELLS := {
	"heal": {"name":"Heal", "school":"restoration", "amount":25, "coefficient":20, "description":"Restore 25 health, including when already healthy."},
	"light": {"name":"Light", "school":"illusion", "rounds":10, "coefficient":8, "description":"Magical light for 10 game minutes. Recasts add duration."}
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
	return maxi(5, int(component * (110 - int(character.stat(spell.school))) / 400))
