extends Node3D

class_name LevelTeleporter

@export var label_name: String
@export var scene_path: String

var started_level_transition: bool = false

func _ready() -> void:
	$Label3D.text = label_name

func _on_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if !started_level_transition:
			if body is Player:
				var player := body as Player
				if player.name == str(1):
					started_level_transition = true
					Logger.info("player: %s entered teleporter: label: %s, scene: %s" % [ str(player.name), label_name, scene_path])
					#GameInstance.load_and_change_scene(scene_path)
					player.fade_to_black(1.0)
					await get_tree().create_timer(1.0).timeout
					GameInstance.lobby_load_and_change_scene(scene_path)
					# TODO: implement game instance way to travel/change scenes with lobby
