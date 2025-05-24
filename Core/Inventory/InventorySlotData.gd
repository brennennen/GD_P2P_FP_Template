extends Resource
class_name InventorySlotData

const max_stack_size: int = 99

@export var inventory_item_data: InventoryItemData
@export_range(1, max_stack_size) var quantity: int = 1
