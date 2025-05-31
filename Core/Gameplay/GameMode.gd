extends Node

class_name GameMode

enum GameModeType { DEFAULT, HUB, RACE, LAST_MAN_STANDING }

var game_mode_type: GameModeType
var players: Node
var spawn_points: Node3D
var player_scene: PackedScene
var allow_spawn_on_join_after_start: bool

var reserved_spawn_points_this_frame: Array[SpawnPoint] = []

var allow_player_join_spawn_mid_match: bool = true

@onready var game_mode_1hz_timer: Timer = $Timer

func _ready() -> void:
	player_scene = load("res://Core/Character/Player/Player.tscn")
	game_mode_1hz_timer.start(1.0)
	game_mode_1hz_timer.timeout.connect(_on_game_mode_1_hz_timer_timeout)

func _physics_process(_delta: float) -> void:
	reserved_spawn_points_this_frame.clear()

func set_game_mode_type(new_game_mode_type: GameModeType):
	game_mode_type = new_game_mode_type

func set_player_spawn_points(new_spawn_points: Node3D):
	spawn_points = new_spawn_points

func set_player_scene(player_scene_path: String):
	player_scene = load(player_scene_path)

func handle_peer_join(peer_id) -> void:
	spawn_player(peer_id)

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
		spawn_point_global_position = spawn_point.global_position
		spawn_point_rotation = spawn_point.rotation
	else:
		Logger.error("NO VALID SPAWN POINT! SPAWNING AT (0,0,0)")
	player.name = str(peer_id)
	GameInstance.get_node("Players").add_child(player)
	player.set_owner(get_tree().get_edited_scene_root())
	player.set_spawn_rotation(spawn_point_rotation)
	player.global_position = spawn_point_global_position
	player.network_controller.network_target_position = spawn_point_global_position
	
	GameInstance.networking.peers[peer_id].player_last_broadcast_position = player.global_position
	GameInstance.networking.peers[peer_id].player_last_broadcast_rotation_y = player.global_rotation_degrees.y
	GameInstance.networking.peers[peer_id].player_camera_last_broadcast_rotation_x = player.camera.global_rotation_degrees.x
	GameInstance.networking.peers[peer_id].player = player
	return player

var last_spawn_index: int = 0
func get_spawn_point() -> SpawnPoint:
	var sentinel: int = 0
	var spawn_points_array: Array[Node] = spawn_points.get_children()
	var spawn_point_count: int = spawn_points.get_child_count()
	var next_spawn_index = last_spawn_index
	while(true):
		sentinel += 1
		if sentinel > 100:
			break
		next_spawn_index = (next_spawn_index + 1) % (spawn_point_count - 1)
		if spawn_points_array[next_spawn_index] is SpawnPoint:
			var spawn_point = spawn_points_array[next_spawn_index] as SpawnPoint
			if !spawn_point.is_occupied() and spawn_point not in reserved_spawn_points_this_frame:
				last_spawn_index = next_spawn_index
				return spawn_point
	return spawn_points.get_children().pick_random()

func handle_player_death(player: Player):
	Logger.info("handle_player_death: %s" % [ player.name ])
	match(game_mode_type):
		GameModeType.LAST_MAN_STANDING:
			respawn_player(player, true)
		_:
			respawn_player(player, false)

#@rpc("authority", "call_local", "reliable")
func respawn_player(player: Player, spectator: bool = false):
	if is_instance_valid(spawn_points) and spawn_points.get_children().size() > 0:
		var spawn_point = get_spawn_point()
		Logger.info("respawn_player: %s, pos: %v, spectate: %s" % [ player.name, spawn_point.global_position, str(spectator) ])
		player.respawn.rpc(spawn_point.global_position + Vector3(0.0, 0.1, 0.0), spawn_point.global_rotation_degrees.y, spectator) # spawn a bit above the point?
	else:
		Logger.error("%s:respawn_player: NO VALID SPAWN POINTS!" % [name])

func _on_game_mode_1_hz_timer_timeout():
	if GameInstance.networking.is_server():
		check_players_to_spawn()
		if game_mode_type == GameModeType.LAST_MAN_STANDING:
			last_man_standing_1hz()

func check_players_to_spawn():
	if allow_player_join_spawn_mid_match:
		for peer in GameInstance.networking.peers:
			if !GameInstance.networking.peers[peer].player:
				Logger.info("Found player not spawned, spawning them: %s" % [str(peer)])
				spawn_player(peer)
	# TODO: check dead players and respawn them if needed?

func last_man_standing_1hz():
	var players_alive: int = 0
	for player in GameInstance.get_players():
		if player.is_alive:
			players_alive += 1
	if players_alive == 1:
		# TODO: start end game timer!
		Logger.info("TODO! game over! player still alive wins!")
		handle_game_over()
	if players_alive == 0:
		# gotta handle this
		Logger.info("TODO! game over! figure out which player died last?")
		handle_game_over()
	Logger.info("last_man_standing_1hz: players_alive: %d" % [players_alive])

func handle_game_over():
	# TODO: start timer and teleport to hub world after 10 seconds?
	GameInstance.lobby_load_and_change_scene("res://Maps/HUBLevel/HUBLevel.tscn")

func debug_imgui_game_instance_window(_delta: float) -> void:
	#ImGui.Begin("GameMode")
	#ImGui.Text("")
	#ImGui.End()
	pass

func reset_game_mode():
	pass
