extends Node

class_name ServerNetworking


var networking: Networking

var player_movement_sync_tick_rate: float = 0.066666 # 15 fps # 0.0333333 # 30 fps
var player_movement_sync_running_delta: float = 0.0

func debug_imgui_append_server_networking_debug_window(_delta: float) -> void:
	ImGui.Text("server");

func initialize(p_networking: Networking):
	networking = p_networking

func tick(delta: float) -> void:
	server_synchronize_player_movement(delta)
	if networking.network_tick % 200 == 0: # at 30fps net tick: .03333 * 200 = 6.6666 seconds? seems long....
		server_broadcast_network_tick(networking.network_tick)

func on_peer_connected(_peer_id):
	pass

func server_add_peer(peer_id):
	networking.add_player(peer_id)

func on_peer_disconnected(peer_id):
	Logger.debug("peer_disconnected: %d" % [ peer_id ])
	networking.remove_peer(peer_id)

func process_peer_packet(from_peer_id: int, packet: PackedByteArray):
	var message_id: int = packet[0]
	#Logger.info("Got message: %s from peer: %d" % [NetworkMessageId_str(message_id), from_peer_id])
	if message_id == Networking.NetworkMessageId.REQUEST_INITIAL_GAME_STATE:
		send_initial_game_state(from_peer_id)
	elif message_id == Networking.NetworkMessageId.REQUEST_INITIAL_LEVEL_STATE:
		send_initial_scene_state(from_peer_id)
	elif message_id == Networking.NetworkMessageId.CLIENT_REGISTER_PLAYER_PAWN_DATA:
		on_receive_register_player_pawn_data(from_peer_id, packet)
	elif message_id == Networking.NetworkMessageId.REQUEST_PEER_INITIAL_STATE:
		on_receive_request_peer_initial_state(from_peer_id, packet)
	elif message_id == Networking.NetworkMessageId.CLIENT_SEND_PLAYER_MOVEMENT:
		on_receive_client_player_movement(from_peer_id, packet)
	elif message_id == Networking.NetworkMessageId.PING:
		on_receive_ping(from_peer_id, packet)

