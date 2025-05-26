extends Resource

class_name InventoryData

@export var slot_datas: Array[InventorySlotData]


func grab_slot_data(index: int) -> InventorySlotData:
	if index < slot_datas.size():
		return slot_datas[index]
	return null
