extends Level


func _ready() -> void:
	
	pass


func _on_finish_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			Logger.info("player: %s entered finish area3d" % [str(player.name)])
			# TODO: end race game mode!
			#player.server_teleport_player.rpc(Vector3(0.0, 0.0, 0.0))


func _on_kill_box_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			Logger.info("player: %s entered killbox" % [str(player.name)])
			player.server_teleport_player.rpc(Vector3(0.0, 0.0, 0.0))
