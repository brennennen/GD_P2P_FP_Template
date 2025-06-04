extends Node3D

class_name LevelTeleporter

@export var label_name: String
@export var scene_path: String

@export var minimum_players: int = 2
@export var maximum_players: int = 8


# # Labels/UI
@onready var level_name_label_3d: Label3D = $LevelNameLabel3D



# # Audio
@onready var invalid_entry_audio: AudioStreamPlayer3D = $InvalidEntryAudio
@onready var valid_entry_audio: AudioStreamPlayer3D = $ValidEntryAudio


var started_level_transition: bool = false

func _ready() -> void:
	level_name_label_3d.text = label_name

func _on_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if minimum_players <= GameInstance.networking.peers.size() and GameInstance.networking.peers.size() <= maximum_players:
			if !started_level_transition:
				if body is Player:
					var player := body as Player
					if player.name == str(1):
						started_level_transition = true
						Log.info("player: %s entered teleporter: label: %s, scene: %s" % [ str(player.name), label_name, scene_path])
						await get_tree().create_timer(1.0).timeout
						valid_entry_feedback.rpc()
						#GameInstance.load_and_change_scene(scene_path)
						player.fade_to_black(1.0)
						await get_tree().create_timer(1.0).timeout
						GameInstance.lobby_load_and_change_scene(scene_path)
						# TODO: implement game instance way to travel/change scenes with lobby
		else:
			invalid_entry_feedback()
	else:
		invalid_entry_feedback()

func invalid_entry_feedback():
	invalid_entry_audio.play()

@rpc("any_peer", "call_local", "reliable")
func valid_entry_feedback():
	valid_entry_audio.play()
