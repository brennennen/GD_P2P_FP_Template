extends Node

class_name Networking

enum MultiplayerMode {
	NONE,
	SINGLE_PLAYER,
	IN_EDITOR,
	DIRECT_CONNECT,
	STEAM
}
static var multiplayer_mode_names = [ "NONE", "SINGLE_PLAYER", "IN_EDITOR", "DIRECT_CONNECT", "STEAM" ]
static func MultiplayerMode_str(mode: MultiplayerMode) -> String:
	return multiplayer_mode_names[mode]

enum NetworkingMessages {
	TIME_SYNC
}

## Messages sent between the client and server to synchronize game state.
enum NetworkMessageId {
# START SYNCHRONIZATION INITIALIZATION MESSAGES
	## Client -> Server: Client requests the initial game state from the server.
	REQUEST_INITIAL_GAME_STATE,
	## Server -> Client: Server
	## Sent by the server when requested, holds the initial game state (ex: which level scene to load,
	## a list of player ids, etc). After a client receives the initial game state, they request the
	## initial state of each player in the game to spawn their respective pawns.
	SERVER_INITIAL_GAME_STATE,
	## Client -> Server: Client requests the intial state of the level being loaded (if any)
	REQUEST_INITIAL_LEVEL_STATE,
	## Server -> Client: Data needed to properly load the initial level.
	SERVER_INITIAL_LEVEL_STATE,
	## Client -> Server: Client registers their pawn data with the server.
	CLIENT_REGISTER_PLAYER_PAWN_DATA,
	## Server -> Client: Server acknolwedgement of client pawn data.
	## The server sends a "SERVER_BROADCAST_PEER_IDS" embedded in ack player pawn data for the next
	## peer sync process
	SERVER_ACKNOWLEDGE_PLAYER_PAWN_DATA,
	## Client -> Server:
	## Sent by the client to request the initial state of each individual player in the game,
	## received by server who responds with PLAYER_INITIAL_STATE
	REQUEST_PEER_INITIAL_STATE,
	## Server -> Client: Sent by server to client to provide the initial data to spawn
	## a peer (pawn data/skins, position, rotation, etc).
	PEER_INITIAL_STATE,
# END SYNCHRONIZATION INITIALIZATION MESSAGES

# MATCH IN PROGRESS MESSAGES
	SERVER_BROADCAST_TICK,
	#SERVER_BROADCAST_TIME,
	PING,
	PING_RESPONSE,
	SERVER_BROADCAST_PEER_IDS,
	SERVER_BROADCAST_PLAYER_MOVEMENT,
	SERVER_BROADCAST_ALL_PLAYER_MOVEMENT,
	CLIENT_SEND_PLAYER_MOVEMENT,
	SERVER_SEND_CLIENT_PLAYER_MOVEMENT_RECONCILIATION,
	SERVER_BROADCAST_NPC_SPAWN,
	SERVER_BROADCAST_NPC_MOVEMENT,
	SERVER_BROADCAST_ALL_NPC_MOVEMENT
	#SERVER_SIGNAL_SCENE_CHANGE,
	#SERVER_PROCEDURAL_SCENE_PACKET
# END MATCH IN PROGRESS MESSAGES
}

static func NetworkMessageId_str(message_id: NetworkMessageId):
	return NetworkMessageId.keys()[message_id]

@onready var client_networking: ClientNetworking = $ClientNetworking
@onready var server_networking: ServerNetworking = $ServerNetworking
@onready var in_editor_lobby: InEditorLobby = $InEditorLobby
@onready var direct_connect_lobby: DirectConnectLobby = $DirectConnectLobby
@onready var steam_lobby: SteamLobby = $SteamLobby

var scene_multiplayer: SceneMultiplayer

var game_network_state = {
	"scene_path": null
}

