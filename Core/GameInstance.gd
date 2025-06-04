extends Node

## Game play logic such as dying/respawning/etc.
@onready var game_mode: GameMode = $GameMode
## Handles all networking, multiplayer peers, and connection management.
@onready var networking: Networking = $Networking
#@onready var net_casual: NetCasual = $NetCasual
## Flag to check if we are running a scene with a proper "initialize_level" call or not.
var runnable_scene_is_initialized: bool = false
@onready var players: Node = $Players
@onready var npcs: Node = $NPCs
@onready var items: Node = $Items
@onready var projectiles: Node = $Projectiles

### Station/world save for the current run.
#var station: Station

const main_menu_scene_path = "res://Maps/Menus/MainMenu.tscn"
const loading_scene = preload("res://Maps/Menus/Loading.tscn")
const player_scene = preload("res://Core/Character/Player/Player.tscn")

var color: Color = Color(1.0, 0.0, 0.0) # default color, TODO: load this from a file?
var my_pawn_data: Dictionary = {
	"color": color
}

var current_level_path: NodePath
var default_level_camera: Camera3D

var is_loading: bool = false
var scene_to_load_path: String

var scene_generation_seed: int = 0

var debug_input: bool = false
var debug_draw: bool = false
var debug_draw_mask: int = 0xFF

var fps_history: Array[float] = []
var fps_history_index: int = 0
var session_min_fps: float = 60.0

var arguments: Dictionary = {}

var menu_error_message: String = ""

func _ready() -> void:
	arguments = parse_command_line_arguments(OS.get_cmdline_args())
	if OS.is_debug_build():
		$DebugLogTimer.wait_time = 10
		$DebugLogTimer.start()
	Log.set_multiplayer_id(networking.get_multiplayer_id())
	#Log.set_multiplayer_id(networking.get_multiplayer_id())
	fps_history.resize(60 * 10) # assume 60 fps for 10 seconds

	initialize_game_mode()
	get_tree().set_multiplayer_poll_enabled(false)

static func parse_command_line_arguments(arguments_raw: PackedStringArray) -> Dictionary:
	var arguments_dict: Dictionary = {}
	for argument in arguments_raw:
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			var key = key_value[0].lstrip("--")
			var value = key_value[1]
			arguments_dict[key] = value
	return arguments_dict

func _process(delta: float) -> void:
	process_fps_history()
	debug_imgui_game_instance_window(delta)

func process_fps_history() -> void:
	var fps = Engine.get_frames_per_second()
	fps_history_index = (fps_history_index + 1) % (fps_history.size() - 1)
	fps_history[fps_history_index] = fps
	if fps < session_min_fps:
		session_min_fps = fps

func debug_imgui_game_instance_window(_delta: float) -> void:
	ImGui.Begin("GameInstance")
	ImGui.Text("fps: %f" % [ Engine.get_frames_per_second() ])
	ImGui.Text("min fps: %f" % [session_min_fps ])
	ImGui.PlotLines("fps", fps_history, fps_history.size())
	ImGui.End()

func initialize_game_mode():
	if !game_mode:
		game_mode = GameMode.new()
		game_mode.name = "GameMode"
		add_child(game_mode)
		game_mode.set_owner(get_tree().get_edited_scene_root())

func initialize_level(level_name: String, scene_path: String, game_mode_type: GameMode.GameModeType, spawn_points: Node3D, level_cam: Camera3D):
	Log.info("Initializing level: %s, net_mode: %s" % [scene_path, Networking.MultiplayerMode_str(networking.multiplayer_mode)])
	runnable_scene_is_initialized = true
	default_level_camera = level_cam
	current_level_path = scene_path
	networking.game_network_state["scene_path"] = current_level_path
	game_mode.set_game_mode_type(game_mode_type)
	game_mode.set_player_spawn_points(spawn_points)

	# HACK: try to allow multiplayer testing with "running from current scene", really really janky, here be dragons
	if (	OS.is_debug_build() and \
			OS.has_feature("editor") and \
			get_parent() == get_tree().root and \
			networking.multiplayer_mode == Networking.MultiplayerMode.NONE
		):
		in_editor_run_multiple_instance_hack(level_name, scene_path)
	_on_debug_log_timer_timeout() # debug log right away

