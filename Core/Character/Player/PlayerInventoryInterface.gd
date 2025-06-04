extends Control

class_name PlayerInventoryInterface

@onready var player_inventory: Inventory = $PlayerInventory
@onready var external_inventory: Inventory = $ExternalInventory
@onready var grabbed_slot: InventorySlot = $GrabbedSlot

var grabbed_slot_data_last_index: int
var grabbed_slot_data: InventorySlotData

var external_inventory_container: ContainerInteractable

func _ready() -> void:
	grabbed_slot.hide()
	external_inventory.hide()
	player_inventory.player_interface = self
	external_inventory.player_interface = self

func _physics_process(_delta: float) -> void:
	if grabbed_slot.visible:
		grabbed_slot.global_position = get_global_mouse_position() + Vector2(5.0, 5.0)

func toggle_inventory_ui():
	Log.info("toggle_inventory_ui")
	if grabbed_slot_data:
		Log.info("toggle_inventory_ui: %s - %d" % [str(grabbed_slot_data), grabbed_slot_data_last_index])
		# TODO: handle grabbed item when the inventory is toggled off
		#grabbed_slot_data = null
		player_inventory.populate_item_grid()
		update_grabbed_slot()

func set_player_inventory_data(inventory_data: InventoryData) -> void:
	player_inventory.set_inventory_data(inventory_data)

func slot_clicked(inventory: Inventory, slot_index: int, event_index: int) -> void:
	Log.info("PlayerInventoryInterface.slot_clicked: slot: %d" % [ slot_index ])
	if event_index == MOUSE_BUTTON_LEFT:
		if grabbed_slot_data:
			drop_or_swap_grabbed_slot(inventory, slot_index)
		else:
			grab_slot_data(inventory, slot_index)
	if event_index == MOUSE_BUTTON_RIGHT:
		if grabbed_slot_data:
			drop_single(inventory, slot_index)
		else:
			# TODO: consume item?
			pass

func grab_slot_data(inventory: Inventory, slot_index: int):
	if slot_index < inventory.inventory_data.slot_datas.size():
		grabbed_slot_data = inventory.inventory_data.slot_datas[slot_index]
		grabbed_slot_data_last_index = slot_index
		inventory.inventory_data.slot_datas[slot_index] = null

	inventory.populate_item_grid()
	Log.info("grab_slot_data: %s" % [grabbed_slot_data])
	update_grabbed_slot()

func drop_or_swap_grabbed_slot(inventory: Inventory, slot_index: int):
	# If the slot is empty, just drop the grabbed item into it.
	if inventory.inventory_data.slot_datas[slot_index] == null:
		inventory.inventory_data.slot_datas[slot_index] = grabbed_slot_data
		grabbed_slot_data = null
	# If the slot is the same type as the grabbed slot, try to merge, if can't then swap
	elif inventory.inventory_data.slot_datas[slot_index].inventory_item_data == grabbed_slot_data.inventory_item_data:
		if grabbed_slot_data.quantity + inventory.inventory_data.slot_datas[slot_index].quantity <= inventory.inventory_data.slot_datas[slot_index].max_stack_size:
			inventory.inventory_data.slot_datas[slot_index].quantity += grabbed_slot_data.quantity
			grabbed_slot_data = null
		else:
			var temp: InventorySlotData = inventory.inventory_data.slot_datas[slot_index]
			inventory.inventory_data.slot_datas[slot_index] = grabbed_slot_data
			grabbed_slot_data = temp
	# If the slot is a different type, then swap
	else:
		var temp: InventorySlotData = inventory.inventory_data.slot_datas[slot_index]
		inventory.inventory_data.slot_datas[slot_index] = grabbed_slot_data
		grabbed_slot_data = temp
	inventory.populate_item_grid()
	update_grabbed_slot()

func swap_grabbed_slot_data():
	pass

func grabbed_item_split_single() -> InventorySlotData:
	var new_slot_data = grabbed_slot_data.duplicate()
	new_slot_data.quantity = 1
	grabbed_slot_data.quantity -= 1
	if grabbed_slot_data.quantity == 0:
		grabbed_slot_data = null
	return new_slot_data

func drop_single(inventory: Inventory, slot_index: int):
	if inventory.inventory_data.slot_datas[slot_index] == null:
		var single_slot_data: InventorySlotData = grabbed_item_split_single()
		inventory.inventory_data.slot_datas[slot_index] = single_slot_data
	elif inventory.inventory_data.slot_datas[slot_index].inventory_item_data == grabbed_slot_data.inventory_item_data:
		if inventory.inventory_data.slot_datas[slot_index].quantity < inventory.inventory_data.slot_datas[slot_index].max_stack_size:
			grabbed_item_split_single()
			inventory.inventory_data.slot_datas[slot_index].quantity += 1
	inventory.populate_item_grid()
	update_grabbed_slot()

func update_grabbed_slot() -> void:
	Log.info("update_grabbed_slot")
	if grabbed_slot_data:
		grabbed_slot.show()
		grabbed_slot.set_slot_data(grabbed_slot_data)
	else:
		grabbed_slot.hide()

func set_external_inventory_container(new_external_inventory_container: ContainerInteractable) -> void:
	external_inventory_container = new_external_inventory_container
	external_inventory.set_inventory_data(external_inventory_container.inventory_data)
	external_inventory.show()

func clear_external_inventory_container() -> void:
	if external_inventory_container:
		external_inventory_container = null
		external_inventory.hide()
		external_inventory.clear_inventory_data()