var network_tick: int = 0
var network_time_ms: int = 0 # don't need both net_tick and net_time_ms, but might be good to explore the trade offs between the two approaches
var network_tick_rate: float = 0.016666666 # 0.06666666666 = 15 fps 0.03333333333 = 30 fps, 0.0166666 = 60 fps)
var network_tick_running_delta: float = 0.0
var network_tick_second_rollover: float = 0.0
var network_player_tick_rate: float = 0.06666666666
var network_fixed_physics_tick_rate: float = 5.0 # not important data

# Been using clumsy for most emulation these days, don't use any of this much.
# TODO: setup packet loss emulation
var debug_emulate_latency: bool = false
var debug_emulate_latency_seconds: float = 0.500 # 500ms?
var debug_emulate_latency_running_delta: float = 0.0
var debug_emulate_packet_loss: bool = true
var debug_emulate_packet_loss_percent: float = 0.10 # 10%?

var peers: Dictionary[int, PeerMetadata]
#var player_pawn_data: Dictionary = {}

var multiplayer_mode: MultiplayerMode = MultiplayerMode.NONE

var polling_paused: bool = false

# Metrics
var sent_messages: int = 0
var received_messages: int = 0
var total_bytes_sent: int = 0
var total_bytes_received: int = 0
var this_second_bytes_sent: int = 0
var this_second_bytes_received: int = 0
var last_second_bytes_sent: int = 0
var last_second_bytes_received: int = 0

# Status
var last_status_message: String = ""

# "multiplayer.is_server" always returns true, so this needs to be tracked manually...
var _is_server: bool = false
func is_server() -> bool:
	return _is_server

func _ready():
	multiplayer.allow_object_decoding = true # doesn't work - supposed to make RPC object arguments work - https://github.com/godotengine/godot/issues/82718#issuecomment-1744678717
	initialize_networking_signals()
	client_networking.initialize(self)
	server_networking.initialize(self)
	game_network_state["scene_path"] = null

func debug_imgui_handle_network_window(delta: float) -> void:
	ImGui.Begin("Networking")
	if is_server():
		server_networking.debug_imgui_append_server_networking_debug_window(delta)
	else:
		client_networking.debug_imgui_append_client_networking_debug_window(delta)
	ImGui.Text("peers %s" % [ JSON.stringify(peers.keys()) ]);
	ImGui.Text("tick %d" % [ network_tick ]);
	#ImGui.Text("mp_clock %d" % [ multiplayer.get_network_time_msec() ]);
	# TODO: estimated packet loss?
	# TODO: estimated download/receive byte count
	# TODO: estimated

	if multiplayer_mode == MultiplayerMode.STEAM:
		steam_lobby.debug_imgui_append_steam_debug_window(delta)
	ImGui.End()

## Initialize high level multiplayer api signals. Currently only supports "SceneMultiplayer"
func initialize_networking_signals():
	multiplayer.peer_connected.connect(on_peer_connected)
	multiplayer.peer_disconnected.connect(on_peer_disconnected)
	multiplayer.connected_to_server.connect(client_networking.on_client_connected_to_server) # client only
	multiplayer.connection_failed.connect(client_networking.on_client_to_server_connection_failed) # client only
	multiplayer.server_disconnected.connect(client_networking.on_client_disconnected_from_server) # client only
	if scene_multiplayer == null:
		if MultiplayerAPI.get_default_interface() == "SceneMultiplayer":
			scene_multiplayer = multiplayer as SceneMultiplayer
			scene_multiplayer.peer_packet.connect(process_peer_packet)
		elif MultiplayerAPI.get_default_interface() == "LevelMultiplayer":
			Logger.error("TODO: LevelMultiplayer")
		else:
			Logger.error("UNSUPPORTED HIGH LEVEL MULTIPLAYER API!")

func _process(delta):
	multiplayer_poll(delta)
	network_tick_running_delta += delta
	if network_tick_running_delta >= network_tick_rate:
		tick(network_tick_running_delta)
		network_tick_running_delta = 0.0
	calculate_network_metrics(delta)
	debug_imgui_handle_network_window(delta)

## Network tick that occurs on a well defined tick rate.
func tick(delta):
	network_tick += 1
	if GameInstance.networking.is_server():
		server_networking.tick(delta)
	else:
		client_networking.tick(delta)

