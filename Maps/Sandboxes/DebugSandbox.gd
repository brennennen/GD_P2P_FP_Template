extends Level

func _ready() -> void:
	super()
	GameInstance.initialize_level(name, scene_file_path, GameMode.GameModeType.DEFAULT, player_spawn_points, default_level_camera)
	# Delete a box on client's to easily test de-sync issues (client walks through box, "predicting"
	# the server will allow it). When the server sees the movement, it sees a box in the way and
	# snaps/rubber bands the player back if outside of some distance tolerance.
	if !GameInstance.networking.is_server():
		$World/Section1/ServerSideOnlyBox.queue_free()

	# TODO: only run this if it isn't played as the main scene from editor?
	# If we travel back to the HUBLevel, respawn each player
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			GameInstance.game_mode.respawn_player(player)
