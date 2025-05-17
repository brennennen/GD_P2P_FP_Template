extends Level

@export var player_spawn_points: Node3D
@export var default_level_camera: Camera3D
@export var end_race_return_scene_path: String

@onready var kill_box = $KillBoxArea3D
@onready var start_timer_label_3d = $StartTimerLabel3D
@onready var pre_start_timer = $GamePreStartTimer
@onready var start_timer = $GameStartTimer
@onready var first_cross_end_timer = $FirstCrossEndTimer

@onready var winner_label3d = $WinnerLabel3D

var pre_start_timer_time: float = 5.0
var start_timer_time: float = 10.0
var first_cross_end_timer_time: float = 10.0

var finish_line_first_cross: bool = false

func _ready() -> void:
	super()
	GameInstance.initialize_level(name, scene_file_path, GameMode.GameModeType.DEFAULT, player_spawn_points, default_level_camera)
	# TODO: connect local player to the level camera for x seconds during pre-start?
	pre_start_timer.connect("timeout", _on_pre_start_timer_timeout)
	start_timer.connect("timeout", _on_start_timer_timeout)
	first_cross_end_timer.connect("timeout", _on_first_cross_end_timer_timeout)
	pre_start_timer.start(pre_start_timer_time)
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			GameInstance.game_mode.respawn_player(player)
			player.server_lock_movement.rpc()

@rpc("any_peer", "call_local", "reliable")
func start_race_timer() -> void:
	start_timer.start(start_timer_time)

func _process(delta: float) -> void:
	handle_start_timer_label()
	debug_imgui_race_window(delta)

func handle_start_timer_label():
	if start_timer.time_left > 0.0:
		start_timer_label_3d.text = "%f" % [ start_timer.time_left ]

func _on_pre_start_timer_timeout() -> void:
	Logger.info("_on_pre_start_timer_timeout")
	if GameInstance.networking.is_server():
		start_race_timer.rpc()

func _on_start_timer_timeout() -> void:
	Logger.info("Start timer timeout! race starting!")
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			player.unlock_movement.rpc()
	start_race.rpc()

func _on_first_cross_end_timer_timeout() -> void:
	Logger.info("_on_first_cross_end_timer_timeout")
	GameInstance.lobby_load_and_change_scene(end_race_return_scene_path)

@rpc("any_peer", "call_local", "reliable")
func start_race() -> void:
	start_timer.stop()
	pre_start_timer.stop()
	start_timer_label_3d.text = "GO!"

func _on_finish_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			Logger.info("player: %s entered finish area3d" % [ str(player.name) ])
			first_cross_finish_line.rpc(first_cross_finish_line)
			first_cross_end_timer.start(first_cross_end_timer_time)

@rpc("authority", "call_local", "reliable")
func first_cross_finish_line(player_name):
	winner_label3d.text = "Winner: %s!" % [ player_name ]

func _on_kill_box_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			Logger.info("player: %s entered killbox" % [str(player.name)])
			player.server_teleport_player.rpc(Vector3(0.0, 0.0, 0.0))

func debug_imgui_race_window(_delta: float) -> void:
	ImGui.Begin("Race")
	ImGui.Text("pre_start_timer: %f" % pre_start_timer.time_left)
	ImGui.Text("start_timer: %f" % start_timer.time_left)
	ImGui.Text("first_cross_end_timer: %f" % first_cross_end_timer.time_left)
	ImGui.End()
