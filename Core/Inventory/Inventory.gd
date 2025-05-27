# https://www.youtube.com/watch?v=V79YabQZC1s
# 27:00
# TODO: rip out and ignore the inventory interface stuff


extends PanelContainer

class_name Inventory

const slot_scene = preload("res://Core/Inventory/InventorySlot.tscn")

@onready var item_grid: GridContainer = $MarginContainer/ItemGrid

var player_interface: PlayerInventoryInterface

var inventory_data: InventoryData
var grabbed_slot_data: InventorySlotData

#func _ready() -> void:
	#var inv_data = preload("res://Core/Inventory/TestInventory.tres")
	#populate_item_grid(inv_data.slot_datas)

#func populate_item_grid(slot_data_list: Array[InventorySlotData]) -> void:
func populate_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()

	for slot_data in inventory_data.slot_datas:
		var slot = slot_scene.instantiate()
		#slot.inventory = self
		item_grid.add_child(slot)

		if slot_data:
			slot.set_slot_data(slot_data)
			pass
	pass

func set_inventory_data(new_inventory_data: InventoryData) -> void:
	inventory_data = new_inventory_data
	populate_item_grid()

func slot_clicked(slot_index: int, event_index: int) -> void:
	#Logger.info("inventory.slot_clicked: slot: %d" % [ slot_index ])
	if player_interface:
		player_interface.slot_clicked(slot_index, event_index)
	#if grabbed_slot_data == null and event_index == MOUSE_BUTTON_LEFT:
		#grabbed_slot_data = inventory_data.grab_slot_data(slot_index)
		#Logger.info("grabbed_slot_data: %s" % [grabbed_slot_data])
		#pass
	pass
