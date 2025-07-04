extends Node

class_name ClientNetworking


enum ClientSyncState {
	NONE,
	SYNCING_START,
	SYNCING_LEVEL,
	SYNCING_MY_PAWN,
	SYNCING_PEERS,
	SYNCED
}
const client_sync_state_names: Array[String] = [
	"NONE",
	"SYNCING_START",
	"SYNCING_LEVEL",
	"SYNCING_MY_PAWN",
	"SYNCING_PEERS",
	"SYNCED"
]
func ClientSyncState_str(message_id: ClientSyncState):
	return client_sync_state_names[message_id]

var networking: Networking

var done_initial_synchronization = false
var initial_synchronization = {
	"current_state": ClientSyncState.NONE,
	"start_time_ms": 0,
	"max_retries": 5,
	"wait_tick_ms_per_retry": 5000,
	ClientSyncState.NONE: {
		"name": "NONE",
		"send_message_callback": client_debug_log,
		"start_time_ms": 0,
		"last_message_sent_time_ms": 0,
		"retries": 0,
		"next_state": ClientSyncState.SYNCING_START
	},
	ClientSyncState.SYNCING_START: {
		"name": "SYNCING_START",
		"send_message_callback": send_request_initial_game_state,
		"start_time_ms": 0,
		"last_message_sent_time_ms": 0,
		"retries": 0,
		"next_state": ClientSyncState.SYNCING_LEVEL
	},
	ClientSyncState.SYNCING_LEVEL: {
		"name": "SYNCING_LEVEL",
		"send_message_callback": send_request_initial_level_state,
		"start_time_ms": 0,
		"last_message_sent_time_ms": 0,
		"retries": 0,
		"next_state": ClientSyncState.SYNCING_MY_PAWN
	},
	ClientSyncState.SYNCING_MY_PAWN: {
		"name": "SYNCING_MY_PAWN",
		"send_message_callback": send_register_pawn_data,
		"start_time_ms": 0,
		"last_message_sent_time_ms": 0,
		"retries": 0,
		"next_state": ClientSyncState.SYNCING_PEERS
	},
	ClientSyncState.SYNCING_PEERS: {
		"name": "SYNCING_PEERS",
		"send_message_callback": send_all_request_player_initial_state,
		"start_time_ms": 0,
		"last_message_sent_time_ms": 0,
		"retries": 0,
		"next_state": ClientSyncState.SYNCED
	},
	ClientSyncState.SYNCED: {
		"name": "SYNCED",
		"send_message_callback": client_debug_log,
		"start_time_ms": 0,
		"last_message_sent_time_ms": 0,
		"retries": 0,
		"next_state": null
	}
}

var tick_out_of_sync_tolerance: int = 5 # 5 * 15hz ~= 100ms off, might be too wide?
var client_latency_ms: float = 0
var client_latency_history_size: int = 10
var client_latency_history: Array[float] = []
var client_latency_history_index: int = 0
var client_latency_rolling_sum: float = 0.0

var client_ping_running_delta: float = 5.0
var client_process_running_delta: float = 0.0

var server_peer_id_list: Array[int] = []

var pings_sent: int = 0
var pings_received: int = 0

func _ready() -> void:
	client_latency_history_size = 50
	client_latency_history.resize(client_latency_history_size)

func debug_imgui_append_client_networking_debug_window(_delta: float) -> void:
	ImGui.Text("client_id: %s (%d)" % [ networking.get_multiplayer_id(), multiplayer.get_unique_id() ]);
	ImGui.Text("latency: %0.2f ms  (avg: %0.2f ms)" % [ client_latency_ms, get_latency_average() ]);
	ImGui.PlotLines("latency", client_latency_history, client_latency_history_size);
	ImGui.Text("server_peer_id_list: %s" % [ JSON.stringify(server_peer_id_list) ]);
	ImGui.Text("init_sync_state: %s" % [ ClientSyncState_str(initial_synchronization.get("current_state", ClientSyncState.NONE)) ]);
	# TODO: estimated packet loss?

	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		debug_imgui_append_client_enet_statistics()
	# TODO: SteamPeer stats?

