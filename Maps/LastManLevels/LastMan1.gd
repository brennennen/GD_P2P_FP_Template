extends Level

@onready var pre_start_timer: Timer = $GamePreStartTimer
@onready var start_timer: Timer = $GameStartTimer

@onready var start_timer_label_3d = $StartTimerLabel3D

var pre_start_timer_time: float = 5.0
var start_timer_time: float = 10.0

func _ready() -> void:
	super()
	pre_start_timer.connect("timeout", _on_pre_start_timer_timeout)
	start_timer.connect("timeout", _on_start_timer_timeout)
	if GameInstance.networking.is_server():
		last_man_server_start()

func last_man_server_start() -> void:
	pre_start_timer.start(pre_start_timer_time)
	for player in GameInstance.get_players():
		GameInstance.game_mode.respawn_player(player)
		player.server_lock_movement.rpc_id(int(player.name))

func _process(delta: float) -> void:
	handle_start_timer_label()
	debug_imgui_last_man_window(delta)

func handle_start_timer_label():
	if start_timer.time_left > 0.0:
		start_timer_label_3d.text = "%f" % [ start_timer.time_left ]

func _on_pre_start_timer_timeout() -> void:
	#Log.info("_on_pre_start_timer_timeout")
	if GameInstance.networking.is_server():
		start_game_start_timer.rpc()

func _on_start_timer_timeout() -> void:
	#Log.info("Start timer timeout! race starting!")
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			player.unlock_movement.rpc()
	start_game.rpc()

@rpc("any_peer", "call_local", "reliable")
func start_game_start_timer() -> void:
	start_timer.start(start_timer_time)

@rpc("any_peer", "call_local", "reliable")
func start_game() -> void:
	start_timer.stop()
	pre_start_timer.stop()
	start_timer_label_3d.text = "FIGHT!"

func debug_imgui_last_man_window(_delta: float) -> void:
	ImGui.Begin("LastMan")
	ImGui.Text("pre_start_timer: %f" % pre_start_timer.time_left)
	ImGui.Text("start_timer: %f" % start_timer.time_left)
	ImGui.Text("players_alive: %d" % start_timer.time_left)
	ImGui.End()
