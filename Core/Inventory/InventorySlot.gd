extends PanelContainer

class_name InventorySlot

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect

@onready var quantity_label: Label = $MarginContainer/QuantityLabel


func set_slot_data(slot_data: InventorySlotData) -> void:
	var inventory_item_data = slot_data.inventory_item_data
	#texture_rect.texture = inventory_item_data.texture
	#tooltip_text = "%s\n%s" % [inventory_item_data.name, inventory_item_data.description]
	
	if slot_data.quantity > 1:
		quantity_label.text = "%s" % [ slot_data.quantity ]
		quantity_label.show()
