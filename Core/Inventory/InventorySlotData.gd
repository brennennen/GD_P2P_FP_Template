extends Resource
class_name InventorySlotData

const max_stack_size: int = 99

@export var inventory_item_data: InventoryItemData
@export_range(1, max_stack_size) var quantity: int = 1: set = set_quantity

func set_quantity(value: int) -> void:
	quantity = value
	if quantity > 1 and not inventory_item_data.stackable:
		quantity = 1
		Logger.error("%s is not stackable! setting quantity to 1" % [ inventory_item_data.name ])