## The default multiplayer api polling is disabled to allow for a static network tick rate.
func multiplayer_poll(delta):
	if polling_paused: #don't poll while procedurally adding/removing things. temporarily pause multiplayer polling or godot with throw errors...
		return
	if debug_emulate_latency:
		debug_emulate_latency_running_delta += delta
		if debug_emulate_latency_running_delta >= debug_emulate_latency_seconds:
			debug_emulate_latency_running_delta = 0.0
			multiplayer.poll()
	else:
		multiplayer.poll()

func host_game() -> Error:
	game_network_state["scene_path"] = GameInstance.current_level_path
	var new_peer = PeerMetadata.new()
	new_peer.peer_id = 1
	peers[1] = new_peer
	#player_pawn_data[1] = GameInstance.my_pawn_data
	Logger.info("host_game, peer_list: %s" % [JSON.stringify(multiplayer.get_peers())])
	_is_server = true
	if multiplayer_mode == MultiplayerMode.DIRECT_CONNECT:
		return direct_connect_lobby.host_game()
	elif multiplayer_mode == MultiplayerMode.IN_EDITOR:
		return in_editor_lobby.host_game()
	elif multiplayer_mode == MultiplayerMode.STEAM:
		return steam_lobby.host_game()
	elif multiplayer_mode == MultiplayerMode.SINGLE_PLAYER:
		pass # Don't do anything
	else:
		Logger.info("TODO: implement host game for other multiplayer game modes.")
		return Error.FAILED
	return Error.OK

func get_multiplayer_id() -> String:
	# for editor builds, always use the run index
	if OS.has_feature("editor"):
		return str(in_editor_lobby.get_multiplayer_id())
	if multiplayer_mode == Networking.MultiplayerMode.IN_EDITOR:
		return str(in_editor_lobby.get_multiplayer_id())
	else:
		if multiplayer:
			return str(multiplayer.get_unique_id())
	return "u" # u for unknown, keep string short to make logs easier to read

func set_multiplayer_mode(mode: MultiplayerMode):
	multiplayer_mode = mode

func on_peer_connected(peer_id):
	Logger.debug("peer_connected: %d" % [ peer_id ])
	if GameInstance.networking.is_server():
		server_networking.on_peer_connected(peer_id)
	else:
		client_networking.on_peer_connected(peer_id)

func on_peer_disconnected(peer_id):
	if GameInstance.networking.is_server():
		server_networking.on_peer_disconnected(peer_id)
	else:
		client_networking.client_on_peer_disconnected(peer_id)

func process_peer_packet(from_peer_id: int, packet: PackedByteArray):
	if packet.size() == 0:
		Logger.error("got empty peer packet from peer_id: %d" % from_peer_id)
		return
	if GameInstance.networking.is_server():
		server_networking.server_process_peer_packet(from_peer_id, packet)
	else:
		client_networking.client_process_peer_packet(from_peer_id, packet)
	this_second_bytes_received += packet.size()
	total_bytes_received += packet.size()

func send_bytes(bytes: PackedByteArray, id: int = 0, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, channel: int = 0):
	total_bytes_sent += bytes.size()
	this_second_bytes_sent += bytes.size()
	scene_multiplayer.send_bytes(bytes, id, mode, channel)

