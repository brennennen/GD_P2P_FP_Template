extends Node3D

class_name PlayerNetworkController

@onready var player: Player = $".."

@onready var debug_label_3d = $DebugLabel3D

var last_sent_location: Vector3
var last_sent_rotation_degrees_y: float
var last_sent_rotation_degrees_x: float
var last_sent_velocity: Vector3
var last_sent_inputs1: int
var last_sent_movement_status_bitmap: int

var interpolate_networked_movement: bool = true
var network_movement_interpolation_rate: float = 0.5

var network_target_position: Vector3
var server_last_valid_target_position: Vector3
var server_last_valid_on_ground_target_position: Vector3
var network_target_rotation_degrees_y: float
var network_target_rotation_degrees_x: float
var network_inputs1: int
var network_movement_status_bitmap: int


func _ready() -> void:
	# Needs to interpolate/reach the target by the next sync packet (received every network tick)
	network_movement_interpolation_rate = (1.0 / Engine.physics_ticks_per_second) / GameInstance.networking.network_tick_rate
	network_movement_interpolation_rate *= 0.8 # still needs to be tinkered with emperically
	set_debug_label_3d()

func set_debug_label_3d():
	var net_auth_mode = "???"
	if !is_multiplayer_authority():
		if str(name).to_int() == 1:
			net_auth_mode = "Authority"
		elif GameInstance.networking.is_server():
			net_auth_mode = "Autonomous"
		else:
			net_auth_mode = "Simulated"
	debug_label_3d.text = "%s\n%s" % [ str(player.name).to_int(), net_auth_mode]

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

func local_controlled_pawn_physics_process(_delta):
	network_inputs1 = build_inputs1()
	network_movement_status_bitmap = build_movement_states_bitmap()

func remote_pawn_physics_process(_delta):
	if is_multiplayer_authority():
		return
	if player.global_position != network_target_position:
		if interpolate_networked_movement:
			# TODO: don't lerp? slerp or bicubic interpolation?
			player.global_position = lerp(player.global_position, network_target_position, network_movement_interpolation_rate)
		else:
			player.global_position = network_target_position
	player.velocity = (player.global_position - player.last_global_position) / _delta #0.06667
	if player.global_rotation_degrees.y != network_target_rotation_degrees_y:
		player.global_rotation_degrees.y = network_target_rotation_degrees_y
	if player.camera.global_rotation_degrees.x != network_target_rotation_degrees_x:
		player.camera.global_rotation_degrees.x = network_target_rotation_degrees_x

	var forward := bool(network_inputs1 & INPUTS1_FORWARD_MASK)
	var back :=  bool(network_inputs1 & INPUTS1_BACK_MASK)
	var right := bool(network_inputs1 & INPUTS1_RIGHT_MASK)
	var left := bool(network_inputs1 & INPUTS1_LEFT_MASK)
	var sprint := bool(network_inputs1 & INPUTS1_SPRINT_MASK)
	var input_crouch := bool(network_inputs1 & INPUTS1_CROUCH_MASK)
	#var lean_right = network_inputs1 & INPUTS1_LEAN_RIGHT_MASK
	#var lean_left = network_inputs1 & INPUTS1_LEAN_LEFT_MASK

	var is_on_ground := bool(network_movement_status_bitmap & MOVEMENT_STATES_ON_GROUND_MASK)

	# Rather than basing animation data on movement inputs, could also just use movement vector since last packet
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

	#Logger.debug("f: %s, b: %s, r: %s, l: %s " % [str(forward), str(back), str(right), str(left)])

	#third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/on_ground", is_on_floor())
	#if (!is_on_ground and player.third_person_animation_tree.get("parameters/LocomotionStateMachine/conditions/jump")):
	#	player.third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/jump", false)
	if player.movement_controller.movement_mode == PlayerMovementController.MovementMode.HORSE_RIDING:
		if player.horse_mount:

			#Logger.info("y: %f" % [ground_locomotion_blend_position.y])

			#player.third_person_animation_tree.set("parameters/LocomotionStateMachine/WalkBlendSpace2D/blend_position", player.velocity.length())
			if back:
				player.horse_mount.animation_tree.set("parameters/LocomotionStateMachine/LocomotionSpace1D/blend_position", -1.0)
			else:
				if player.velocity.length() != 0.0:
					player.horse_mount.animation_tree.set("parameters/LocomotionStateMachine/LocomotionSpace1D/blend_position", player.velocity.length() / player.movement_controller.horse_gallop_speed)
	else:
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
			and inputs1 == last_sent_inputs1 \
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
	last_sent_inputs1 = inputs1
	last_sent_movement_status_bitmap = movement_states_bitmap

