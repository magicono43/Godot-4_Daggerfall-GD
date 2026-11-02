extends RefCounted
## Prototype definitions; these are not decoded classic item templates.
const DEFINITIONS := {
	"dagger": {"name": "Dagger", "stackable": false, "weapon": "dagger", "description": "A short blade for close combat."},
	"gold": {"name": "Gold pieces", "description": "Prototype currency items; spending is not implemented.", "stackable": true},
	"bone": {"name": "Bone", "description": "A bone from the skeleton. No use action yet.", "stackable": true},
}

static func valid(id: String) -> bool:
	return DEFINITIONS.has(id)

static func label(id: String) -> String:
	return DEFINITIONS.get(id, {}).get("name", id)
