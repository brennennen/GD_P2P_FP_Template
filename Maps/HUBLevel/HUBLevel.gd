extends Level

@export var player_spawn_points: Node3D
@export var default_level_camera: Camera3D

func _ready() -> void:
	super()
	GameInstance.initialize_level(name, scene_file_path, GameMode.GameModeType.DEFAULT, player_spawn_points, default_level_camera)
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			GameInstance.game_mode.respawn_player(player)
