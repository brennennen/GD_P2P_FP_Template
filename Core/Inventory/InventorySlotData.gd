extends Resource
class_name InventorySlotData

const max_stack_size: int = 99

@export var inventory_item_data: InventoryItemData
@export_range(1, max_stack_size) var quantity: int = 1: set = set_quantity

func set_quantity(value: int) -> void:
	quantity = value
	if quantity > 1 and not inventory_item_data.stackable:
		quantity = 1
		Log.error("%s is not stackable! setting quantity to 1" % [ inventory_item_data.name ])

func can_merge(other_slot_data: InventorySlotData) -> bool:
	if inventory_item_data == other_slot_data.inventory_item_data \
			and inventory_item_data.stackable \
			and quantity + other_slot_data.quantity <= max_stack_size:
		return true
	return false

func merge(other_slot_data: InventorySlotData) -> void:
	quantity += other_slot_data.quantity

