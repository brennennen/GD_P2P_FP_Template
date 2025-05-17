extends Node

class_name GameMode

enum GameModeType { DEFAULT, HUB, RACE, LAST_MAN_STANDING }

var game_mode_type: GameModeType
var players: Node
var spawn_points: Node3D
var player_scene: PackedScene

var reserved_spawn_points_this_frame: Array[SpawnPoint] = []

var allow_player_join_spawn_mid_match: bool = true

# No struct, so using dictionary for player states
#var player_state = {
#	"peer_id": 1,
#	"spawned_once": false,
#}
var player_states: Array = []

func _ready() -> void:
	player_scene = load("res://Core/Character/Player/Player.tscn")

func _physics_process(_delta: float) -> void:
	reserved_spawn_points_this_frame.clear()

func set_game_mode_type(new_game_mode_type: GameModeType):
	game_mode_type = new_game_mode_type

func set_player_spawn_points(new_spawn_points: Node3D):
	spawn_points = new_spawn_points

func set_player_scene(player_scene_path: String):
	player_scene = load(player_scene_path)

## Spawns a player into the level. Only callable by the server.
func spawn_player(peer_id) -> Player:
	Logger.info("spawn_player: %d" % [peer_id])
	if !GameInstance.networking.is_server():
		return
	var player : Player = player_scene.instantiate()
	var spawn_point_global_position = Vector3(0.0, 0.0, 0.0)
	var spawn_point_rotation = Vector3(0.0, 0.0, 0.0)
	if is_instance_valid(spawn_points) and spawn_points.get_children().size() > 0:
		var spawn_point = get_spawn_point() # TODO: add a random vector offset incase the player is spawned at the same point?
		Logger.info("%s:spawn_player: player: %s pos: %v, rot.y: %d" % [name, player.name, spawn_point.global_position, spawn_point.rotation_degrees.y])
		#player.set_spawn_rotation(spawn_point.rotation)
		Logger.info("player rot_deg.y: %f" % [player.rotation_degrees.y])
		#player.global_position = spawn_point.global_position
		spawn_point_global_position = spawn_point.global_position
		spawn_point_rotation = spawn_point.rotation
	else:
		Logger.error("NO VALID SPAWN POINT! SPAWNING AT (0,0,0)")
	player.name = str(peer_id)
	GameInstance.get_node("Players").add_child(player)
	player.set_owner(get_tree().get_edited_scene_root())
	player.set_spawn_rotation(spawn_point_rotation)
	player.global_position = spawn_point_global_position
	player.network_target_position = spawn_point_global_position
	return player

func get_spawn_point() -> SpawnPoint:
	for child in spawn_points.get_children():
		var spawn_point = child as SpawnPoint
		if !spawn_point.is_occupied() and spawn_point not in reserved_spawn_points_this_frame:
			reserved_spawn_points_this_frame.append(spawn_point)
			return spawn_point
	return spawn_points.get_children().pick_random() # if all spawn points are occupied, pick a random one

# TODO: create a spawn queue? respawning adds players to the spawn queue, only spawn 1 player per physics tick?


func handle_player_death(player: Player):
	Logger.info("handle_player_death: %s" % [ player.name ])
	match(game_mode_type):
		GameModeType.LAST_MAN_STANDING:
			player.die()
			# TODO: start spectate mode after x seconds...
		_:
			player.die()
			# TODO: respawn after x seconds...
			respawn_player(player)

func respawn_player(player: Player):
	Logger.info("respawn_player: %s" % [ player.name ])
	if is_instance_valid(spawn_points) and spawn_points.get_children().size() > 0:
		var spawn_point = get_spawn_point()
		player.global_position = spawn_point.global_position
		player.network_target_position = spawn_point.global_position
		player.respawn()
	else:
		Logger.error("%s:respawn_player: NO VALID SPAWN POINTS!" % [name])

func register_new_player(peer_id):
	var new_player_state = {
		"peer_id": peer_id,
		"spawned_once": false,
	}
	player_states.append(new_player_state)

func _on_game_mode_1_hz_timer_timeout():
	#if multiplayer.is_server():
	if GameInstance.networking.is_server():
		check_players_to_spawn()

func check_players_to_spawn():
	for player_state in player_states:
		if player_state["spawned"] == false:
			spawn_player(player_state["peer_id"])

func reset_game_mode():
	pass
