extends Node3D

class_name PlayerMovementController

enum MovementMode { UNKNOWN, WALKING, FALLING, SWIMMING, SWINGING, HORSE_RIDING, DEBUG_FLY, SPECTATE }
enum WalkingSubMovementMode { NONE, CROUCHING, SPRINTING }

@onready var player: Player = $".."

@export_category("Movement")
@export var walk_speed: float = 2.5
@export var crouch_speed: float = 1.5
@export var sprint_speed: float = 5.0
@export var horse_mounted_speed: float = 9.0
@export var swim_speed: float = 3.0
@export var air_strafe_speed: float = 1.0
@export var debug_fly_speed: float = 10.0
@export var jump_height: float = 1.0 # meters

var jump_velocity: float = 0.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


var movement_mode: MovementMode = MovementMode.WALKING
var walking_sub_movement_mode: WalkingSubMovementMode = WalkingSubMovementMode.NONE

func _ready() -> void:
	jump_velocity = sqrt(jump_height * gravity * 2)

@rpc("any_peer", "call_local", "reliable")
func change_movement_mode(new_movement_mode: MovementMode) -> void:
	Logger.info("%s: change_movement_mode: %s -> %s" % [ player.name, MovementMode.keys()[movement_mode], MovementMode.keys()[new_movement_mode] ])
	
	match movement_mode:
		MovementMode.SWINGING:
			match new_movement_mode:
				MovementMode.FALLING:
					movement_mode_transition_swinging_to_falling()
				_:
					pass
			pass
		_:
			pass

	match new_movement_mode:
		MovementMode.HORSE_RIDING:
			player.third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/walk", false)
			player.third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/horse_riding", true)
	if movement_mode == MovementMode.SWINGING:
		pass
		#movement_controller.change_movement_mode(PlayerMovementController.MovementMode.FALLING)
		#movement_controller.movement_mode_transition_swinging_to_falling()
	movement_mode = new_movement_mode

func determine_movement_mode(_delta, last_movement_mode) -> MovementMode:
	# TODO: don't change movement mode?
	
	var new_movement_mode = last_movement_mode
	if player.is_on_floor():
		if last_movement_mode == MovementMode.FALLING:
			movement_mode_transition_falling_to_walking()
		elif last_movement_mode == MovementMode.SWINGING:
			movement_mode_transition_swinging_to_walking()
		new_movement_mode = MovementMode.WALKING
		walking_sub_movement_mode = determine_walking_sub_movement_mode()
	else:
		if new_movement_mode == MovementMode.WALKING:
			new_movement_mode = MovementMode.FALLING
	return new_movement_mode

func determine_walking_sub_movement_mode() -> WalkingSubMovementMode:
	if player.is_crouching:
		return WalkingSubMovementMode.CROUCHING
	elif player.is_sprinting:
		return WalkingSubMovementMode.SPRINTING
	return WalkingSubMovementMode.NONE

func movement_mode_transition_falling_to_walking():
	# TODO: turn off jump animation
	#third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/on_ground", is_on_floor())
	#third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/jump", false)
	player.play_footstep_audio()

func movement_mode_transition_swinging_to_walking():
	# TODO: play swinging to ground landing animation
	player.play_footstep_audio()

func movement_mode_transition_swinging_to_falling():
	#
	#movement_mode = MovementMode.FALLING
	pass

func get_movement_speed() -> float:
	var movement_speed = walk_speed
	if player.is_on_floor():
		if player.is_crouching == true:
			movement_speed = crouch_speed
		elif player.is_sprinting == true:
			movement_speed = sprint_speed
	# TODO: figure out if we are in water?
	# elif is_in_water(): { movement_speed = SWIM_SPEED }
	else:
		if player.is_debug_flying == true:
			movement_speed = debug_fly_speed
		else:
			movement_speed = air_strafe_speed
	return movement_speed

@rpc("any_peer", "call_local", "reliable")
func start_jump():
	player.velocity.y = jump_velocity
	player.third_person.jump_third_person_visuals()
	player.play_footstep_audio()

func player_physics_process(delta: float, input_dir: Vector2, sprint_held: bool, jump_pressed: bool) -> void:
	#movement_mode = determine_movement_mode(delta, movement_mode)

	# Handle Jump.
	if !player.is_paused:
		#if movement_mode != PlayerMovementController.MovementMode.HORSE_RIDING:
		if jump_pressed and player.is_on_floor():
			start_jump.rpc() # TODO: this no longer makes sense to do in the physics frame given it's an rpc... need to rethink this...

	# Handle Sprint
	player.is_sprinting = false
	if !player.is_paused:
		if sprint_held:
			if player.stamina <= 1.0:
				player.is_sprinting = false
			else:
				player.is_sprinting = true
				player.set_stamina(player.stamina - 0.25)
		else:
			# TODO: add delay before regen
			if player.stamina < 100.0:
				player.set_stamina(player.stamina + 0.25)

	if player.handle_hit_next_physics_frame:
		player.physics_process_handle_hit()
		player.handle_hit_next_physics_frame = false

	var move_speed: float = get_movement_speed()
	if movement_mode == MovementMode.WALKING and jump_pressed == false:
		ground_movement_physics(delta, move_speed, input_dir)
		if player.velocity.length() != 0:
			player.footstep_animation_player.play("Walk")
			player.head_bob_animation_player.play("HeadBob")
	elif movement_mode == MovementMode.HORSE_RIDING:
		horse_riding_movement_physics(delta, input_dir)
	elif movement_mode == MovementMode.SWINGING:
		swinging_movement_physics(delta, move_speed)
	elif movement_mode == MovementMode.FALLING:
		falling_movement_physics(delta, move_speed)
	elif movement_mode == MovementMode.SPECTATE:
		spectate_movement_physics(delta)
	elif movement_mode == MovementMode.DEBUG_FLY:
		debug_flying_physics(delta, move_speed)
	if !GameInstance.networking.is_server() and is_multiplayer_authority():
		player.network_controller.client_send_move_data()

