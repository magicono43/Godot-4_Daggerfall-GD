extends RefCounted
## Scene-local identity; compatible stack merges retain the destination UID.
const Catalog = preload("res://scripts/item_catalog.gd")
static var next_uid := 1
var items: Array[Dictionary] = []
var equipped_uid := 0
var armor_uid := 0
signal changed

func add_item(definition: String, quantity: int = 1) -> int:
	if not Catalog.valid(definition) or quantity < 1:
		return 0
	if quantity != 1 and not Catalog.DEFINITIONS[definition].stackable:
		return 0
	var uid := next_uid
	next_uid += 1
	var item := {"uid": uid, "definition": definition, "quantity": quantity}
	if not Catalog.weapon_profile(item).is_empty():
		item["material"] = "steel"
	return accept(item)

func find(uid: int) -> Dictionary:
	for item in items:
		if item.uid == uid:
			return item
	return {}

func compatible_stack(item: Dictionary) -> Dictionary:
	if not Catalog.DEFINITIONS[item.definition].stackable:
		return {}
	var identity := item.duplicate(true)
	identity.erase("uid")
	identity.erase("quantity")
	for candidate in items:
		if is_equipped(int(candidate.uid)):
			continue
		var other := candidate.duplicate(true)
		other.erase("uid")
		other.erase("quantity")
		if identity == other:
			return candidate
	return {}

func accept(item: Dictionary) -> int:
	var target := compatible_stack(item)
	if target.is_empty():
		items.append(item)
		target = item
	else:
		target.quantity += int(item.quantity)
	changed.emit()
	return int(target.uid)

func move_to(destination: RefCounted, uid: int) -> int:
	# Return the surviving destination UID so the UI can follow merged selection.
	var item := find(uid)
	if destination == self or item.is_empty() or is_equipped(uid) or not destination.find(uid).is_empty():
		return 0
	items.erase(item)
	var target_uid: int = destination.accept(item)
	changed.emit()
	return target_uid

func transfer_to(destination: RefCounted, uid: int) -> bool:
	return move_to(destination, uid) != 0

func equip(uid: int) -> bool:
	var item := find(uid)
	if item.is_empty() or not Catalog.equippable(item):
		return false
	if Catalog.DEFINITIONS[item.definition].get("slot", "") == "chest":
		armor_uid = uid
	else:
		equipped_uid = uid
	changed.emit()
	return true

func has_dagger() -> bool:
	var item := find(equipped_uid)
	return not item.is_empty() and item.definition == "dagger"

func unequip(uid: int = 0) -> void:
	if uid != 0 and uid == armor_uid:
		armor_uid = 0
	elif uid == 0 or uid == equipped_uid:
		equipped_uid = 0
	changed.emit()

func is_equipped(uid: int) -> bool:
	return uid != 0 and uid in [equipped_uid, armor_uid]

func consume_one(uid: int) -> bool:
	var item := find(uid)
	if item.is_empty() or is_equipped(uid) or int(item.quantity) < 1:
		return false
	item.quantity -= 1
	if item.quantity == 0:
		items.erase(item)
	changed.emit()
	return true

func equipped_weapon() -> String:
	var item := find(equipped_uid)
	if item.is_empty():
		return ""
	var key: String = Catalog.DEFINITIONS[item.definition].get("weapon", "")
	return key if Catalog.WEAPONS.has(key) else ""

func has_weapon() -> bool:
	return not equipped_weapon().is_empty()