func in_editor_run_multiple_instance_hack(level_name: String, scene_path: String):
	Log.info("Detected scene running directly via run-scene. Using InEditorLobby for mulitple run instances.")
	networking.multiplayer_mode = Networking.MultiplayerMode.IN_EDITOR
	var main_node = load("res://Maps/Main/Main.tscn").instantiate()
	get_window().add_child.call_deferred(main_node)
	main_node.set_owner(get_tree().get_edited_scene_root())
	var level_node = get_tree().get_root().get_node(level_name)
	level_node.queue_free()
	var new_level_node = load(scene_path).instantiate()
	main_node.add_child.call_deferred(new_level_node)
	new_level_node.set_owner(get_tree().get_edited_scene_root())
	if GameInstance.networking.in_editor_lobby.instance_num == 1:
		networking.host_game()
	else:
		await get_tree().create_timer(0.5).timeout
		GameInstance.networking.in_editor_lobby.join_lobby()
	await get_tree().create_timer(1.0).timeout
	debug_position_all_instance_windows()
	pass

func debug_position_all_instance_windows():
	var window := get_window()
	match(networking.in_editor_lobby.instance_num):
		1:
			window.title = "server - 1"
			window.position = Vector2(0, 30)
		2:
			window.title = "client - 2"
			window.position = Vector2(1300, 30)
		3:
			window.title = "client - 3"
			window.position = Vector2(1300,  730) # 3rd player is bottom right, leave bottom left open to scan logs easier
		4:
			window.title = "client - 4"
			window.position = Vector2(0, 730)
		_:
			pass

## Changes to the loading scene and then loads the requested scene
func load_and_change_scene(scene_path: String):
	Log.info("%s:load_and_change_scene: scene_path: '%s'" % [name, scene_path])
	if ResourceLoader.has_cached(scene_path):
		Log.info("cached: '%s'" % scene_path)
		multiplayer.multiplayer_peer = GameInstance.mutliplayer_peer
		var scene = ResourceLoader.load_threaded_get(scene_path)
		change_scene(scene)
	else:
		scene_to_load_path = scene_path
		change_scene(loading_scene)
		ResourceLoader.load_threaded_request(scene_path, "", true)

## Doesn't show a loading screen, just loads directly on the same thread, good for menu transitions
func load_and_change_scene_blocking(scene_path: String):
	Log.info("%s:load_and_change_scene_blocking: scene_path: '%s'" % [name, scene_path])
	var scene = load(scene_path)
	change_scene(scene)

func change_scene(resource: Resource):
	if !resource:
		Log.error("%s:change_scene: scene resource is null! Can't change scene." % [name])
		return

	Log.info("%s:change_scene: '%s'" % [name, resource.resource_path])
	var node = resource.instantiate()
	#Log.debug("children: %s" % JSON.stringify(main.get_children()))
	var main: Node = get_tree().root.get_node("Main")
	for child in main.get_children():
		child.queue_free()
	main.add_child(node)

func go_to_main_menu_with_error(error: String):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_error_message = error
	load_and_change_scene_blocking(main_menu_scene_path)
	Log.error("go_to_main_menu_with_error: %s" % error)
	# TODO: figure out displaying the error

func lobby_load_and_change_scene(scene_path: String):
	# TODO: each player in the lobby needs to call load_and_change_scene
	lobby_load_and_change_scene_rpc.rpc(scene_path)

