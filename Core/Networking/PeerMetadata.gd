#extends Resource
# extending nothing extends RefCounted?

class_name PeerMetadata

## Unique identifier per peer, 4 bytes
var peer_id: int = 0
## Incrementing number from 0 - 255, not sure if it'll be used, but could be used to save 3 bytes from peer_id
var peer_index: int = 0
## Ping/latency in ms to the server.
var ping: float = 0.0
## TODO
var last_received_message: int = 0
var server_reconciliations: int = 0
var server_recent_reconciliations: int = 0
# TODO: could keep a rotating buffer of last 16 reconciliation epoch timestamps?

var player: Player

var player_last_broadcast_position: Vector3
var player_last_broadcast_rotation_y: float
var player_camera_last_broadcast_rotation_x: float



func _to_string():
	return "peer_id: %d" % [peer_id]
