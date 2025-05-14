extends Level

@export var player_spawn_points: Node3D
@export var default_level_camera: Camera3D

@onready var kill_box = $Area3D

func _ready() -> void:
	super()
	GameInstance.initialize_level(name, scene_file_path, GameMode.GameModeType.DEFAULT, player_spawn_points, default_level_camera)
