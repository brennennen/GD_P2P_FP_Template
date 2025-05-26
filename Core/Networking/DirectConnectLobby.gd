extends Node

class_name DirectConnectLobby

var port: int = 7000
var password: String = ""
var max_connections: int = 4
var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var networking: Networking

func setup(node_name: String, new_networking: Networking):
	name = node_name
	networking = new_networking

func host_game() -> Error:
	Logger.info("Creating direct connect server on: %d, max_connections: %d" % [port, max_connections])
	var error = enet_peer.create_server(port, max_connections)
	if error:
		Logger.error("direct connect create_game error: %d" % error)
		return error
	multiplayer.multiplayer_peer = enet_peer
	return Error.OK

func join_game(address: String = "127.0.0.1", join_port: int = 7000) -> Error:
	var peer = ENetMultiplayerPeer.new()
	Logger.info("Creating direct connect join client with address: %s, port: %d" % [address, join_port])
	var error = peer.create_client(address, join_port)
	peer.get_peer(1).set_timeout(0, 0, 3000) # 3 second timeout # TODO: figure out what 1 is? does that need to be multiplyer id?
	if error:
		Logger.error("join_game error: (%d) %s" % [error, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	return Error.OK

@rpc("authority", "call_remote", "reliable", 0)
func transfer_lobby_data(lobby_data: Dictionary):
	Logger.info("peer %d got lobby_data: %s" % [ multiplayer.get_unique_id(), JSON.stringify(lobby_data)])
