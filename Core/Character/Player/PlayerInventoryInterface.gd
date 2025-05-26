extends Control

class_name PlayerInventoryInterface

@onready var player_inventory: Inventory = $PlayerInventory
@onready var grabbed_slot: InventorySlot = $GrabbedSlot

var grabbed_slot_data: InventorySlotData


func set_player_inventory_data(inventory_data: InventoryData) -> void:
	player_inventory.set_inventory_data(inventory_data)
	pass

func update_grabbed_slot() -> void:
	#if grabbed_slot_data
	pass

func slot_clicked(slot_index: int, event_index: int) -> void:
	Logger.info("inventory.slot_clicked: slot: %d" % [ slot_index ])
	if grabbed_slot_data == null and event_index == MOUSE_BUTTON_LEFT:
		grabbed_slot_data = player_inventory.inventory_data.grab_slot_data(slot_index)
		Logger.info("grabbed_slot_data: %s" % [grabbed_slot_data])
		pass
	
	pass
