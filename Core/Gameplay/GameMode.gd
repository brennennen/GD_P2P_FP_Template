extends Node

class_name GameMode

enum GameModeType { DEFAULT, HORROR }

var game_mode_type: GameModeType
var players: Node
#var spawn_points: Array[SpawnPoint]
var spawn_points: Node3D
var player_scene: PackedScene


var allow_player_join_spawn_mid_match: bool = true

# No struct, so using dictionary for player states
#var player_state = {
#	"peer_id": 1,
#	"spawned_once": false,
#}
var player_states: Array = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player_scene = load("res://Core/Character/Player/Player.tscn")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func set_game_mode_type(new_game_mode_type: GameModeType):
	game_mode_type = new_game_mode_type

func set_player_spawn_points(new_spawn_points: Node3D):
	spawn_points = new_spawn_points
	#spawn_points = []
	#for spawn_point in new_spawn_points.get_children():
		#if spawn_point is SpawnPoint:
			#spawn_points.append(spawn_point)

func set_player_scene(player_scene_path: String):
	player_scene = load(player_scene_path)

## Spawns a player into the level. Only callable by the server.
# TODO: do most of this logic in the network class, only get spawn position and set meta data
# in the game mode class
func spawn_player(peer_id) -> Player:
	#if !multiplayer.is_server():
	Logger.info("spawn_player: %d" % [peer_id])
	if !GameInstance.networking.is_server():
		return
	var player = player_scene.instantiate()
	var spawn_point_global_position = Vector3(0.0, 0.0, 0.0)
	var spawn_point_rotation = Vector3(0.0, 0.0, 0.0)
	if is_instance_valid(spawn_points) and spawn_points.get_children().size() > 0:
		var spawn_points_list = spawn_points.get_children()
		var spawn_point = spawn_points_list.pick_random()
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
	return player

func respawn_player(player: Player):
	# TODO: get unoccupied spawn point
	if is_instance_valid(spawn_points) and spawn_points.get_children().size() > 0:
		var spawn_points_list = spawn_points.get_children()
		var spawn_point = spawn_points_list.pick_random()
		player.global_position = spawn_point.global_position + Vector3(0.0, 10.0, 0.0)
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
		pass
	pass # Replace with function body.

func reset_game_mode():
	
	pass
