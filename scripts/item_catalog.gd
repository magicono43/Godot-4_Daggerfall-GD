extends RefCounted
## Prototype definitions; these are not decoded classic item templates.
const DEFINITIONS := {
	"dagger": {"name": "Dagger", "stackable": false, "weapon": "dagger", "icon": [234, 5], "description": "A short blade for close combat."},
	"gold": {"name": "Gold pieces", "icon": [216, 1], "description": "Prototype currency items; spending is not implemented.", "stackable": true},
	"twigs": {"name": "Twigs", "icon": [254, 9], "description": "An alchemy ingredient. Brewing is not available yet.", "stackable": true},
	"healing_potion": {"name": "Healing potion", "icon": [205, 15], "description": "Restores up to 25 health. Kept if health is full.", "stackable": true, "heal_amount": 25},
}

static func valid(id: String) -> bool:
	return DEFINITIONS.has(id)

static func label(id: String) -> String:
	return DEFINITIONS.get(id, {}).get("name", id)
