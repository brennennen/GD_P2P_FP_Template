extends Node3D

class_name Level

@export var game_mode_type: GameMode.GameModeType
@export var player_spawn_points: Node3D
@export var default_level_camera: Camera3D

func _ready() -> void:
	GameInstance.initialize_level(name, scene_file_path, game_mode_type, player_spawn_points, default_level_camera)
	pass