## Initial game state sent by the server to the client when requested.
## Message contents:
##  * u8 - Message id (REQUEST_INITIAL_LEVEL_STATE)
##  * u16 - Level scene path string length
##  * string - Level scene path string
##  * u8 - Player count
##  * Array[u8] - Player peer ids
## @param peer_id	Peer id to send the initial game state to.
func send_initial_game_state(peer_id: int):
	var offset = 1
	var packet: PackedByteArray = [ Networking.NetworkMessageId.SERVER_INITIAL_GAME_STATE, 0x00, 0x00 ]
	var server_scene_path: String = networking.game_network_state["scene_path"]
	var scene_path_bytes: PackedByteArray = server_scene_path.to_utf8_buffer()
	packet.encode_u16(offset, scene_path_bytes.size()) # write to bytes 1 and 2
	offset += 2
	packet.append_array(scene_path_bytes) # bytes 3 and after
	offset += scene_path_bytes.size()
	packet.resize(offset + 1 + (networking.player_id_list.size() * 4))
	packet.encode_u8(offset, (networking.player_id_list.size()))
	offset += 1

	for i in range(0, networking.player_id_list.size()):
		packet.encode_s32(offset, networking.player_id_list[i])
		offset += 4
	Logger.info("sending: %s to %s" % [ Networking.NetworkMessageId_str(packet[0]), str(peer_id) ])
	networking.send_bytes(packet, peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func send_initial_scene_state(peer_id: int):
	var packet: PackedByteArray = [ Networking.NetworkMessageId.SERVER_INITIAL_LEVEL_STATE, 
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  # server seed
	]
	#Logger.info("sending: %s" % [ Networking.NetworkMessageId_str(packet[0]),
		#0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	#])
	var server_seed: int = GameInstance.scene_generation_seed
	packet.encode_s64(1, server_seed)
	# TODO: add scene specific data to synchronize
	Logger.info("sending: %s to %s" % [ Networking.NetworkMessageId_str(packet[0]), str(peer_id) ])
	networking.send_bytes(packet, peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func on_receive_register_player_pawn_data(from_peer_id: int, request_packet: PackedByteArray):
	# TODO: save player pawn data
	var message_id: int = request_packet.decode_u8(0)
	var color_packed_rgba32: int = request_packet.decode_s32(1)
	var color = Color(color_packed_rgba32)
	
	# TODO: set networking peer 
	networking.set_peer_pawn_data(from_peer_id, color)
	#packet_bytes.encode_s32(1, color.to_rgba32())
	Logger.info("received: %s, from: %d" % [ 
		Networking.NetworkMessageId_str(message_id), from_peer_id
	])
	server_add_peer(from_peer_id)
	send_acknowledge_register_player_pawn_data(from_peer_id)
	server_broadcast_player_id_list()
	# TODO: send broadcast updating player_id_list
	pass

func send_acknowledge_register_player_pawn_data(peer_id: int):
	var packet: PackedByteArray = [ Networking.NetworkMessageId.SERVER_ACKNOWLEDGE_PLAYER_PAWN_DATA, 0x00 ]
	packet.resize(1 + 1 + (networking.player_id_list.size() * 4))
	var offset: int = 1
	packet.encode_u8(offset, (networking.player_id_list.size()))
	offset += 1
	for i in range(0, networking.player_id_list.size()):
		packet.encode_s32(offset, networking.player_id_list[i])
		offset += 4
	networking.send_bytes(packet, peer_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)
	pass

## 
func on_receive_request_peer_initial_state(from_peer_id: int, request_packet: PackedByteArray):
	var peer_id_being_requested = request_packet.decode_s32(1)
	Logger.info("received: %s, from: %d, data: peer_state_requested: %d" % [ 
		Networking.NetworkMessageId_str(Networking.NetworkMessageId.REQUEST_PEER_INITIAL_STATE), from_peer_id, peer_id_being_requested
	])
	send_player_initial_state(peer_id_being_requested, from_peer_id)

## Send the players initial state from the client to the server.
func send_player_initial_state(peer_id: int, peer_id_to_send_to: int):
	var peer_index = networking.get_player_index(peer_id)
	var player_position: Vector3 = networking.player_list[peer_index].global_position
	var rot_y_mapped: int = int((networking.player_list[peer_index].global_rotation_degrees.y + 180) * (256.0 / 360))
	Logger.info("sending: %s, to: %d, data: peer: %d (%d), position: %.2v, rot_degs.y: %f" % [ 
		Networking.NetworkMessageId_str(Networking.NetworkMessageId.PEER_INITIAL_STATE), peer_id_to_send_to, 
		peer_id, peer_index, player_position, rot_y_mapped
	])
	var response_packet: PackedByteArray = [ Networking.NetworkMessageId.PEER_INITIAL_STATE, 
		0x00, 0x00, 0x00, 0x00, # peer id
		0x00, # peer index
		0x00, 0x00, 0x00, 0x00, # pos.x
		0x00, 0x00, 0x00, 0x00, # pos.y
		0x00, 0x00, 0x00, 0x00, # pos.z
		0x00, # rot.y
		0x00, 0x00, 0x00, 0x00 # player pawn data (just color for now)
	]
	response_packet.encode_s32(1, peer_id)
	response_packet.encode_u8(5, peer_index)
	response_packet.encode_float(6, player_position.x)
	response_packet.encode_float(10, player_position.y)
	response_packet.encode_float(14, player_position.z)
	response_packet.encode_u8(18, rot_y_mapped)
	var color: Color = networking.player_pawn_data[peer_id]["color"]
	response_packet.encode_s32(19, color.to_rgba32())
	#print("SENT COLOR: %d %s" % [color.to_rgba32(), JSON.stringify(color)])
	# TODO: send additional data, player scene, skins, position, metadata?
	networking.send_bytes(response_packet, peer_id_to_send_to, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

## Server on receiving a client player movement packet
func on_receive_client_player_movement(from_peer_id: int, packet: PackedByteArray):
	#var peer_id = packet.decode_s32(1)
	var pos_x = packet.decode_float(5)
	var pos_y = packet.decode_float(9)
	var pos_z = packet.decode_float(13)
	var new_position = Vector3(pos_x, pos_y, pos_z)
	var rot_y_mapped = packet.decode_u8(17)
	var rot_y_degrees = (rot_y_mapped * (360.0 / 256)) - 180
	var rot_x_mapped = packet.decode_u8(18)
	var rot_x_degrees = (rot_x_mapped * (360.0 / 256)) - 180
	var inputs1 = packet.decode_u8(19)
	var movement_status_bitmap = packet.decode_u8(20)
	var player = networking.get_player(from_peer_id)
	player.network_target_position = new_position
	player.network_target_rotation_degrees_y = rot_y_degrees
	player.network_target_rotation_degrees_x = rot_x_degrees
	player.network_inputs1 = inputs1
	player.network_movement_status_bitmap = movement_status_bitmap

func on_receive_ping(from_peer_id: int, packet: PackedByteArray):
	var ping_send_time = packet.decode_s32(1)
	
	var time_delta = Time.get_ticks_msec() - ping_send_time
	# TODO: store time delta
	
	networking.send_ping_response(from_peer_id, ping_send_time)

## 
func server_synchronize_player_movement(delta: float) -> void:
	player_movement_sync_running_delta += delta
	if player_movement_sync_running_delta >= player_movement_sync_tick_rate:
		player_movement_sync_running_delta = 0.0
		# TODO: send all player movements in a single packet, less overhead from many small packets
		#print("player_list size: %d" % networking.player_list.size())
		for i in range(0, networking.player_list.size() - 1):
			if (	networking.player_list[i].global_position == networking.player_last_broadcast_position[i] \
					and networking.player_list[i].global_rotation_degrees.y == networking.player_last_broadcast_rotation_degrees_y[i] \
					and networking.player_list[i].global_rotation_degrees.x == networking.player_last_broadcast_rotation_degrees_x[i] \
				):
				# Player hasn't moved, save the bandwidth
				continue
			else:
				server_broadcast_player_movement(networking.player_list[i].get_multiplayer_authority())
				networking.player_last_broadcast_position[i] = networking.player_list[i].global_position
				networking.player_last_broadcast_rotation_degrees_y[i] = networking.player_list[i].global_rotation_degrees.y
				networking.player_last_broadcast_rotation_degrees_x[i] = networking.player_list[i].global_rotation_degrees.x

func server_broadcast_network_tick(network_tick: int):
	var packet: PackedByteArray = [ networking.NetworkMessageId.SERVER_BROADCAST_TICK, 
		0x00, 0x00, 0x00, 0x00 ]
	packet.encode_s32(1, network_tick) # is this an int? maybe make it 8 bytes or unsigned?
	networking.send_bytes(packet, 0, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, 0)

func server_broadcast_player_id_list():
	var packet: PackedByteArray = [ networking.NetworkMessageId.SERVER_BROADCAST_PLAYER_ID_LIST, 
		0x00 ]
	#Logger.info("server sending: %s" % [])
	packet.resize(1 + 1 + (networking.player_id_list.size() * 4))
	var offset: int = 1
	packet.encode_u8(offset, (networking.player_id_list.size()))
	offset += 1
	for i in range(0, networking.player_id_list.size()):
		packet.encode_s32(offset, networking.player_id_list[i])
		offset += 4
	networking.send_bytes(packet, 0, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func server_broadcast_all_player_movement():
	var packet: PackedByteArray = [ networking.NetworkMessageId.SERVER_BROADCAST_PLAYER_MOVEMENT ]
	#packet.resize(1 + 13 * networking.player_list.size())
	var offset = 1
	for i in range(0, networking.player_list.size() - 1):
		if (	networking.player_list[i].global_position == networking.player_last_broadcast_position[i] \
				and networking.player_list[i].global_rotation_degrees.y == networking.player_last_broadcast_rotation_degrees_y[i]
			):
			# Player hasn't moved, save the bandwidth
			break
		else:
			pass
			packet.resize(offset + 13)
			packet.encode_s32(offset, networking.player_list[i].get_multiplayer_authority())
			server_broadcast_player_movement(networking.player_list[i].get_multiplayer_authority())
			networking.player_last_broadcast_position[i] = networking.player_list[i].global_position
			networking.player_last_broadcast_rotation_degrees_y[i] = networking.player_list[i].global_rotation_degrees.y
			networking.player_last_broadcast_rotation_degrees_x[i] = networking.player_list[i].camera.global_rotation_degrees.x
			networking.send_bytes(packet, 0, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)
	pass

func server_broadcast_player_movement(peer_id: int):
	var packet: PackedByteArray = [ networking.NetworkMessageId.SERVER_BROADCAST_PLAYER_MOVEMENT, 
		0x00, 0x00, 0x00, 0x00, # peer id (TODO: sync indicies and just send 1 byte player index)
		0x00, 0x00, 0x00, 0x00, # pos.x
		0x00, 0x00, 0x00, 0x00, # pos.y
		0x00, 0x00, 0x00, 0x00, # pos.z
		0x00, # rot.y
		0x00, # rot.x
		#0x00, 0x00, 0x00, 0x00, # velocity
		#0x00, 0x00, 0x00, 0x00, # input.x
		#0x00, 0x00, 0x00, 0x00, # input.y
		0x00, # inputs1
		0x00 # movement status bitmap
		# TODO: crouching/sprinting (not jumping or spontaneous actions, those can be rpcs)
	]
	var peer_index = networking.get_player_index(peer_id)
	if peer_index == null:
		return
	#Logger.info("server_broadcast_player_movement: player_list: %s, id_list: %s" % [JSON.stringify(networking.player_list), JSON.stringify(networking.player_id_list)])
	var player_position: Vector3 = networking.player_list[peer_index].global_position
	packet.encode_s32(1, peer_id)
	packet.encode_float(5, player_position.x)
	packet.encode_float(9, player_position.y)
	packet.encode_float(13, player_position.z)
	# 1 byte y rotation: starting rot_y range: -180 - 180, add 180 to change range to 0 - 360, then multiply by 256/360 to squish range to: 0 - 255
	var rot_y_mapped: int = int((networking.player_list[peer_index].global_rotation_degrees.y + 180) * (256.0 / 360))
	packet.encode_u8(17, rot_y_mapped)
	# 1 byte x rotation: starting rot_x range: -180 - 180, add 180 to change range to 0 - 360, then multiply by 256/360 to squish range to: 0 - 255
	# TODO: get camera x rotation
	var rot_x_mapped: int = int((networking.player_list[peer_index].camera.global_rotation_degrees.x + 180) * (256.0 / 360))
	packet.encode_u8(18, rot_x_mapped)
	packet.encode_u8(19, networking.player_list[peer_index].network_controller.build_inputs1())
	packet.encode_u8(20, networking.player_list[peer_index].network_controller.build_movement_states_bitmap())
	#Logger.info("sending: %s, peer: %d, pos: %v, rot_y: %f, rot_x: %f" % [
		#Networking.NetworkMessageId_str(networking.NetworkMessageId.SERVER_BROADCAST_PLAYER_MOVEMENT),
		#peer_id, player_position, networking.player_list[peer_index].global_rotation_degrees.y,
		#networking.player_list[peer_index].global_rotation_degrees.x
	#])
	networking.send_bytes(packet, 0, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, 0)

func reset_server_networking() -> void:
	
	pass

func debug_log() -> void:
	var peers_string: String = JSON.stringify(multiplayer.get_peers())
	var server_scene_path = networking.game_network_state["scene_path"]
	#if networking.game_network_state["scene_path"] != null:
	#	server_scene_path = networking.game_network_state["scene_path"]
	Logger.info("server: my_id: %d, peers: %s, scene_path: %s, player_id_list: %s, player_list: %s, player_pawn_data: %s" % [
		int(multiplayer.get_unique_id()), String(peers_string), str(server_scene_path),
		JSON.stringify(networking.player_id_list), JSON.stringify(networking.player_list),
		JSON.stringify(networking.player_pawn_data)
	])
