extends RefCounted
## Scene-local identity. Transfers move instances rather than cloning them.
const Catalog = preload("res://scripts/item_catalog.gd")
static var next_uid := 1
var items: Array[Dictionary] = []
var equipped_uid := 0
signal changed

func add_item(definition: String, quantity: int = 1) -> int:
	if not Catalog.valid(definition) or quantity < 1:
		return 0
	if quantity != 1 and not Catalog.DEFINITIONS[definition].stackable:
		return 0
	var uid := next_uid
	next_uid += 1
	items.append({"uid": uid, "definition": definition, "quantity": quantity})
	changed.emit()
	return uid

func find(uid: int) -> Dictionary:
	for item in items:
		if item.uid == uid:
			return item
	return {}

func transfer_to(destination: RefCounted, uid: int) -> bool:
	var item := find(uid)
	if destination == self or item.is_empty() or uid == equipped_uid or not destination.find(uid).is_empty():
		return false
	items.erase(item)
	destination.items.append(item)
	changed.emit()
	destination.changed.emit()
	return true

func equip(uid: int) -> bool:
	var item := find(uid)
	if item.is_empty() or Catalog.DEFINITIONS[item.definition].get("weapon", "") != "dagger":
		return false
	equipped_uid = uid
	changed.emit()
	return true

func has_dagger() -> bool:
	var item := find(equipped_uid)
	return not item.is_empty() and item.definition == "dagger"
