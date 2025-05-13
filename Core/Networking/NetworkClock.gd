extends Node

class_name NetworkClock

#signal latency_calculated_event_handler(var latency_average: int)

@export var sample_size: int = 11
@export var sample_rate_ms: float = 500
@export var min_latency: int = 20

var clock: int = 0
var immediate_latency: int = 0
var average_latency: int = 0
var offset: int = 0
var jitter: int = 0
var last_offset: int = 0
var decimal_collector: float = 0

var offset_values: Array[int] = []
var latency_values: Array[int] = []

var _multiplayer: SceneMultiplayer


# Called when the node enters the scene tree for the first time.
func _ready():
	_multiplayer = get_tree().get_multiplayer() as SceneMultiplayer
	#_multiplayer.peer_packet.connect(on_packet_received)
	# TODO: add a timer?

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	## adjust_clock(delta)
	## display_debug_information()
	#pass

func on_packet_received(id: int, data: PackedByteArray):
	if data.size() != 0:
		if data[0] == Networking.NetworkingMessages.TIME_SYNC:
			time_sync_received(id, data)

func time_sync_received(_id: int, _data: PackedByteArray):
	# TODO: read sync client time and sync server time from data
	var sync_client_time = 0
	var sync_server_time = 0
	@warning_ignore("integer_division")
	immediate_latency = (Time.get_ticks_msec() - sync_client_time) / 2
	offset = (sync_server_time - clock) + immediate_latency
	offset_values.append(offset)
	latency_values.append(immediate_latency)
	
	if offset_values.size() >= sample_size:
		offset_values.sort()
		latency_values.sort()
		var offset_average = filter_and_smooth(offset_values, min_latency)
		jitter = latency_values[latency_values.size() - 1] - latency_values[0]
		average_latency = filter_and_smooth(latency_values, min_latency)
		# emmit signal latency calculated
		last_offset = offset_average
		
		offset_values.clear()
		latency_values.clear()

func filter_and_smooth(samples: Array[int], min_value: int):
	sample_size = samples.size()
	@warning_ignore("integer_division")
	var middle_value = samples[samples.size() / 2]
	var running_sum = 0
	for i in range(0, samples.size()):
		var value = samples[i]
		# Filter out values too low (why? how does this work with lan or split screen?)
		# Filter out values too high (why 2 * middle_value?)
		if value > (2 * middle_value) && value > min_value:
			samples.remove_at(i)
			sample_size -= 1
		else:
			running_sum += value
	@warning_ignore("integer_division")
	return running_sum / samples.size()

func adjust_clock(delta: float):
	var ms_delta: int = int(delta * 1000.0)
	clock += ms_delta + last_offset
	
	decimal_collector += (delta * 1000.0) - ms_delta
	if decimal_collector >= 1.0:
		clock += 1
		decimal_collector -= 1.0
	last_offset = 0

#func time_sync_received(id: int, data: PackedByteArray):
#	
#	pass
