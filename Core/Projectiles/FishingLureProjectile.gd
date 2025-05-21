extends RigidBody3D

class_name FishingLureProjectile

@onready var player_collision_area_3d: Area3D = $PlayerCollisionArea3D

var start_direction: Vector3
var start_force: float
var owning_player: Player

func launch() -> void:
	apply_central_impulse(start_direction * start_force)

func _on_player_collision_area_3d_body_entered(body: Node3D) -> void:
	# Player to player: only allow on server?
	if GameInstance.networking.is_server():
		if body is Player and body != owning_player:
			var player_hit = body as Player
			Logger.info("player: %s (%v) fishing lure hit player: %s (%v)" % [owning_player.name, owning_player.global_position, player_hit.name, player_hit.global_position])
			# TODO: yoink player hit toward owning player?
			player_hit.receive_fishing_lure_yoink.rpc(owning_player.global_position)
			# TODO: queue_free() rpc
			#queue_free()
			cleanup.rpc()
	# player to environment: allow on client
	if body is StaticBody3D:
		Logger.info("player: %s (%v) fishing lure hit static body: %s (%v)" % [owning_player.name, owning_player.global_position, body.name, body.global_position])
		# TODO: yoink self toward point that lure hit?

@rpc("any_peer", "call_local", "reliable")
func cleanup():
	Logger.info("FishingLureProjectile.cleanup")
	# TODO: will this cause node not found desync issues? should multiplayer polling be disabled/turned off and then deleted after some delay? maybe just teleport to narnia for some time before deleting?
	# TODO: or just pool 2 of these per player and swap between them, disabling/hiding the unused one?
	queue_free()
	pass
