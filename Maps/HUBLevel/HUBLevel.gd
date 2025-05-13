extends Level

@export var player_spawn_points: Node3D
@export var default_level_camera: Camera3D

@onready var kill_box = $Area3D

func _ready() -> void:
	super()
	GameInstance.initialize_level(name, scene_file_path, GameMode.GameModeType.DEFAULT, player_spawn_points, default_level_camera)

func _on_kill_box_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			Logger.info("player: %s entered killbox" % [str(player.name)])
			player.server_teleport_player.rpc(Vector3(0.0, 0.0, 0.0))
