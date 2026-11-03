extends RefCounted
## Prototype definitions; these are not decoded classic item templates.
const ARMOR_SLOTS := ["head", "right_arm", "left_arm", "chest", "hands", "legs", "feet"]
const SLOT_NAMES := {"head":"Head", "right_arm":"Right arm", "left_arm":"Left arm", "chest":"Chest", "hands":"Hands", "legs":"Legs", "feet":"Feet"}
const DEFINITIONS := {
	"dagger": {"name": "Dagger", "stackable": false, "weapon": "dagger", "icon": [234, 5], "description": "A short blade for close combat."},
	"gold": {"name": "Gold pieces", "icon": [216, 1], "description": "Prototype currency items; spending is not implemented.", "stackable": true},
	"twigs": {"name": "Twigs", "icon": [254, 9], "description": "An alchemy ingredient. Brewing is not available yet.", "stackable": true},
	"healing_potion": {"name": "Healing potion", "icon": [205, 15], "description": "Restores up to 25 health. Kept if health is full.", "stackable": true, "heal_amount": 25},
	"mace": {"name": "Mace", "stackable": false, "weapon": "mace", "icon": [234, 14], "description": "A blunt weapon; skeletons resist edged weapons."},
	"steel_cuirass": {"name": "Steel cuirass", "stackable": false, "slot": "chest", "protection": 9, "icon": [249, 4], "description": "Protects the chest. Protection 9: -45 percentage points to incoming hit chance for chest attacks, before chance limits. Other regions remain unprotected."},
	"steel_helm": {"name": "Steel helm", "stackable": false, "slot": "head", "protection": 9, "icon": [249, 27], "description": "Steel armor protecting only the head region. Protection 9 (higher is better)."},
	"steel_right_pauldron": {"name": "Steel right pauldron", "stackable": false, "slot": "right_arm", "protection": 9, "icon": [249, 23], "description": "Steel armor protecting only the right arm region. Protection 9 (higher is better)."},
	"steel_left_pauldron": {"name": "Steel left pauldron", "stackable": false, "slot": "left_arm", "protection": 9, "icon": [249, 18], "description": "Steel armor protecting only the left arm region. Protection 9 (higher is better)."},
	"steel_gauntlets": {"name": "Steel gauntlets", "stackable": false, "slot": "hands", "protection": 9, "icon": [249, 9], "description": "Steel armor protecting only the hands region. Protection 9 (higher is better)."},
	"steel_greaves": {"name": "Steel greaves", "stackable": false, "slot": "legs", "protection": 9, "icon": [249, 12], "description": "Steel armor protecting only the legs region. Protection 9 (higher is better)."},
	"steel_boots": {"name": "Steel boots", "stackable": false, "slot": "feet", "protection": 9, "icon": [249, 1], "description": "Steel armor protecting only the feet region. Protection 9 (higher is better)."},
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
	return not weapon_profile(item).is_empty() or not armor_slot(item).is_empty()

static func armor_slot(item: Dictionary) -> String:
	var slot: String = DEFINITIONS.get(item.get("definition", ""), {}).get("slot", "")
	return slot if slot in ARMOR_SLOTS else ""

static func armor_protection(item: Dictionary) -> int:
	return int(DEFINITIONS.get(item.get("definition", ""), {}).get("protection", 0)) if not armor_slot(item).is_empty() else 0

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

