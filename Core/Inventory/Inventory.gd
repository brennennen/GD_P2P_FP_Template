# https://www.youtube.com/watch?v=V79YabQZC1s
# 27:00
# TODO: rip out and ignore the inventory interface stuff


extends PanelContainer

class_name Inventory

const slot_scene = preload("res://Core/Inventory/InventorySlot.tscn")

@onready var item_grid: GridContainer = $MarginContainer/ItemGrid

#func _ready() -> void:
	#var inv_data = preload("res://Core/Inventory/TestInventory.tres")
	#populate_item_grid(inv_data.slot_datas)

#func populate_item_grid(slot_data_list: Array[InventorySlotData]) -> void:
func populate_item_grid(inventory_data: InventoryData) -> void:
	for child in item_grid.get_children():
		child.queue_free()
	
	for slot_data in inventory_data.slot_datas:
		var slot = slot_scene.instantiate()
		slot.inventory = self
		item_grid.add_child(slot)
		
		if slot_data:
			slot.set_slot_data(slot_data)
			pass
	pass

func set_inventory_data(inventory_data: InventoryData) -> void:
	populate_item_grid(inventory_data)
	pass

func slot_clicked(slot_index: int, event_index: int) -> void:
	Logger.info("inventory.slot_clicked: slot: %d" % [ slot_index ])
	pass
