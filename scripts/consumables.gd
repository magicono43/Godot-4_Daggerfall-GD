extends RefCounted
## Prototype item effects; independent of UI, archive decoding and the player motor.
const Catalog = preload("res://scripts/item_catalog.gd")

static func use_item(inventory: RefCounted, health: RefCounted, uid: int) -> Dictionary:
	var item: Dictionary = inventory.find(uid)
	if item.is_empty():
		return {"healed": 0, "message": "That item is no longer in your inventory."}
	var amount: int = Catalog.DEFINITIONS[item.definition].get("heal_amount", 0)
	if amount <= 0:
		return {"healed": 0, "message": "This item cannot be used."}
	if health.current <= 0:
		return {"healed": 0, "message": "You cannot use a potion while dead."}
	if health.current >= health.maximum:
		return {"healed": 0, "message": "Health is already full. Potion kept."}
	if not inventory.consume_one(uid):
		return {"healed": 0, "message": "That item cannot be consumed."}
	var healed: int = health.restore(amount)
	return {"healed": healed, "message": "Restored %d health." % healed}