@rpc("authority", "call_local", "reliable")
func lobby_load_and_change_scene_rpc(scene_path: String):
	Log.info("%s:lobby_load_and_change_scene_rpc: scene_path: '%s'" % [name, scene_path])
	if ResourceLoader.has_cached(scene_path):
		Log.info("cached: '%s'" % scene_path)
		multiplayer.multiplayer_peer = GameInstance.mutliplayer_peer
		var scene = ResourceLoader.load_threaded_get(scene_path)
		change_scene(scene)
	else:
		scene_to_load_path = scene_path
		change_scene(loading_scene)
		ResourceLoader.load_threaded_request(scene_path, "", true)
	# TODO: also move each player pawn to a spawn point?

#@rpc("any_peer", "call_local", "reliable")
#func spawn_dropped_item(item_to_drop: InventoryItem):
	#print("here????: %d" % [multiplayer.get_unique_id()])
	#var interactable: RigidBodyInteractable = item_to_drop.rigid_body_interactable_resource.instantiate()
	#add_child(interactable)
	## TODO: find parent forward vector?
	##var parent = get_parent()
	#var dropped_item_position = inventory_owner.global_position + (-1 * inventory_owner.global_transform.basis.z * Vector3(0.5, 0.5, 0.5))
	#if inventory_owner is Player:
		##print("INVENTORY PARENT IS PLAYER!")
		#var player = inventory_owner as Player
		#dropped_item_position = player.vision_start.global_position + (-1 * inventory_owner.vision_start.global_transform.basis.z * Vector3(0.5, 0.0, 0.5))
	#interactable.global_position = dropped_item_position
	#Log.info("Spawning interactable: %s at %v" % [interactable.name, interactable.global_position])
	#interactable.set_owner(get_tree().get_edited_scene_root())

func load_player_menu_scene_blocking(scene_path: String):
	Log.info("%s:load_player_menu_scene_blocking: scene_path: '%s'" % [name, scene_path])
	var scene = load(scene_path)
	change_player_sibling_menu_scene(scene)

func change_player_sibling_menu_scene(resource: Resource) -> Node:
	if !resource:
		Log.error("%s:change_scene: scene resource is null! Can't change scene." % [name])
		return

	Log.info("%s:change_scene: '%s'" % [name, resource.resource_path])
	var node = resource.instantiate()
	#Log.debug("children: %s" % JSON.stringify(main.get_children()))
	# TODO: where to spawn this? main seems messy? need a sub folder? make it off of player?
	#var x = get_tree().root.get_node_or_null("Main/PlayerMenus")
	#if !x:
	#	get_tree().root.
	var main: Node = get_tree().root.get_node("Main")
	#for child in main.get_children():
	#	#main.remove_child(child)
	#	child.queue_free()
	main.add_child(node)
	return node

##
## Scene path is expected to inherit from node3d!
##
@rpc("any_peer", "call_local", "reliable")
func spawn_item_3d_scene(scene_path: String, pos: Vector3) -> Node:
	var resource: Resource = load(scene_path)
	var scene: Node = resource.instantiate()
	scene.global_position = pos
	items.add_child(scene)
	return scene

func remove_all_players():
	for player in GameInstance.get_node("Players").get_children():
		player.queue_free()

@rpc("any_peer", "call_local", "reliable")
func despawn_npcs():
	for npc in GameInstance.get_node("NPCs").get_children():
		npc.queue_free()

@rpc("any_peer", "call_local", "reliable")
func despawn_items():
	for item in GameInstance.get_node("Items").get_children():
		item.queue_free()

func log_system_data():
	var system_data = {
		"debug": OS.is_debug_build(),
		"model": OS.get_model_name(),
		"os": OS.get_name(),
		"os_distribution": OS.get_distribution_name(),
		"id": OS.get_unique_id(),
		"version": OS.get_version(),
		"arguments": OS.get_cmdline_args(),
		"config_dir": OS.get_config_dir(),
		"data_dir": OS.get_data_dir(),
		"user_data_dir": OS.get_user_data_dir(),
		"processor": OS.get_processor_name(),
		"logical_cores": OS.get_processor_count(),
		"process_id": OS.get_process_id(),
		"locale": OS.get_locale(),
		"language": OS.get_locale_language(),
		"executable_path": OS.get_executable_path()
	}
	Log.info("system: %s" % JSON.stringify(system_data))

