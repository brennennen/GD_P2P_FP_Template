# https://www.youtube.com/watch?v=V79YabQZC1s
# 48:50
# TODO: rip out and ignore the inventory interface stuff

extends PanelContainer

class_name Inventory

const slot_scene = preload("res://Core/Inventory/InventorySlot.tscn")

@onready var item_grid: GridContainer = $MarginContainer/ItemGrid

var player_interface: PlayerInventoryInterface

var inventory_data: InventoryData
var grabbed_slot_data: InventorySlotData

func populate_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	for slot_data in inventory_data.slot_datas:
		var slot = slot_scene.instantiate()
		slot.inventory = self
		item_grid.add_child(slot)
		if slot_data:
			slot.set_slot_data(slot_data)

func set_inventory_data(new_inventory_data: InventoryData) -> void:
	inventory_data = new_inventory_data
	populate_item_grid()

func clear_inventory_data() -> void:
	inventory_data = null

func slot_clicked(slot_index: int, event_index: int) -> void:
	Log.debug("inventory.slot_clicked: slot: %d" % [ slot_index ])
	if player_interface:
		player_interface.slot_clicked(self, slot_index, event_index)
