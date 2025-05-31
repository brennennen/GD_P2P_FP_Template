extends PanelContainer

class_name InventorySlot


# TODO: create a reference up to the inventory...
var inventory: Inventory

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect
@onready var quantity_label: Label = $MarginContainer/QuantityLabel

func set_slot_data(slot_data: InventorySlotData) -> void:
	var inventory_item_data = slot_data.inventory_item_data
	texture_rect.texture = inventory_item_data.texture
	tooltip_text = "%s\n%s" % [inventory_item_data.name, inventory_item_data.description]
	if slot_data.quantity > 1:
		quantity_label.text = "%s" % [ slot_data.quantity ]
		quantity_label.show()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and (event.button_index == MOUSE_BUTTON_LEFT \
			or event.button_index == MOUSE_BUTTON_RIGHT) \
			and event.is_pressed():
		if inventory:
			inventory.slot_clicked(get_index(), event.button_index)
		#inventory.slot_clicked(get_index(), event.button_index)
		# slot_clicked.emit(get_index(), event.button_index)
		pass
	pass # Replace with function body.