func ground_movement_physics(delta: float, move_speed: float, input_dir: Vector2) -> void:
	player.velocity.y -= player.gravity * delta
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		player.velocity.x = lerp(player.velocity.x, direction.x * move_speed, delta * 3.0)
		player.velocity.z = lerp(player.velocity.z, direction.z * move_speed, delta * 3.0)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, move_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, move_speed)
	player.move_and_slide()
	move_colliding_rigid_bodies()

# TODO: lerp to target_dir?
var target_dir: Vector2
var actual_dir: Vector2

var target_speed: float
var actual_speed: float

func horse_riding_movement_physics(delta: float, input_dir: Vector2):
	ground_movement_physics(delta, horse_mounted_speed, input_dir)
	# TODO: special physics, move fast but slow acceleration and no strafing, also slow backwards movement
	#player.velocity.y -= player.gravity * delta
	#target_dir = input_dir
	#actual_dir = lerp(actual_dir, target_dir, 0.5)
	#var direction = (player.transform.basis * Vector3(0, 0, actual_dir.y)).normalized()
	## TOOD: make going backwards really slow?
	#target_speed = horse_mounted_speed
	#actual_speed = lerpf(actual_speed, target_speed, 0.05)
	#if direction:
		#player.velocity.x = lerp(player.velocity.x, direction.x * actual_speed, delta * 3.0)
		#player.velocity.z = lerp(player.velocity.z, direction.z * actual_speed, delta * 3.0)
	#else:
		#player.velocity.x = move_toward(player.velocity.x, 0, actual_speed)
		#player.velocity.z = move_toward(player.velocity.z, 0, actual_speed)
	#player.move_and_slide()
	#move_colliding_rigid_bodies()

var current_swing_radius: float = 0.0

@export var swing_control_strength: float = 1.0
@export var swing_initial_boost_factor: float = 0.5
@export var swing_damping_factor: float = 1.0

func start_swinging():
	change_movement_mode.rpc(MovementMode.SWINGING)
	#movement_mode = MovementMode.SWINGING
	#current_swing_radius = (player.global_transform.origin - player.grapple_hook_point).length()
	#var vector_to_anchor = player.grapple_hook_point - player.global_transform.origin
	#var radial_velocity = player.velocity.project(vector_to_anchor.normalized())
	#player.velocity = (player.velocity - radial_velocity) * swing_initial_boost_factor
	pass

var rest_length: float = 2.0
var stiffness: float = 5.0
var dampening: float = 1.0

func swinging_movement_physics(delta: float, _move_speed: float) -> void:
	player.velocity.y -= player.gravity * delta
	# TODO: move in parabala from swinging point
	# use "player.grapple_hook_point" to access vector3 point to swing around

	# If the grapple hook is gone, change to falling
	if player.grapple_hook_point == null:
		movement_mode = MovementMode.FALLING
		return

	# hooke's law
	# https://www.youtube.com/watch?v=yWRHMOqoxGM
	var target_dir = player.global_position.direction_to(player.grapple_hook_point)
	var target_dist = player.global_position.distance_to(player.grapple_hook_point)
	var displacement = target_dist - rest_length
	var force := Vector3.ZERO
	
	if displacement > 0.0001:
		var spring_force_magnitude = stiffness * displacement
		var spring_force = target_dir * spring_force_magnitude
		var vel_dot: float = player.velocity.dot(target_dir)
		var local_dampening = -dampening * vel_dot * target_dir
		force = spring_force + local_dampening
	player.velocity += force * delta
	player.move_and_slide()

func spectate_movement_physics(delta: float) -> void:
	# No move?
	pass

func falling_movement_physics(delta, _speed):
	player.velocity.y -= player.gravity * delta
	#velocity.y -= gravity * delta
	#Logger.info("gravity: %f, y_veloc: %f" % [gravity, velocity.y])
	player.move_and_slide()

func move_colliding_rigid_bodies():
	for col_idx in player.get_slide_collision_count():
		var col : KinematicCollision3D = player.get_slide_collision(col_idx)
		if col.get_collider() is RigidBody3D:
			col.get_collider().apply_central_impulse(-col.get_normal() * 0.3)
			col.get_collider().apply_impulse(-col.get_normal() * 0.01, col.get_position())

func debug_flying_physics(_delta, fly_speed):
	player.velocity = Vector3(0.0, 0.0, 0.0)
	if Input.is_action_pressed("move_forward"):
		player.velocity += -1 * player.camera.get_owner().transform.basis.z * fly_speed
	if Input.is_action_pressed("move_backward"):
		player.velocity += player.camera.get_owner().transform.basis.z * fly_speed
	if Input.is_action_pressed("move_left"):
		player.velocity += -1 * player.camera.get_owner().transform.basis.x * fly_speed
	if Input.is_action_pressed("move_right"):
		player.velocity += player.camera.get_owner().transform.basis.x * fly_speed
	if Input.is_action_pressed("jump"):
		player.velocity += player.camera.get_owner().transform.basis.y * fly_speed
	if Input.is_action_pressed("crouch_toggle") or Input.is_action_pressed("crouch_hold"):
		player.velocity += -1 * player.camera.get_owner().transform.basis.y * fly_speed
	player.move_and_slide()
