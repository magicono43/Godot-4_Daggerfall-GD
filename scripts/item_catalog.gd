extends RefCounted
## Prototype definitions; these are not decoded classic item templates.
const DEFINITIONS := {
	"dagger": {"name": "Dagger", "stackable": false, "weapon": "dagger", "icon": [234, 5], "description": "A short blade for close combat."},
	"gold": {"name": "Gold pieces", "icon": [216, 1], "description": "Prototype currency items; spending is not implemented.", "stackable": true},
	"twigs": {"name": "Twigs", "icon": [254, 9], "description": "An alchemy ingredient. Brewing is not available yet.", "stackable": true},
	"healing_potion": {"name": "Healing potion", "icon": [205, 15], "description": "Restores up to 25 health. Kept if health is full.", "stackable": true, "heal_amount": 25},
	"mace": {"name": "Mace", "stackable": false, "weapon": "mace", "icon": [234, 14], "description": "A blunt weapon; skeletons resist edged weapons."},
	"steel_cuirass": {"name": "Steel cuirass", "stackable": false, "slot": "chest", "icon": [249, 4], "description": "Protects the chest. Protection 9: -45 percentage points to incoming hit chance for chest attacks, before chance limits. Other regions remain unprotected."},
}

const WEAPONS := {
	"dagger": {"minimum": 1, "maximum": 6, "skill": "short_blade", "blunt": false, "ready_offset": 0.04, "draw": "draw", "miss": "miss"},
	"mace": {"minimum": 1, "maximum": 12, "skill": "blunt_weapon", "blunt": true, "ready_offset": 0.0, "draw": "draw_mace", "miss": "miss_mace"},
}
const MATERIALS := {
	"iron": {"rank": 0, "modifier": -1}, "steel": {"rank": 1, "modifier": 0},
	"silver": {"rank": 2, "modifier": 0}, "elven": {"rank": 3, "modifier": 1},
	"dwarven": {"rank": 4, "modifier": 2}, "mithril": {"rank": 5, "modifier": 3},
	"adamantium": {"rank": 6, "modifier": 3}, "ebony": {"rank": 7, "modifier": 4},
	"orcish": {"rank": 8, "modifier": 5}, "daedric": {"rank": 9, "modifier": 6},
}

static func weapon_profile(item: Dictionary) -> Dictionary:
	return WEAPONS.get(DEFINITIONS.get(item.get("definition", ""), {}).get("weapon", ""), {})

static func equippable(item: Dictionary) -> bool:
	return not weapon_profile(item).is_empty() or DEFINITIONS.get(item.get("definition", ""), {}).get("slot", "") == "chest"

static func valid_material(item: Dictionary) -> bool:
	return weapon_profile(item).is_empty() or MATERIALS.has(item.get("material", ""))

static func description(item: Dictionary) -> String:
	var text: String = DEFINITIONS[item.definition].description
	var profile := weapon_profile(item)
	if not profile.is_empty():
		text += "\nMaterial: %s | Base damage %d-%d | Skill: %s. STR, material, swing and target modify damage." % [String(item.get("material", "steel")).capitalize(), profile.minimum, profile.maximum, String(profile.skill).replace("_", " ").capitalize()]
	return text

static func valid(id: String) -> bool:
	return DEFINITIONS.has(id)

static func label(id: String) -> String:
	return DEFINITIONS.get(id, {}).get("name", id)

