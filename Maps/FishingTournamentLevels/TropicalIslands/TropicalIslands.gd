extends Level

@onready var game_pre_start_timer: Timer = $GamePreStartTimer
@onready var game_start_timer: Timer = $GameStartTimer
@onready var game_timer: Timer = $GameTimer
@onready var game_end_transition_timer: Timer = $GameEndTransitionTimer


@onready var start_timer_label_3d: Label3D = $StartTimerLabel3D
@onready var game_timer_label_3d: Label3D = $GameTimerLabel3D


var pre_start_timer_time: float = 5.0
var start_timer_time: float = 10.0
var game_timer_time: float = 10.0 #60.0 * 5.0 # 5 minutes?
var game_end_transition_timer_time: float = 10.0


func _ready() -> void:
	super()
	GameInstance.initialize_level(name, scene_file_path, GameMode.GameModeType.DEFAULT, player_spawn_points, default_level_camera)
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			GameInstance.game_mode.respawn_player(player)

	game_pre_start_timer.connect("timeout", _on_pre_start_timer_timeout)
	game_start_timer.connect("timeout", _on_start_timer_timeout)
	game_timer.connect("timeout", _on_game_timer_timeout)
	game_end_transition_timer.connect("timeout", _on_game_end_transition_timer_timeout)
	game_pre_start_timer.start(5.0)

	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			GameInstance.game_mode.respawn_player(player)
			player.server_lock_movement.rpc_id(int(player.name))

@rpc("any_peer", "call_local", "reliable")
func start_game_start_timer() -> void:
	game_start_timer.start(start_timer_time)

@rpc("any_peer", "call_local", "reliable")
func start_game() -> void:
	game_pre_start_timer.stop()
	game_start_timer.stop()
	start_timer_label_3d.text = "GO!"
	game_timer.start(game_timer_time)

func _process(delta: float) -> void:
	handle_start_timer_label()
	handle_game_timer_label()
	#debug_imgui_race_window(delta)

func handle_start_timer_label():
	if game_start_timer.time_left > 0.0:
		start_timer_label_3d.text = "%f" % [ game_start_timer.time_left ]

func handle_game_timer_label():
	#if game_start_timer.time_left > 0.0:
	game_timer_label_3d.text = "%f" % [ game_timer.time_left ]


func _on_pre_start_timer_timeout() -> void:
	#Log.info("_on_pre_start_timer_timeout")
	if GameInstance.networking.is_server():
		start_game_start_timer.rpc()

func _on_start_timer_timeout() -> void:
	#Log.info("Start timer timeout! game starting!")
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			player.unlock_movement.rpc_id(int(player.name))
	start_game.rpc()

func _on_game_timer_timeout() -> void:
	#Log.info("Game timer timeout! check winner and start end game transition!")
	# TODO: check money of each player to decide who won
	game_end_transition_timer.start(game_end_transition_timer_time)

func _on_game_end_transition_timer_timeout() -> void:
	#Log.info("Game end transition timer timeout! game ending (for real this time)!")
	GameInstance.lobby_load_and_change_scene("res://Maps/HUBLevel/HUBLevel.tscn")
