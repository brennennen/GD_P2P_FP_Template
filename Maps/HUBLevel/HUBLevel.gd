extends Level

@export var player_spawn_points: Node3D
@export var default_level_camera: Camera3D


func _ready() -> void:
	super()
	GameInstance.initialize_level(name, scene_file_path, GameMode.GameModeType.DEFAULT, player_spawn_points, default_level_camera)

	# TODO: only run this if it isn't played as the main scene from editor?
	# If we travel back to the HUBLevel, respawn each player
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			GameInstance.game_mode.respawn_player(player)

func _process(delta) -> void:
	debug_imgui_hub_level_window(delta)

func debug_imgui_hub_level_window(_delta: float) -> void:
	ImGui.Begin("My HUBLevel Window")
	#ImGui.Text("hello from GDScript")
	ImGui.End()

func _on_kill_box_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			Logger.info("player: %s entered killbox" % [str(player.name)])
			GameInstance.game_mode.handle_player_death(player)
			#player.server_teleport_player.rpc(Vector3(0.0, 0.0, 0.0))
