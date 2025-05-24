# https://www.youtube.com/watch?v=V79YabQZC1s
# 17:36

extends PanelContainer

class_name Inventory

const slot_scene = preload("res://Core/Inventory/InventorySlot.tscn")

@onready var item_grid: GridContainer = $MarginContainer/ItemGrid

func _ready() -> void:
	var inv_data = preload("res://Core/Inventory/TestInventory.tres")
	populate_item_grid(inv_data.slot_datas)

func populate_item_grid(slot_data_list: Array[InventorySlotData]) -> void:
	for child in item_grid.get_children():
		child.queue_free()
	
	for slot_data in slot_data_list:
		var slot = slot_scene.instantiate()
		item_grid.add_child(slot)
		
		if slot_data:
			slot.set_slot_data(slot_data)
			pass
	pass
