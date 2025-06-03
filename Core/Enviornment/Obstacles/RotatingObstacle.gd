extends Node3D

class_name RotatingObstacle

# TODO: simulate based of network tick and server network tick?


@export var rotation_axis: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var revolutions_per_second: float = 0.333333

@export var rotating_node: Node3D

@export var enable_rotate: bool = true
@export var sync_with_server: bool = false
## Uses `GameInstance.network.network_fixed_physics_tick_rate` (5.0 ms as of writing this) when not overridden
@export var sync_rate_override: bool = false
@export var sync_rate_override_rate: float = 0.0

# Can't get this working right... might switch to a "simulate from start state" style model?
@export var client_side_extrapolation: bool = false

var client_sync_next_frame: bool = false
var client_sync_next_frame_rotation: Vector3
var client_sync_next_frame_server_net_tick: int = 0


var sync_rate_ms: float = 0.0
func _ready() -> void:
	rotating_node.orthonormalize()
	if sync_rate_override:
		sync_rate_ms = sync_rate_override_rate
	else:
		sync_rate_ms = GameInstance.networking.network_fixed_physics_tick_rate # TODO: add a slight random offset to prevent stampedes? or are stampedes good because of nagle's algorithm (or is this disabled on game servers?)

var sync_running_delta: float = 0.0
func _physics_process(delta: float) -> void:
	if enable_rotate:
		rotating_node.rotate(rotation_axis, revolutions_per_second * delta)
	if GameInstance.networking.is_server():
		if sync_with_server:
			sync_running_delta += delta
			if sync_running_delta >= sync_rate_ms:
				sync_rotation.rpc(rotating_node.rotation, GameInstance.networking.network_tick)
				sync_running_delta = 0.0
	if client_sync_next_frame:
		rotating_node.rotation = client_sync_next_frame_rotation
		if client_side_extrapolation:
			var net_tick_difference = GameInstance.networking.network_tick - client_sync_next_frame_server_net_tick
			var net_tick_delta = net_tick_difference * GameInstance.networking.network_tick_rate
			Logger.info("rot obs: tick diff: %d, delta: %f, physics frames delta: %f " % [ net_tick_difference, net_tick_delta, (net_tick_delta / 0.016667) ])
			rotating_node.rotate(rotation_axis, revolutions_per_second * net_tick_delta) #(net_tick_delta / 0.016667))
		client_sync_next_frame = false

@rpc("any_peer", "call_remote", "unreliable")
func sync_rotation(new_rotation: Vector3, server_net_tick: int):
	# Can't rotate outside of physics frame, set a flag to rotate next physics frame
	client_sync_next_frame = true
	client_sync_next_frame_rotation = new_rotation
	client_sync_next_frame_server_net_tick = server_net_tick
	Logger.info("sync_rotation: server net tick: %d, my tick: %d" % [server_net_tick, GameInstance.networking.network_tick])
