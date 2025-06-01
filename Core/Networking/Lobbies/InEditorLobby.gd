extends Node

class_name InEditorLobby

##
# Multiplayer lobby implementation for "in editor" lobbies. Launching multiple instances
# in your editor can be a quick way to debug and test the multiplayer features on a level.
#

var enet_peer: ENetMultiplayerPeer# = ENetMultiplayerPeer.new()

@export var instance_num := -1
var instance_socket: TCPServer
var networking: Networking
var port: int = 7999
var player_scene: Resource

func _init() -> void:
	if OS.is_debug_build() and OS.has_feature("editor"):
		Logger.debug("InEditorLobby.init()")
		#GameInstance.process_command_line_arguments()
		find_debug_run_instance_id()
		enet_peer = ENetMultiplayerPeer.new()

func _ready() -> void:
	if OS.is_debug_build() and OS.has_feature("editor"):
		Logger.debug("InEditorLobby.ready()")

func setup(node_name: String, new_networking: Networking):
	if OS.is_debug_build() and OS.has_feature("editor"):
		name = node_name
		networking = new_networking

# Godot _init() is called before any globals exist, so can't call `GamInstance.parse_command_line_arguments()`.
static func parse_command_line_arguments(arguments_raw: PackedStringArray) -> Dictionary:
	var arguments_dict: Dictionary = {}
	for argument in arguments_raw:
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			var key = key_value[0].lstrip("--")
			var value = key_value[1]
			arguments_dict[key] = value
	return arguments_dict

func find_debug_run_instance_id():
	# 4.3 introduced command line args per instance which might be a better work around: https://github.com/godotengine/godot/pull/65753
	var arguments = parse_command_line_arguments(OS.get_cmdline_args())
	if "instance_id" in arguments.keys():
		instance_num = int(arguments["instance_id"])
		return

	# Pre 4.3, no in-engine way to get instance id:
	# open issue/feature request: https://github.com/godotengine/godot-proposals/issues/3357
	# Janky work around: https://www.reddit.com/r/godot/comments/11ec4ju/get_instance_number_when_using_the_godot_4_run/
	#if OS.is_debug_build() and OS.has_feature("editor"):
		#Logger.debug("InEditorLobby.find_debug_run_instance_id")
		#instance_socket = TCPServer.new()
		#for n in range(1,9): # 1 based array to match server id being 1
			#if instance_socket.listen(5000 + n) == OK:
				#instance_num = n
				#break
		#assert(instance_num >= 1, "Unable to determine instance number. Seems like all TCP ports are in use")

func get_multiplayer_id():
	return instance_num

func manage_lobby():
	find_debug_run_instance_id()
	Logger.debug("InEditorLobby.manage_lobby(): %d" % instance_num)
	if OS.is_debug_build() and OS.has_feature("editor"):
		if instance_num == 1:
			host_game()
		else:
			await get_tree().create_timer(1.0).timeout
			join_lobby()

func host_game() -> Error:
	if OS.is_debug_build() and OS.has_feature("editor"):
		Logger.debug("InEditorLobby.create_lobby(): instance: %d, mp_id: %d" % [ instance_num, multiplayer.get_unique_id() ])
		var result = enet_peer.create_server(port)
		multiplayer.multiplayer_peer = enet_peer
		return result
	return 1 as Error

func join_lobby() -> Error:
	if OS.is_debug_build() and OS.has_feature("editor"):
		var peer = ENetMultiplayerPeer.new()
		Logger.debug("InEditorLobby.join_lobby(): %d" % instance_num)
		var error = peer.create_client("127.0.0.1", port)
		peer.get_peer(1).set_timeout(0, 0, 3000) # 3 second timeout # TODO: figure out what 1 is? does that need to be multiplyer id?
		if error:
			Logger.error("InEditorLobby join_game error: (%d) %s" % [error, error_string(error)])
			return error
		multiplayer.multiplayer_peer = peer
		return Error.OK
	else:
		Logger.error("InEditorLobby join called from non-editor or non-debug build game instance!")
		return Error.FAILED