var continuous_floor_collisions: int = 0
var continuous_corner_collisions: int = 0

## Server on receiving a client player movement packet
## Whenever the server is notified a client's pawn moved, try and simulate that move on the server
## to make sure the client is not clipping through geometry or fly/move speed hacking. Reconcile the
## client's position if it is out of a tolerance of where the server thinks the player should be.
func server_handle_client_pawn_movement(_peer_id: int, new_position: Vector3, rot_y_degrees: float, rot_x_degrees: float, inputs1: int, movement_status_bitmap: int):
	# If we just spawned in, ignore client pawn movement for a bit
	if player.spawning_delay > 0.0:
		return

	#var motion = new_position - server_last_valid_target_position
	# TODO: simulate the move on a physics tick? also move all this to PlayerNetworking class
	#var collision: KinematicCollision3D = player.move_and_collide(motion, true)
	## TODO: speed and fly hack checking
	#if collision:
		#var distance = player.network_controller.server_last_valid_target_position.distance_to(new_position)
		## If the collision is with another player, ignore it
		#if collision.get_collider() is Player:
			#pass
		## if a really low angel and low col depth, assume floor collision and ignore unless it continues for awhile, then reconcile up
		#elif collision.get_angle() < 1.0 and collision.get_depth() < 0.01:
			#continuous_floor_collisions += 1
			#if continuous_floor_collisions >= 100:
				#Logger.info("server_handle_client_pawn_movement: 100+ floor collisions! pushing client up 10cm from last valid position.")
				#server_handle_client_pawn_movement_reconciliation(peer_id, server_last_valid_on_ground_target_position + Vector3(0.0, 0.1, 0.0))
			#return
		## if just low depth, assume it's clipping a corner on some geometry
		## TODO: this breaks the 3m x 3m x 3m server side only box collision when jumping through it
		#elif collision.get_depth() < 0.01 and distance < 0.1:
			#continuous_corner_collisions += 1
			#if continuous_corner_collisions >= 100:
				#Logger.info("server_handle_client_pawn_movement: 100+ corner collisions? TODO: not sure.")
			#return
		#else:
			#Logger.info("server detected player %s collided: %s, dist: %f, depth: %f, angle: %f" % [ player.name, collision.get_collider(), distance, collision.get_depth(), collision.get_angle() ])
			##Logger.info("Server detected collision for player: %s, dist: %f" % [player.name, distance])
			#if distance > 0.25:
				#Logger.info("Server detected collision for player and distance out of tolerance: %s, dist: %f, pos: %v" % [player.name, distance, player.global_position])
				## TODO: rate limit?
				## send message to move player back to last valid target position if they are out of tolerance (reconciliation)
				##server_send_client_player_movement_reconciliation(from_peer_id, player.server_last_valid_target_position)
				#server_handle_client_pawn_movement_reconciliation(peer_id, server_last_valid_on_ground_target_position)
				#server_last_valid_target_position = server_last_valid_on_ground_target_position
				## TODO: add a count of reconciliation events and do special stuff if the player is stuck or something weird
			#return
	## Only allow server pawn to move if they are not colliding.
	#continuous_floor_collisions = 0
	#continuous_corner_collisions = 0

	# TODO: have both server_last_valid_target_position and server_last_valid_on_ground_target_position
	# try and use server_last_valid_target_position first, then fall back to on_ground version if it fails?
	server_last_valid_target_position = network_target_position # TODO: only set this when the player is on the ground
	if (movement_status_bitmap & MOVEMENT_STATES_ON_GROUND_MASK) == 1:
		#Logger.info("player: %s last on ground, updating server_last_valid_on_ground_target_position: %v" % [ str(from_peer_id), network_target_position ])
		server_last_valid_on_ground_target_position = network_target_position
	network_target_position = new_position
	network_target_rotation_degrees_y = rot_y_degrees
	network_target_rotation_degrees_x = rot_x_degrees
	network_inputs1 = inputs1
	network_movement_status_bitmap = movement_status_bitmap

func server_handle_client_pawn_movement_reconciliation(peer_id: int, last_valid_position: Vector3):
	# TODO: rate limit, keep track of a counter, disconnect or kill/respawn pawn if too many reconciliations happen to fast (indicates being stuck somewhere?)
	GameInstance.networking.server_networking.server_send_client_player_movement_reconciliation(peer_id, last_valid_position)

func client_handle_server_movement_reconciliation(server_position: Vector3):
	player.position = server_position
	pass
