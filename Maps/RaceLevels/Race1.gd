extends Level

@export var player_spawn_points: Node3D
@export var default_level_camera: Camera3D

@onready var kill_box = $KillBoxArea3D
@onready var start_timer_label_3d = $StartTimerLabel3D
@onready var pre_race_start_timer = $RacePreStartTimer
@onready var race_start_timer = $RaceStartTimer

var pre_start_timer_time: float = 10.0
var start_timer_time: float = 20.0

func _ready() -> void:
	super()
	GameInstance.initialize_level(name, scene_file_path, GameMode.GameModeType.DEFAULT, player_spawn_points, default_level_camera)
	# TODO: connect local player to the level camera for x seconds
	# move the player camera?
	# TODO: lock each player to not be allowed to move until timer expires!
	# TODO: spawn each player at a spawn point
	pre_race_start_timer.connect("timeout", _on_pre_start_timer_timeout)
	race_start_timer.connect("timeout", _on_start_timer_timeout)
	pre_race_start_timer.start(pre_start_timer_time)
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			GameInstance.game_mode.respawn_player(player)
			Logger.info("calling lock_movement.rpc")
			player.lock_movement.rpc()

@rpc("any_peer", "call_local", "reliable")
func start_race_timer() -> void:
	race_start_timer.start(start_timer_time)

func _process(delta: float) -> void:
	handle_start_timer_label(delta)
	debug_imgui_race_window(delta)

func handle_start_timer_label(delta):
	if race_start_timer.time_left > 0.0:
		start_timer_label_3d.text = "%f" % [ race_start_timer.time_left ]

func _on_pre_start_timer_timeout() -> void:
	Logger.info("pre start timer timeout")
	start_race_timer.rpc()

func _on_start_timer_timeout() -> void:
	Logger.info("Start timer timeout! race startin!")
	if GameInstance.networking.is_server():
		for player in GameInstance.get_players():
			player.unlock_movement.rpc()
	start_race.rpc()

@rpc("any_peer", "call_local", "reliable")
func start_race() -> void:
	race_start_timer.stop()
	pre_race_start_timer.stop()
	start_timer_label_3d.text = "GO!"

func _on_finish_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			Logger.info("player: %s entered finish area3d" % [str(player.name)])

func _on_kill_box_area_3d_body_entered(body: Node3D) -> void:
	if GameInstance.networking.is_server():
		if body is Player:
			var player := body as Player
			Logger.info("player: %s entered killbox" % [str(player.name)])
			player.server_teleport_player.rpc(Vector3(0.0, 0.0, 0.0))

func debug_imgui_race_window(_delta: float) -> void:
	ImGui.Begin("Race")
	ImGui.Text("pre_start_timer: %f" % pre_race_start_timer.time_left)
	ImGui.Text("start_timer: %f" % race_start_timer.time_left)
	ImGui.End()
