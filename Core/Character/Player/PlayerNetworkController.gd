extends Node3D

class_name PlayerNetworkController

@onready var player: Player = $".."

@onready var owning_multiplayer_id: int = 0

var last_sent_location: Vector3
var last_sent_rotation_degrees_y: float
var last_sent_rotation_degrees_x: float
var last_sent_velocity: Vector3
var last_sent_movement_status_bitmap: int



## The locally controlled player (controlled by the local game instance) is ready
func authoritative_player_ready():
	Logger.info("%s:authoritative_player_ready" % [player.name])
	player.camera.current = true
	player.third_person.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.crouch_shapecast.add_exception($".")
	player.fade_from_black(5.0)
	player.toggle_pause() # for debug testing on a single machine, best to start paused so you can move the windows around

## A peer player (not controlled by the local game instance) is ready
func peer_player_ready():
	Logger.info("%s:peer_player_ready" % [player.name])
	player.camera.current = false
	player.first_person.visible = false
	player.third_person.visible = true
	player.hud.hide()
	Logger.info("spawned %s's peer, sending rpc to start syncing" % [player.name])
	player.notify_peer_their_player_is_spawned.rpc_id(str(player.name).to_int(), player.multiplayer.get_unique_id())

const INPUTS1_FORWARD_MASK: int = 1 	# 1 << 0
const INPUTS1_BACK_MASK: int = 2 		# 1 << 1
const INPUTS1_RIGHT_MASK: int = 4		# 1 << 2
const INPUTS1_LEFT_MASK: int = 8		# 1 << 3
const INPUTS1_CROUCH_MASK: int = 16		# 1 << 4
const INPUTS1_SPRINT_MASK: int = 32		# 1 << 5
const INPUTS1_LEAN_RIGHT_MASK: int = 64		# 1 << 6
const INPUTS1_LEAN_LEFT_MASK: int = 128		# 1 << 7

func build_inputs1() -> int:
	var inputs1 = 0
	if player.last_input_dir.y > 0.0:
		inputs1 += INPUTS1_FORWARD_MASK
	elif player.last_input_dir.y < 0.0:
		inputs1 += INPUTS1_BACK_MASK
	if player.last_input_dir.x > 0.0:
		inputs1 += INPUTS1_RIGHT_MASK
	elif player.last_input_dir.x < 0.0:
		inputs1 += INPUTS1_LEFT_MASK
	if player.is_crouching:
		inputs1 += INPUTS1_CROUCH_MASK
	if player.is_sprinting:
		inputs1 += INPUTS1_SPRINT_MASK
	if player.is_leaning_right:
		inputs1 += INPUTS1_LEAN_RIGHT_MASK
	if player.is_leaning_left:
		inputs1 += INPUTS1_LEAN_LEFT_MASK
	#Logger.info("%f,%f - %d" % [last_input_dir.x, last_input_dir.y, inputs1])
	return inputs1

const MOVEMENT_STATES_ON_GROUND_MASK: int = 1 	# 1 << 0

func build_movement_states_bitmap():
	var movement_state_bitmap = 0
	if player.is_on_floor():
		movement_state_bitmap += MOVEMENT_STATES_ON_GROUND_MASK
	return movement_state_bitmap

func remote_pawn_physics_process(_delta):
	if is_multiplayer_authority():
		return
	if player.global_position != player.network_target_position:
		if player.interpolate_networked_movement:
			player.global_position = lerp(player.global_position, player.network_target_position, player.network_movement_interpolation_rate)
		else:
			player.global_position = player.network_target_position
	if player.global_rotation_degrees.y != player.network_target_rotation_degrees_y:
		player.global_rotation_degrees.y = player.network_target_rotation_degrees_y
	if player.camera.global_rotation_degrees.x != player.network_target_rotation_degrees_x:
		player.camera.global_rotation_degrees.x = player.network_target_rotation_degrees_x

	var forward = player.network_inputs1 & INPUTS1_FORWARD_MASK
	var back =  player.network_inputs1 & INPUTS1_BACK_MASK
	var right = player.network_inputs1 & INPUTS1_RIGHT_MASK
	var left = player.network_inputs1 & INPUTS1_LEFT_MASK
	var sprint = true if (player.network_inputs1 & INPUTS1_SPRINT_MASK > 0) else false
	var input_crouch = true if (player.network_inputs1 & INPUTS1_CROUCH_MASK > 0) else false
	#var lean_right = player.network_inputs1 & INPUTS1_LEAN_RIGHT_MASK
	#var lean_left = player.network_inputs1 & INPUTS1_LEAN_LEFT_MASK

	var is_on_ground = true if (player.network_movement_status_bitmap & MOVEMENT_STATES_ON_GROUND_MASK > 0) else false

	var ground_locomotion_blend_position = Vector2(0.0, 0.0)
	if forward:
		ground_locomotion_blend_position.y = 1.0 # -z is forward
	elif back:
		ground_locomotion_blend_position.y = -1.0
	if right:
		ground_locomotion_blend_position.x = 1.0
	elif left:
		ground_locomotion_blend_position.x = -1.0

	if !sprint:
		ground_locomotion_blend_position = ground_locomotion_blend_position * 0.5

	#third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/on_ground", is_on_floor())
	#if (!is_on_ground and player.third_person_animation_tree.get("parameters/LocomotionStateMachine/conditions/jump")):
	#	player.third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/jump", false)

	player.third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/walk", is_on_ground and !input_crouch)
	player.third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/on_ground", is_on_ground)
	player.third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/crouch", input_crouch)

	player.third_person_animation_tree.set("parameters/LocomotionStateMachine/WalkBlendSpace2D/blend_position", ground_locomotion_blend_position)
	player.third_person_animation_tree.set("parameters/LocomotionStateMachine/CrouchBlendSpace2D/blend_position", ground_locomotion_blend_position)
	# TODO: how to set falling blend position?
	# third_person_animation_tree["parameters/LocomotionStateMachine/FallingBlendSpace2D/blend_position"] = ???
	player.last_global_position = player.global_position

var send_move_data_ticks: int = 0
var sent_one_extra_no_move_data_packet: bool = false
func client_send_move_data():
	var inputs1 = build_inputs1()
	var movement_states_bitmap = build_movement_states_bitmap()
	if global_position == last_sent_location \
			and global_rotation_degrees.y == last_sent_rotation_degrees_y \
			and global_rotation_degrees.x == last_sent_rotation_degrees_x \
			and player.velocity == last_sent_velocity \
			and movement_states_bitmap == last_sent_movement_status_bitmap \
			and sent_one_extra_no_move_data_packet == true:
		# player hasn't moved, don't waste the bandwidth
		return

	if global_position != last_sent_location:
		sent_one_extra_no_move_data_packet = false

	if sent_one_extra_no_move_data_packet == false and global_position == last_sent_location:
		#print("sent sent_one_extra_no_move_data_packet")
		sent_one_extra_no_move_data_packet = true
		#inputs1 = inputs1 & 0x11110000 # zero out movement (forward/back/left/right) bits
		inputs1 = 0

	GameInstance.networking.client_networking.client_send_player_movement(name.to_int(),
		player.global_position, player.global_rotation_degrees.y, player.camera.global_rotation_degrees.x,
		inputs1, movement_states_bitmap)
	#Logger.info("global_position: %v" % [ global_position ])
	last_sent_location = global_position
	last_sent_rotation_degrees_y = global_rotation_degrees.y
	last_sent_velocity = player.velocity
	last_sent_movement_status_bitmap = movement_states_bitmap

func client_handle_server_movement_reconciliation(server_position: Vector3):
	player.position = server_position
	pass
