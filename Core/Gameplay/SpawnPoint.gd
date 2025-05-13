extends Node3D

class_name SpawnPoint

var colliding_entries: Array[Node3D] = []

func _ready() -> void:
	$MeshInstance3D.visible = false;

func is_occupied() -> bool:
	return colliding_entries.size() != 0

func _on_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		colliding_entries.append(body)
		var colliding_entries_string = JSON.stringify(colliding_entries)
		Logger.info("SpawnPoint: %s area entered by %s (%s)" % [name, body.name, colliding_entries_string])

func _on_area_3d_body_exited(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		colliding_entries.erase(body)
		var colliding_entries_string = JSON.stringify(colliding_entries)
		Logger.info("SpawnPoint: %s area exited by %s (%s)" % [name, body.name, colliding_entries_string])
