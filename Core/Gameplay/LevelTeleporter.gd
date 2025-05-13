extends Node3D

class_name LevelTeleporter

@export var label_name: String
@export var scene_path: String

func _ready() -> void:
	$Label3D.text = label_name
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			if player.name == str(1):
				Logger.info("player: %s entered teleporter: label: %s, scene: %s" % [ str(player.name), label_name, scene_path])
				#GameInstance.load_and_change_scene(scene_path)
				GameInstance.lobby_load_and_change_scene(scene_path)
				# TODO: implement game instance way to travel/change scenes with lobby
