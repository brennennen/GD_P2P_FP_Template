#extends Resource
# extending nothing extends RefCounted?

class_name PeerMetadata

var peer_id: int = 0
var ping: float = 999.999
var last_received_message: int = 0

func _to_string():
	return "peer_id: %d" % [peer_id]
