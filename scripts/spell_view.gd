extends Control
## Original magic-element casting hands, mirrored as in FPSSpellCasting.cs.
var actor: CharacterBody3D
var left: TextureRect
var right: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for flipped in [false, true]:
		var hand := TextureRect.new()
		hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hand.flip_h = flipped
		add_child(hand)
		if flipped: right = hand
		else: left = hand

func _process(_delta: float) -> void:
	visible = actor.casting.active() and not actor.modal_open and not actor.is_dead()
	if not visible or actor.spell_payload.is_empty():
		return
	var index: int = actor.casting.SEQUENCE[mini(6, int(actor.casting.elapsed / actor.casting.FRAME_SECONDS))]
	var bank: Array = actor.spell_payloads.get(actor.casting.element, actor.spell_payload)
	var frame: Dictionary = bank[index]
	var screen := get_viewport().get_visible_rect().size
	var dimensions := Vector2(frame.width, frame.height) * screen / Vector2(300, 200)
	var inset := screen.x * 0.134 if index in [0, 5] or (actor.casting.element == "fire" and index == 4) else 0.0
	for hand in [left, right]:
		hand.texture = frame.texture
		hand.size = dimensions
		hand.position.y = screen.y - dimensions.y
	left.position.x = inset
	right.position.x = screen.x - inset - dimensions.x
