extends RigidBody3D

class_name FishingLureProjectile

@onready var player_collision_area_3d: Area3D = $PlayerCollisionArea3D

var start_direction: Vector3
var start_force: float
var owning_player: Player

func launch() -> void:
	apply_central_impulse(start_direction * start_force)

func _physics_process(_delta: float) -> void:
	# player to environment: allow on client (player movement related and static bodies shouldn't change too much, folks could cheat with this though)
	if owning_player.is_multiplayer_authority():
		if get_contact_count() > 0:
			for node in get_colliding_bodies():
				if node is StaticBody3D:
					# TODO: instead of "is_on_floor" maybe if player is holding left click?
					if owning_player.is_on_floor() and global_position.y - 1.0 < owning_player.global_position.y:
					#if owning_player.is_on_floor():
						owning_player.receive_fishing_lure_yoink.rpc(global_position)
						cleanup.rpc()
					else:
						owning_player.start_swinging.rpc(global_position)
					cleanup.rpc()

func _on_player_collision_area_3d_body_entered(body: Node3D) -> void:
	# Player to player: only allow on server
	if GameInstance.networking.is_server():
		if body is Player and body != owning_player:
			var player_hit = body as Player
			Log.info("player: %s (%v) fishing lure hit player: %s (%v)" % [owning_player.name, owning_player.global_position, player_hit.name, player_hit.global_position])
			player_hit.receive_fishing_lure_yoink.rpc(owning_player.global_position)
			cleanup.rpc()

@rpc("any_peer", "call_local", "reliable")
func cleanup():
	#Log.info("FishingLureProjectile.cleanup")
	# TODO: will this cause node not found desync issues? should multiplayer polling be disabled/turned off and then deleted after some delay? maybe just teleport to narnia for some time before deleting?
	# TODO: or just pool 2 of these per player and swap between them, disabling/hiding the unused one?
	queue_free()
	pass
