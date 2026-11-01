extends RefCounted
## Prototype definitions; these are not decoded classic item templates.
const DEFINITIONS := {
	"dagger": {"name": "Dagger", "stackable": false, "weapon": "dagger"},
	"gold": {"name": "Gold pieces", "stackable": true},
	"bone": {"name": "Bone", "stackable": true},
}

static func valid(id: String) -> bool:
	return DEFINITIONS.has(id)

static func label(id: String) -> String:
	return DEFINITIONS.get(id, {}).get("name", id)
