extends Area3D

class_name KillBox

func _ready() -> void:
	body_entered.connect(_on_kill_box_area_3d_body_entered)

func _on_kill_box_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			Log.info("player: %s entered killbox" % [str(player.name)])
			player.die.rpc()