func debug_imgui_append_client_enet_statistics() -> void:
	pass
	#var enet_peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	#ImGui.Separator()
	#ImGui.Text("enet")
	#ImGui.Text("last lat: %0.2f ms" % [ enet_peer.get_peer(1).get_statistic(ENetPacketPeer.PeerStatistic.PEER_LAST_ROUND_TRIP_TIME) / 2.0 ])
	#ImGui.Text("mean lat: %0.2f ms" % [ enet_peer.get_peer(1).get_statistic(ENetPacketPeer.PeerStatistic.PEER_ROUND_TRIP_TIME) / 2.0 ])
	#ImGui.Text("pkt loss: %0.2f (scale: %d)" % [ enet_peer.get_peer(1).get_statistic(ENetPacketPeer.PeerStatistic.PEER_PACKET_LOSS), ENetPacketPeer.PACKET_LOSS_SCALE ])
	#ImGui.Separator()

func initialize(p_networking: Networking):
	networking = p_networking

func on_peer_connected(peer_id):
	Log.debug("client:peer_connected: %d" % [ peer_id ])

func client_on_peer_disconnected(peer_id):
	Log.debug("client_on_peer_disconnected: %d" % [ peer_id ])
	networking.remove_peer(peer_id)

func on_client_connected_to_server():
	Log.info("on_client_connected_to_server")
	if networking.multiplayer_mode == Networking.MultiplayerMode.IN_EDITOR:
		await get_tree().create_timer(0.5).timeout
		client_start_sync_process()
	else:
		client_start_sync_process()

func on_client_to_server_connection_failed():
	Log.info("on_client_connection_failed")
	GameInstance.go_to_main_menu_with_error("Failed to connect to server.")

func on_client_disconnected_from_server():
	Log.info("on_client_disconnected_from_server")
	disconnect_from_server()
	GameInstance.go_to_main_menu_with_error("Server disconnected.")

func disconnect_from_server() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	networking.remove_all_peers()
	server_peer_id_list.clear()
	initial_synchronization.clear()
	GameInstance.remove_all_players()

func tick(delta: float) -> void:
	if !done_initial_synchronization:
		client_manage_initial_synchronization()
	else:
		periodic_ping(delta)

func client_process_peer_packet(from_peer_id: int, packet: PackedByteArray):
	var message_id: int = packet[0]
	#Log.info("Got message: %s from peer: %d" % [Networking.NetworkMessageId_str(message_id), from_peer_id])
	match message_id:
		Networking.NetworkMessageId.SERVER_INITIAL_GAME_STATE:
			on_receive_initial_game_state(from_peer_id, packet)
		Networking.NetworkMessageId.SERVER_INITIAL_LEVEL_STATE:
			on_receive_initial_level_state(from_peer_id, packet)
		Networking.NetworkMessageId.SERVER_ACKNOWLEDGE_PLAYER_PAWN_DATA:
			on_receive_server_acknowledge_player_pawn_data(from_peer_id, packet)
		Networking.NetworkMessageId.PEER_INITIAL_STATE:
			on_receive_player_initial_state(from_peer_id, packet)
		Networking.NetworkMessageId.SERVER_BROADCAST_TICK:
			on_receive_server_tick(from_peer_id, packet)
		#Networking.NetworkMessageId.SERVER_BROADCAST_TIME:
		#	on_receive_server_time(from_peer_id, packet)
		Networking.NetworkMessageId.SERVER_BROADCAST_PEER_IDS:
			on_recieve_peer_ids(from_peer_id, packet)
		Networking.NetworkMessageId.SERVER_BROADCAST_PLAYER_MOVEMENT:
			on_recieve_player_movement(from_peer_id, packet)
		Networking.NetworkMessageId.SERVER_SEND_CLIENT_PLAYER_MOVEMENT_RECONCILIATION:
			on_receive_client_player_movement_reconciliation(from_peer_id, packet)
		Networking.NetworkMessageId.PING:
			networking.on_receive_ping(from_peer_id, packet)
		Networking.NetworkMessageId.PING_RESPONSE:
			on_receive_ping_response(from_peer_id, packet)
		_:
			Log.warn("client_process_peer_packet: received unknown message! from: %d, message_id: %d" % [ from_peer_id, message_id ])

