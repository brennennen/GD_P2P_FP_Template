extends Level

func _ready() -> void:
	super()
	#Log.info("test")
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			GameInstance.game_mode.respawn_player(player)
