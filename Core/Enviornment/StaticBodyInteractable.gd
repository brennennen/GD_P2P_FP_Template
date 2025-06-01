extends StaticBody3D

class_name StaticBodyInteractable


@export var interact_text: String = "Interact"

var interact_callbacks: Array[Callable] = []

var _interactions_enabled: bool = true

func interactions_enabled() -> bool:
	return _interactions_enabled

func interact_local(_player: Player) -> void:
	pass

func interact() -> void:
	pass