func client_sync_change_next_state():
	var current_state: ClientSyncState = initial_synchronization["current_state"]
	var new_state = initial_synchronization[current_state]["next_state"]
	Log.info("client_sync_change_next_state: state: %s, new_state: %s" % [ClientSyncState_str(current_state), ClientSyncState_str(new_state)])
	initial_synchronization["current_state"] = new_state

func client_start_sync_process():
	Log.info("Client starting sync process")
	initial_synchronization["current_state"] = ClientSyncState.SYNCING_START
	initial_synchronization["start_time_ms"] = Time.get_unix_time_from_system()

## Initial synchronization state machine for clients. Sends a specified message to the server
## and awaits a response before moving onto the next state. See `initial_synchronization`
## for which messages are sent and state order.
func client_manage_initial_synchronization() -> void:
	var current_state = initial_synchronization["current_state"]
	if current_state == ClientSyncState.NONE:
		return
	if initial_synchronization[current_state]["start_time_ms"] == 0:
		Log.info("client_manage_initial_synchronization: state: %s, calling: %s " % [ ClientSyncState_str(current_state), initial_synchronization[current_state]["send_message_callback"] ])
		initial_synchronization[current_state]["send_message_callback"].call()
		initial_synchronization[current_state]["start_time_ms"] = Time.get_ticks_msec()
		initial_synchronization[current_state]["last_message_sent_time_ms"]  = Time.get_ticks_msec()
	else:
		if Time.get_ticks_msec() - initial_synchronization[current_state]["last_message_sent_time_ms"] > initial_synchronization["wait_tick_ms_per_retry"]:
			initial_synchronization[current_state]["retries"] += 1
			if initial_synchronization[current_state]["retries"] > initial_synchronization["max_retries"]:
				Log.error("Failed to sync %s %d times, giving up and returning to lobby" % [
					initial_synchronization[current_state]["name"], initial_synchronization["max_retries"]
				])
				initial_synchronization["current_state"] = ClientSyncState.NONE
				GameInstance.go_to_main_menu_with_error("Failed to synchronize with host...")
			else:
				Log.info("client_manage_initial_synchronization: (retry) state: %s, calling: %s " % [ ClientSyncState_str(current_state), initial_synchronization[current_state]["send_message_callback"] ])
				initial_synchronization[current_state]["send_message_callback"].call()
				initial_synchronization[current_state]["last_message_sent_time_ms"]  = Time.get_ticks_msec()
	if current_state == ClientSyncState.SYNCED:
		done_initial_synchronization = true
		client_debug_log()

func periodic_ping(delta):
	client_ping_running_delta += delta
	# If the match has just started and we haven't received enough pings to fill out our rolling latency buffer,
	# send pings a bit more frequently to speed up getting a more accurate average latency.
	if pings_sent < client_latency_history_size:
		if client_ping_running_delta >= 0.5:
			client_ping_running_delta = 0.0
			networking.send_ping(1)
			pings_sent += 1
	else:
		if client_ping_running_delta >= 5.0:
			client_ping_running_delta = 0.0
			networking.send_ping(1)
			pings_sent += 1