## The time sent in ping is only used in the ping response sent back from the receiver, so it can be
## a relative time.
func send_ping(peer_id: int):
	var ping_send_ticks_ms = Time.get_ticks_msec()
	Logger.debug("sending: %s, to: %d, initial_ping_send_time: %d" % [
		Networking.NetworkMessageId.keys()[NetworkMessageId.PING], peer_id, ping_send_ticks_ms
	])
	var packet_bytes: PackedByteArray = [
		Networking.NetworkMessageId.PING,
		0x00, 0x00, 0x00, 0x00
	]
	packet_bytes.encode_s32(1, ping_send_ticks_ms)
	send_bytes(packet_bytes, peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func on_receive_ping(from_peer_id: int, packet: PackedByteArray):
	var ping_send_time = packet.decode_s32(1)
	send_ping_response(from_peer_id, ping_send_time)

func send_ping_response(peer_id: int, ping_send_time: int):
	Logger.debug("sending: %s, to: %d, initial_ping_send_time: %d" % [
		Networking.NetworkMessageId.keys()[NetworkMessageId.PING_RESPONSE], peer_id, ping_send_time
	])
	var packet_bytes: PackedByteArray = [
		Networking.NetworkMessageId.PING_RESPONSE,
		0x00, 0x00, 0x00, 0x00
	]
	packet_bytes.encode_s32(1, ping_send_time)
	send_bytes(packet_bytes, peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func add_peer(peer_id):
	Logger.info("add_peer: peer_id: %s" % [str(peer_id)])
	#var player = GameInstance.game_mode.spawn_player(peer_id)
	# TODO: switch from parallel arrays to something cleaner #peer_list.append()
	var peer_metadata: PeerMetadata
	if peers.has(peer_id):
		peer_metadata = peers.get(peer_id)
	else:
		peer_metadata = PeerMetadata.new()
		peer_metadata.peer_id = peer_id
		peers[peer_id] = peer_metadata
	# TODO: notify game mode to spawn player?
	
	GameInstance.game_mode.handle_peer_join(peer_id)
	#GameInstance.game_mode.spawn_player(peer_id)
	#peer_metadata.player = GameInstance.game_mode.spawn_player(peer_id)
	#peer_metadata.player_last_broadcast_position = peer_metadata.player.global_position
	#peer_metadata.player_last_broadcast_rotation_y = peer_metadata.player.global_rotation_degrees.y
	#peer_metadata.player_camera_last_broadcast_rotation_x = peer_metadata.player.camera.global_rotation_degrees.x

func remove_peer(peer_id: int) -> void:
	peers.erase(peer_id)

	# Delete any pawns owned by the peer
	for child in GameInstance.players.get_children():
		if child.name.to_int() == peer_id:
			child.queue_free()

	# TODO: do different stuff for different lobbies?

func remove_all_peers() -> void:
	peers.clear()
	GameInstance.remove_all_players()

func kick_peer(peer_id: int) -> void:
	multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	remove_peer(peer_id)

func set_peer_pawn_data(_peer_id, _color):
	pass
	#if peer_id not in player_pawn_data:
	#	player_pawn_data[peer_id] = {}
	#player_pawn_data[peer_id]["color"] = color

func get_peer_index(peer_id):
	if peers.has(peer_id):
		return peers[peer_id].peer_index
	return null

func player_pawn_exists(peer_id) -> bool:
	if peers.has(peer_id) and peers[peer_id].player != null:
		return true
	return false

func get_player(peer_id):
	if peers.has(peer_id):
		return peers[peer_id].player

## Retrieves a list of peer ids (multiplayer.get_peers() doesn't include the server, which makes it hard to use for games where the server is also a peer)
func get_peer_id_list():
	var peer_ids: Array[int] = []
	for peer_id in peers:
		peer_ids.append(peer_id)
	return peer_ids

func calculate_network_metrics(delta):
	network_tick_second_rollover += delta
	if network_tick_second_rollover >= 1.0:
		network_tick_second_rollover = 0.0
		last_second_bytes_sent = this_second_bytes_sent
		this_second_bytes_sent = 0
		last_second_bytes_received = this_second_bytes_received
		this_second_bytes_received = 0

func reset_networking() -> void:
	var my_id = multiplayer.get_unique_id()
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	server_networking.reset_server_networking()
	peers.clear()
	for child in GameInstance.players.get_children():
		# This is going to require some thought... the player id is the multiplayer.get_unique_id, it will be a different id if they connect to someone else...
		if child.name.to_int() != my_id:
			child.queue_free()

func debug_log() -> void:
	if GameInstance.networking.is_server():
		server_networking.debug_log()
	else:
		client_networking.client_debug_log()
