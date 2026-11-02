extends RefCounted
## Shared damage state; combat policy and presentation stay with their owners.
signal damaged(amount: int)
signal died
var maximum := 30
var current := 30

func apply_damage(amount: int) -> bool:
	if amount <= 0 or current <= 0:
		return false
	var applied := mini(amount, current)
	current -= applied
	damaged.emit(applied)
	if current == 0:
		died.emit()
	return true

func restore(amount: int) -> int:
	# Healing never revives a dead actor or exceeds the current maximum.
	if amount <= 0 or current <= 0 or current >= maximum:
		return 0
	var restored := mini(amount, maximum - current)
	current += restored
	return restored