func log_debug_memory_usage():
	if OS.is_debug_build():
		Log.info("memory usage: static: %d, peak: %d" % [ OS.get_static_memory_usage(), OS.get_static_memory_peak_usage() ])

func return_to_main_menu() -> void:
	# TODO: save? tell multiplayer to disconnect peer gracefully?
	#multiplayer_lobby.clear()
	#change_scene("res://Maps/Menus/MainMenu.tscn")
	reset_game_instance()
	load_and_change_scene_blocking("res://Maps/Menus/MainMenu.tscn")

func reset_game_instance() -> void:
	game_mode.reset_game_mode()
	networking.reset_networking()
	clear_players()
	clear_items()
	clear_npcs()

func quit():
	# TODO: save? tell multiplayer to disconnect peer gracefully?
	get_tree().quit()

func clear_players() -> void:
	for player in get_node("Players").get_children():
		player.queue_free()

func clear_items() -> void:
	for item in get_node("Items").get_children():
		item.queue_free()

func clear_npcs() -> void:
	for npc in get_node("NPCs").get_children():
		npc.queue_free()

func get_players() -> Array[Player]:
	var players_array: Array[Player] = []
	for player in get_node("Players").get_children():
		if player is Player:
			players_array.append(player)
	return players_array
	#return networking.get_players()

func get_player_from_id(player_name: int) -> Player:
	var player = get_node("Players").get_node_or_null(str(player_name))
	if player is Player:
		return player as Player
	return null


func get_npcs() -> Array[NPC]:
	var npcs_array: Array[NPC] = []
	for npc in get_node("NPCs").get_children():
		npcs_array.append(npc)
	return npcs_array

var command_history: Array[String] = []
func debug_console_command_execute(command: String, result_output: RichTextLabel):
	command_history.append(command)
	if command == "/help":
		Log.info("here")
		print("HELP COMMAND SENT!")
	#if command.contains("ai:"):
		#var result = do_ai(command)
		#result_output.append_text(result)
	if command.contains(".") and command.contains("(") and command.contains(")"):
		var object_method_parts = command.split(".", true, 1)
		var object = object_method_parts[0]
		var method_arguments_parts = object_method_parts[1].split("(", true, 1)
		var method_name = method_arguments_parts[0]
		var method_args_unparsed = method_arguments_parts[1].rstrip(")")
		var method_args = method_args_unparsed.split(",", false)
		result_output.append_text("obj: %s, method: %s, arguments: %s\n" % [object, method_name, JSON.stringify(method_args)])
		var command_result: String = ""
		if object == "" or object == "gi" or object == "GameInstance":
			var result = GameInstance.callv(method_name, method_args)
			command_result = JSON.stringify(result)
		elif object == "station":
			var result = GameInstance.station.callv(method_name, method_args)
			command_result = JSON.stringify(result)
		elif object == "sector":
			var result = GameInstance.station.current_sector.callv(method_name, method_args)
			command_result = JSON.stringify(result)
		if command_result != "" and command_result != "null":
			result_output.append_text(command_result)
	else:
		print("TODO")
	pass

func get_debug_console_command_history():
	pass

## For scenes like "Player" that are never intended to be ran, if you accidentally press "Run Current Scene",
## then load up the sandbox scene instead of trying to play an unplayable scene.
func debug_run_current_scene(scene_node: Node3D):
	if (	runnable_scene_is_initialized == false and \
			OS.has_feature("editor") and \
			scene_node.get_parent() == get_tree().root
		):
		load_and_change_scene_blocking("res://Maps/HUBLevel/HUBLevel.tscn")

func _on_debug_log_timer_timeout() -> void:
	networking.debug_log()
	#pass # Replace with function body.

func kill_player(player_name: String):
	Log.info("killing player: %s" % player_name)
	for player in get_players():
		if player.name == player_name:
			player.die()
