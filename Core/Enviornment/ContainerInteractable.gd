extends StaticBodyInteractable

class_name ContainerInteractable

@export var inventory_data: InventoryData

var opened: bool = false

func interact_local(player: Player) -> void:
	if opened:
		player.inventory_interface.clear_external_inventory_container()
		opened = false
	else:
		player.inventory_interface.set_external_inventory_container(self)
		opened = true

func interact() -> void:

	Log.info("ContainerInteractable.interact()")
	pass
