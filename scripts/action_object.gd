extends AnimatableBody3D
## E target for a selected source trigger; movement belongs to the scene controller.
var controller: Node
var action_id := ""

func interact() -> void:
	controller.activate(action_id)

func interaction_prompt() -> String:
	return controller.prompt(action_id)