func send_register_pawn_data():#pawn_data: Dictionary):
	var pawn_data: Dictionary = GameInstance.my_pawn_data
	var color: Color = pawn_data["color"]
	var packet_bytes: PackedByteArray = [ Networking.NetworkMessageId.CLIENT_REGISTER_PLAYER_PAWN_DATA,
		0x00, 0x00, 0x00, 0x00,
	]
	Log.info("sending: %s" % [ Networking.NetworkMessageId_str(packet_bytes[0]) ])
	packet_bytes.encode_s32(1, color.to_rgba32())
	# TODO: send my pawn data (skins, meta data) needed for the server to spawn my pawn
	networking.send_bytes(packet_bytes, 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func send_request_initial_game_state():
	Log.info("sending: %s" % [ Networking.NetworkMessageId_str(Networking.NetworkMessageId.REQUEST_INITIAL_GAME_STATE) ])
	var packet_bytes: PackedByteArray = [ Networking.NetworkMessageId.REQUEST_INITIAL_GAME_STATE ]
	networking.send_bytes(packet_bytes, 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func send_request_initial_level_state():
	var packet_bytes: PackedByteArray = [ Networking.NetworkMessageId.REQUEST_INITIAL_LEVEL_STATE ]
	Log.info("sending: %s" % [ Networking.NetworkMessageId_str(packet_bytes[0]) ])
	networking.send_bytes(packet_bytes, 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func send_all_request_player_initial_state():
	Log.info("send_all_request_player_initial_state: %s" % [JSON.stringify(server_peer_id_list)])
	for peer_id in server_peer_id_list:
		send_request_player_initial_state(peer_id)

## Send a request to the server for a specific player peer's initial state.
## @param player_peer_id	Peer id to request the initial player state for.
func send_request_player_initial_state(player_peer_id: int) -> void:
	Log.info("sending: %s, data: peer_id_to_request: %d" % [
		Networking.NetworkMessageId_str(Networking.NetworkMessageId.REQUEST_PEER_INITIAL_STATE), player_peer_id
	])
	var packet_bytes: PackedByteArray = [ Networking.NetworkMessageId.REQUEST_PEER_INITIAL_STATE,
		0x00, 0x00, 0x00, 0x00
	]
	packet_bytes.encode_s32(1, player_peer_id)
	networking.send_bytes(packet_bytes, 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

## Called when the client receives a INITIAL_GAME_STATE message from the server. This message
## is received on request.
## @param from_peer_id 	Peer who sent the message (should always be the server peer id).
## @param packet		Message containing initial game state.
func on_receive_initial_game_state(from_peer_id: int, packet: PackedByteArray):
	if from_peer_id != 1:
		Log.error("Received %s message from client %d (expected server!)" % [
			Networking.NetworkMessageId_str(Networking.NetworkMessageId.SERVER_INITIAL_GAME_STATE), from_peer_id
		])
		return
	var offset = 0
	var message_id = packet.decode_u8(offset)
	offset += 1
	var scene_path_string_length = packet.decode_u16(offset)
	offset += 2
	var scene_path_string_bytes = packet.slice(offset, offset + scene_path_string_length)
	offset += scene_path_string_length
	var scene_path_string = scene_path_string_bytes.get_string_from_utf8()
	var peer_count = packet.decode_u8(offset)
	offset += 1
	server_peer_id_list.clear()
	for i in range(0, peer_count):
		var peer_id = packet.decode_s32(offset)
		offset += 4
		server_peer_id_list.append(peer_id)
	Log.info("received: %s, data: server_scene: %s, player_count: %d, peer_list: %s" % [
		Networking.NetworkMessageId_str(message_id), scene_path_string, peer_count,
		JSON.stringify(server_peer_id_list)
	])
	if initial_synchronization["current_state"] == ClientSyncState.SYNCING_START:
		GameInstance.load_and_change_scene(scene_path_string)
		client_sync_change_next_state()

func on_receive_initial_level_state(from_peer_id: int, _packet: PackedByteArray):
	if from_peer_id != 1:
		Log.error("Received %s message from client %d (expected server!)" % [
			Networking.NetworkMessageId_str(Networking.NetworkMessageId.SERVER_INITIAL_LEVEL_STATE), from_peer_id
		])
		return
	#var offset = 0
	#var message_id = packet.decode_u8(offset)
	#offset += 1
	#var scene_path_string_length = packet.decode_u16(offset)
	#offset += 2
	#var map_gen_seed = packet.decode_s64(offset)
	# TODO: process scene specific data
	if initial_synchronization["current_state"] == ClientSyncState.SYNCING_LEVEL:
		client_sync_change_next_state()

func on_receive_server_acknowledge_player_pawn_data(_from_peer_id: int, packet: PackedByteArray):
	# SERVER_ACKNOWLEDGE_PLAYER_PAWN_DATA
	var offset = 0
	var packet_id = packet.decode_u8(offset)
	offset += 1
	var peer_ids_count = packet.decode_u8(offset)
	offset += 1
	server_peer_id_list = []
	for i in range(0, peer_ids_count):
		var peer_id = packet.decode_s32(offset)
		offset += 4
		server_peer_id_list.append(peer_id)
	Log.info("received: %s, data: server_peer_id_list: %s" % [ Networking.NetworkMessageId_str(packet_id), JSON.stringify(server_peer_id_list) ])
	if initial_synchronization["current_state"] == ClientSyncState.SYNCING_MY_PAWN:
		client_sync_change_next_state()

## Initial state of an individual player, sent by the server when requested by client.
## Holds information need to spawn a pawn of the player in the client's world.
## @param from_peer_id 	Should always be server id.
## @param packet 		Message containing an individual players initial state.
func on_receive_player_initial_state(_from_peer_id: int, packet: PackedByteArray):
	# PEER_INITIAL_STATE
	var packet_id = packet.decode_u8(0)
	var peer_id = packet.decode_s32(1)
	#var peer_index = packet.decode_u8(5)
	var pos_x = packet.decode_float(6)
	var pos_y = packet.decode_float(10)
	var pos_z = packet.decode_float(14)
	var peer_position: Vector3 = Vector3(pos_x, pos_y, pos_z)
	var rot_y_mapped = packet.decode_u8(18)
	var rot_y_degrees = (rot_y_mapped * (360.0 / 256)) - 180
	#var color_packed = packet.decode_s32(19)
	#var color: Color = Color(color_packed)

	Log.info("received: %s, data: peer_id: %d, pos: %v, rot.y: %f" % [
		Networking.NetworkMessageId_str(packet_id), peer_id, peer_position, rot_y_degrees
	])

	if networking.player_pawn_exists(peer_id):
		Log.info("on_receive_player_initial_state: player already exists, ignoring message.")
		return

	#print("RECEIVED COLOR: %d %s" % [color_packed, JSON.stringify(color)])
	#networking.player_pawn_data[peer_id] = {}
	#networking.player_pawn_data[peer_id]["color"] = color
	#var color: Color = networking.player_pawn_data[peer_id]["color"]
	#response_packet.encode_s32(22, color.to_rgba32())

	#var player = client_add_peer_player(peer_id, peer_position, rot_y_degrees)
	#networking.player_list.append(player)
	if !networking.peers.has(peer_id):
		networking.peers[peer_id] = PeerMetadata.new()
		networking.peers[peer_id].peer_id = peer_id
	networking.peers[peer_id].player = client_add_peer_player(peer_id, peer_position, rot_y_degrees)

	if initial_synchronization["current_state"] == ClientSyncState.SYNCING_PEERS:
		Log.info("on_receive_player_initial_state: peers: %s" % [ JSON.stringify(networking.peers.keys()) ])
		var done_syncing_peers = true
		for server_peer_id in server_peer_id_list:
			if !networking.peers.has(server_peer_id):
				done_syncing_peers = false
		if done_syncing_peers:
			client_sync_change_next_state()

func client_add_peer_player(peer_id: int, position: Vector3, rot_y_degrees: float) -> Player:
	if multiplayer.is_server(): # The server handles spawning and should never call this function
		return
	Log.info("client_add_peer_player: peer_id: %s" % [str(peer_id)])
	var player = GameInstance.game_mode.player_scene.instantiate()
	player.name = str(peer_id)
	GameInstance.get_node("Players").add_child(player)
	player.set_owner(get_tree().get_edited_scene_root())
	player.global_position = position
	player.network_controller.network_target_position = position
	player.global_rotation_degrees = Vector3(0.0, rot_y_degrees, 0.0)
	player.network_controller.network_target_rotation_degrees_y = rot_y_degrees
	return player

func on_receive_server_tick(_from_peer_id: int, packet: PackedByteArray):
	var message_id = packet.decode_u8(0)
	var server_tick = packet.decode_s32(1)
	# Correct for latency
	var corrected_server_tick = server_tick + int(get_latency_average() * networking.network_tick_rate)
	var net_tick_delta = abs(corrected_server_tick - networking.network_tick)
	Log.info("received: %s, server_tick: %d (corrected: %d), client_tick: %d, delta: %d" % [
		Networking.NetworkMessageId_str(message_id), server_tick, corrected_server_tick, networking.network_tick,
		net_tick_delta
	])
	if net_tick_delta > tick_out_of_sync_tolerance:
		networking.network_tick = corrected_server_tick
		Log.info("CLIENT CORRECTION: net_tick_delta: %d" % net_tick_delta)

#func on_receive_server_time(_from_peer_id: int, packet: PackedByteArray):
	#var server_time_ms = packet.decode_s32(1)
	#var corrected_server_time = server_time_ms + get_latency_average()
	#var time_delta = abs(corrected_server_time - networking.network_time_ms)

func on_recieve_peer_ids(_from_peer_id: int, packet: PackedByteArray):
	# networking.NetworkMessageId.SERVER_BROADCAST_PEER_IDS
	var offset = 0
	var message_id = packet.decode_u8(offset)
	offset += 1
	var player_id_list_count = packet.decode_u8(offset)
	offset += 1
	var new_peer_id_list: Array[int] = []
	for i in range(0, player_id_list_count):
		var player_id = packet.decode_s32(offset)
		offset += 4
		new_peer_id_list.append(player_id)
	Log.info("received: %s, new_peer_id_list: %s" % [
		Networking.NetworkMessageId_str(message_id), JSON.stringify(new_peer_id_list)
	])
	if initial_synchronization["current_state"] == ClientSyncState.SYNCED:
		server_peer_id_list = new_peer_id_list
	for peer_id in new_peer_id_list:
		if !networking.peers.has(peer_id):
			send_request_player_initial_state(peer_id)

func on_recieve_player_movement(_from_peer_id: int, packet: PackedByteArray):
	var peer_id = packet.decode_s32(1) # SERVER_BROADCAST_PLAYER_MOVEMENT
	if peer_id == multiplayer.get_unique_id():
		# got packet for myself, ignore, maybe do some light cheat detection here?
		return
	var pos_x := packet.decode_float(5)
	var pos_y := packet.decode_float(9)
	var pos_z := packet.decode_float(13)
	var peer_position := Vector3(pos_x, pos_y, pos_z)
	var rot_y_mapped := packet.decode_u8(17)
	var rot_y_degrees = (rot_y_mapped * (360.0 / 256)) - 180
	var rot_x_mapped := packet.decode_u8(18)
	var rot_x_degrees = (rot_x_mapped * (360.0 / 256)) - 180
	var input1 := packet.decode_u8(19)
	var movement_status_bitmap := packet.decode_u8(20)
	#Log.info("on_recieve_player_movement: peer: %d, movement_status_bitmap: %d" % [peer_id, movement_status_bitmap])
	var player: Player = networking.get_player(peer_id)
	if player:
		#player.network_controller.on_receive_player_movement(peer_position, rot_y_degrees, rot_x_degrees, input1, movement_status_bitmap)
		player.network_controller.network_target_position = peer_position
		player.network_controller.network_target_rotation_degrees_y = rot_y_degrees
		player.network_controller.network_target_rotation_degrees_x = rot_x_degrees
		player.network_controller.network_inputs1 = input1
		player.network_controller.network_movement_status_bitmap = movement_status_bitmap

func on_receive_client_player_movement_reconciliation(_from_peer_id: int, packet: PackedByteArray):
	var peer_id = packet.decode_s32(1)
	var pos_x := packet.decode_float(5)
	var pos_y := packet.decode_float(9)
	var pos_z := packet.decode_float(13)
	var server_position := Vector3(pos_x, pos_y, pos_z)
	#var rot_y_mapped := packet.decode_u8(17)
	#var rot_y_degrees = (rot_y_mapped * (360.0 / 256)) - 180
	#var rot_x_mapped := packet.decode_u8(18)
	#var rot_x_degrees = (rot_x_mapped * (360.0 / 256)) - 180
	#var input1 := packet.decode_u8(19)
	#var movement_status_bitmap := packet.decode_u8(20)
	var player: Player = networking.get_player(peer_id)
	if player:
		# TODO: incorporate rotation? velocity? inputs? movement status bitmap?
		player.network_controller.client_handle_server_movement_reconciliation(server_position)
	Log.info("on_receive_client_player_movement_reconciliation")
	if peer_id == multiplayer.get_unique_id():
		# TODO: increment reconciliations count?
		pass


func on_receive_ping_response(_from_peer_id: int, packet: PackedByteArray):
	# TODO: consider using this, maybe create a rotating queue of 10 and take average to smooth out weirdnesses.
	#var peer = (ENetMultiplayerPeer)Multiplayer.MultiplayerPeer;
	#return peer.GetPeer(peerID).GetStatistic(ENetPacketPeer.PeerStatistic.PEER_LAST_ROUND_TRIP_TIME);
	# read timestamp in ping, calculate latency from that
	var sent_tick = packet.decode_s32(1)
	var current_tick = Time.get_ticks_msec()
	var ping_delta = current_tick - sent_tick
	pings_received += 1
	Log.debug("received: %s, current_tick: %d, sent_tick: %d, delta: %d" % [
		Networking.NetworkMessageId_str(Networking.NetworkMessageId.PING_RESPONSE), current_tick, sent_tick, ping_delta
	])
	client_latency_ms = ping_delta / 2.0 # round trip ping, not the most accurate, but good enough for now
	# if this is the first ping we've sent and received, flood the latency history for average calculations
	if pings_received == 1:
		seed_initial_latency_history(client_latency_ms)

	if 1 in GameInstance.networking.peers:
		GameInstance.networking.peers[1].ping = client_latency_ms
	# Keep track of a rolling sum for averaging
	client_latency_rolling_sum -= client_latency_history[client_latency_history_index]
	client_latency_rolling_sum += client_latency_ms
	client_latency_history[client_latency_history_index] = client_latency_ms
	client_latency_history_index = (client_latency_history_index + 1) % (client_latency_history_size - 1)

func seed_initial_latency_history(latency: float) -> void:
	for i in range(0, client_latency_history_size):
		client_latency_history[i] = latency
		client_latency_rolling_sum += latency

func get_latency_average() -> float:
	return client_latency_rolling_sum / client_latency_history_size

func client_send_player_movement(peer_id: int, position: Vector3, rotation_degrees_y: float, camera_rotation_degrees_x: float, inputs1: int, movement_states_bitmap: int):
	var packet: PackedByteArray = [ Networking.NetworkMessageId.CLIENT_SEND_PLAYER_MOVEMENT,
		0x00, 0x00, 0x00, 0x00, # peer id
		0x00, 0x00, 0x00, 0x00, # pos.x
		0x00, 0x00, 0x00, 0x00, # pos.y
		0x00, 0x00, 0x00, 0x00, # pos.z
		0x00, # rot.y
		0x00, # camera.rot.x
		0x00, # inputs1
		0x00, # movement_states_bitmap
	]
	packet.encode_s32(1, peer_id)
	packet.encode_float(5, position.x)
	packet.encode_float(9, position.y)
	packet.encode_float(13, position.z)
	# 1 byte y rotation: starting rot_y range: -180 - 180, add 180 to change range to 0 - 360, then multiply by 256/360 to squish range to: 0 - 255
	var rot_y_mapped: int = int((rotation_degrees_y + 180) * (256.0 / 360))
	packet.encode_u8(17, rot_y_mapped)
	# 1 byte y rotation: starting rot_y range: -180 - 180, add 180 to change range to 0 - 360, then multiply by 256/360 to squish range to: 0 - 255
	var rot_x_mapped: int = int((camera_rotation_degrees_x + 180) * (256.0 / 360))
	packet.encode_u8(18, rot_x_mapped)
	packet.encode_u8(19, inputs1)
	packet.encode_u8(20, movement_states_bitmap)
	networking.send_bytes(packet, 1, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)

func client_debug_log() -> void:
	var server_scene_path = networking.game_network_state["scene_path"]
	Log.debug("client_debug_log: my_id: %d, peers: %s, scene_path: %s, sync_state: %s" % [
		int(multiplayer.get_unique_id()), JSON.stringify(multiplayer.get_peers()), str(server_scene_path),
		ClientSyncState_str(initial_synchronization.get("current_state", ClientSyncState.NONE))
	])
