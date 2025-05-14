extends Character

class_name Player

# Enums/Structs
enum MovementMode { UNKNOWN, WALKING, FALLING, SWIMMING, DEBUG_FLY, SPECTATE }
enum WalkingSubMovementMode { NONE, CROUCHING, SPRINTING }


# Public Members
@export_category("Movement")
@export var walk_speed: float = 2.5
@export var crouch_speed: float = 1.5
@export var sprint_speed: float = 5.0
@export var swim_speed: float = 3.0
@export var air_strafe_speed: float = 1.0
@export var debug_fly_speed: float = 10.0
@export var jump_height: float = 1.0 # meters
@export var crouch_animation_speed : float = 10.0

@export_category("Player Camera")
@export var mouse_sensitivity: float = 0.5
@export var tilt_lower_limit : float = deg_to_rad(-90.0)
@export var tilt_upper_limit : float = deg_to_rad(90.0)

#@export_category("Misc")

# Nodes
# # Camera
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/PlayerCamera

# # UI/HUD
@onready var hud: Control = $HUD
@onready var black_screen: ColorRect = $HUD/BlackScreen
@onready var pause_menu: Control = $PauseMenu
@onready var hud_health: Label = $HUD/MarginContainer/VBoxContainer/HealthHBoxContainer/HealthValue
@onready var hud_stamina: Label = $HUD/MarginContainer/VBoxContainer/StaminaHBoxContainer/StaminaValue
# ... inventory, health/status bars, interactable menus, etc.

# # Movement
@onready var crouch_animation_player : AnimationPlayer = $CrouchAnimationPlayer
@onready var crouch_shapecast: ShapeCast3D = $CrouchShapeCast
@onready var footstep_animation_player: AnimationPlayer = $FootstepAnimationPlayer
@onready var head_bob_animation_player: AnimationPlayer = $CameraPivot/HeadBobAnimationPlayer
@onready var movement_controller: PlayerMovementController = $MovementController
# ... animation players, etc.

# # Misc
@onready var third_person = $ThirdPerson
@onready var third_person_animation_tree: AnimationTree = $ThirdPerson/ThirdPersonAnimationTree
@onready var first_person = $CameraPivot/FirstPerson
@onready var debug_label_3d = $DebugLabel3D
@onready var network_controller: PlayerNetworkController = $NetworkController

# Data Members
# # Status
var health: float = 100.0
var stamina: float = 100.0

# # Movement/Agency
var movement_mode: MovementMode = MovementMode.WALKING
var walking_sub_movement_mode: WalkingSubMovementMode = WalkingSubMovementMode.NONE
var has_mouse_input : bool = false
var mouse_rotation : Vector3
var rotation_input : float
var tilt_input : float
var player_rotation : Vector3
var camera_rotation : Vector3
var is_crouching: bool = false
var sprinting_previous: bool = false
var is_sprinting: bool = false
var is_leaning_left: bool = false
var is_leaning_right: bool = false
var is_debug_flying: bool = false
var jump_velocity: float = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# # Networking
var interpolate_networked_movement: bool = true
var network_movement_interpolation_rate: float = 0.5
var network_target_position: Vector3
var network_target_rotation_degrees_y: float
var network_target_rotation_degrees_x: float
var network_inputs1: int
var network_movement_status_bitmap: int
var delay_physics: bool = true
var physics_delay_running_delta: float = 0.0
var physics_delay_time: float = 3.0
var stored_collision_layer: int = 0
var last_global_position: Vector3 = Vector3(0.0, 0.0, 0.0)
var last_input_dir: Vector2 = Vector2(0.0, 0.0)
var last_sent_location: Vector3
var last_sent_rotation_degrees_y: float
var last_sent_rotation_degrees_x: float
var last_sent_velocity: Vector3

# # Misc
var is_paused: bool = false
var is_movement_locked: bool = false

# Functions

func _enter_tree():
	Logger.info("character enter tree. name: %s" % str(name))
	set_multiplayer_authority(str(name).to_int(), true)

func _ready():
	 # hide any menus that might have been left visible
	pause_menu.visible = false

	jump_velocity = sqrt(jump_height * gravity * 2)
	# Needs to interpolate/reach the target by the next sync packet (received every network tick)
	network_movement_interpolation_rate = (1.0 / Engine.physics_ticks_per_second) / GameInstance.networking.network_tick_rate
	network_movement_interpolation_rate *= 0.8 # still needs to be tinkered with emperically
	stored_collision_layer = collision_layer
	if is_multiplayer_authority():
		authoritative_player_ready() # TODO rename this to something about "autonomouse proxy"
	else:
		peer_player_ready()
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
	debug_label_3d.text = "%s\n%s" % [ str(name).to_int(), net_auth_mode]

## The locally controlled player (controlled by the local game instance) is ready
func authoritative_player_ready():
	Logger.info("%s:authoritative_player_ready" % [name])
	camera.current = true
	third_person.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	crouch_shapecast.add_exception($".")
	fade_from_black(5.0)
	toggle_pause() # for debug testing on a single machine, best to start paused so you can move the windows around

## A peer player (not controlled by the local game instance) is ready
func peer_player_ready():
	Logger.info("%s:peer_player_ready" % [name])
	camera.current = false
	first_person.visible = false
	third_person.visible = true
	hud.hide()
	Logger.info("spawned %s's peer, sending rpc to start syncing" % name)
	notify_peer_their_player_is_spawned.rpc_id(str(name).to_int(), multiplayer.get_unique_id())

@rpc("any_peer", "reliable")
func notify_peer_their_player_is_spawned(spawned_peer_id):
	Logger.info("notify_peer_their_player_is_spawned. arg: %d" % [ spawned_peer_id ])

#func setup_audio():
	#if is_multiplayer_authority():
		#voice_input.stream = AudioStreamMicrophone.new()
		#voice_input.play()
		#audio_input_index = AudioServer.get_bus_index("Record")
		#audio_input_effect = AudioServer.get_bus_effect(audio_input_index, 0)
	#Logger.info("voice output has stream playback: %d" % int(voice_output.has_stream_playback()))
	#voice_output_playback = voice_output.get_stream_playback()
	#input_threshold = Options.voice_input_threshold

func set_health(new_health: float) -> void:
	health = new_health
	hud_health.text = str(int(health))
	#if health <= 0.0:
	#	die.rpc()

func set_stamina(new_stamina: float) -> void:
	stamina = new_stamina
	hud_stamina.text = str(int(stamina))
	if stamina <= 25.0:
		# TODO: lerp into a heavy breathing sound for a bit
		pass

func is_menu_open() -> bool:
	if pause_menu.visible == true: # or options menu, or interactable menu, etc.
		return true
	return false

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
	if !is_paused:
		has_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		if has_mouse_input:
			rotation_input = -event.relative.x
			tilt_input = -event.relative.y
			#GameInstance.debug_panel.update_entry("mouse", ("%.2f, %.2f" % [_rotation_input, _tilt_input]))

func toggle_pause():
	is_paused = !is_paused
	if is_paused:
		Logger.info("Pausing")
		load_player_list()
		pause_menu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Logger.info("Unpausing")
		pause_menu.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

@onready var player_list: VBoxContainer = $PauseMenu/PlayerListMarginContainer/PlayerListVBoxContainer/PlayerListScrollContainer/PlayerListVBoxContainer

func load_player_list():
	for player_label in player_list.get_children():
		player_label.queue_free()
	for id: int in GameInstance.networking.player_id_list:
		var player_label := Label.new()
		if id == 1:
			var ping = GameInstance.networking.client_networking.client_latency_ms
			player_label.text = "%s   %s ms" % [str(id), str(ping)]
		else:
			player_label.text = "%s" % [str(id)]
		player_list.add_child(player_label)

@rpc("any_peer", "call_local", "reliable")
func lock_movement() -> void:
	Logger.info("lock_movement: %s" % [str(name)])
	is_movement_locked = true

@rpc("any_peer", "call_local", "reliable")
func unlock_movement() -> void:
	Logger.info("unlock_movement")
	is_movement_locked = false

func ghost_level_camera() -> void:
	# reparent? or just move?
	#camera.global_position
	pass

func reconnect_camera_to_player() -> void:
	camera.global_position = camera_pivot.global_position
	pass

func _input(event):
	if is_multiplayer_authority():
		handle_system_inputs(event)
		if !is_paused: # and !debug_console.visible:
			handle_gameplay_inputs(event)

## Handle non-gameplay related system inputs (pausing, quiting, etc.)
func handle_system_inputs(event):
	if !is_multiplayer_authority():
		return
	if event.is_action_pressed("pause"):
		toggle_pause()
	#if event.is_action_pressed("screen_mode_toggle"):
		#Options.toggle_fullscreen()
	#if event.is_action_pressed("debug_console"):
		#debug_console.toggle()
	if event.is_action_pressed("debug_quit"):
		Logger.info("debug_quit pressed")
		get_tree().quit()

## Handle gameplay related inputs (moving, interacting, etc.)
func handle_gameplay_inputs(event):
	if !is_multiplayer_authority():
		return
	if !self.is_alive:
		return
	if is_menu_open():
		return
	if event.is_action_pressed("crouch_toggle"):
		toggle_crouch.rpc()
	if event.is_action_pressed("debug_fly_toggle"):
		toggle_debug_fly.rpc()

func set_spawn_rotation(new_rotation: Vector3):
	player_rotation = Vector3(0.0, new_rotation.y, 0.0)
	mouse_rotation = Vector3(0.0, new_rotation.y, 0.0)

func _process(delta) -> void:
	if is_paused:
		load_player_list()

func _physics_process(delta):
	# delay when just spawned in for a bit to give godot a second to not spaz out
	if delay_physics:
		physics_delay_running_delta += delta
		if physics_delay_running_delta >= physics_delay_time:
			collision_layer = stored_collision_layer
			delay_physics = false
		return
	if is_menu_open():
		return
	if not self.is_alive: # If the player is dead, allow them to move the camera, but don't do much else.
		update_camera(delta)
		return
	if not is_multiplayer_authority():
		network_controller.remote_pawn_physics_process(delta)
		return
	if is_movement_locked:
		return
	movement_mode = determine_movement_mode(delta, movement_mode)
	update_camera(delta)

	# Handle Jump.
	var jump_pressed: bool = false
	if !is_paused:
		jump_pressed = Input.is_action_just_pressed("jump")
		if jump_pressed and is_on_floor():
			if is_crouching == true:
				toggle_crouch.rpc()
			start_jump.rpc()
	
	# Handle Sprint
	is_sprinting = false
	if !is_paused:
		if Input.is_action_pressed("sprint"):
			if stamina <= 1.0:
				is_sprinting = false
			else:
				is_sprinting = true
				set_stamina(stamina - 0.25)
		else:
			# TODO: add delay before regen
			if stamina < 100.0:
				set_stamina(stamina + 0.25)

	velocity.y -= gravity * delta
	
	var move_speed = movement_controller.get_movement_speed()
	if movement_mode == MovementMode.WALKING and jump_pressed == false and !is_paused:
		ground_movement_physics(delta, move_speed)
		if velocity.length() != 0:
			footstep_animation_player.play("Walk")
			head_bob_animation_player.play("HeadBob")
	elif movement_mode == MovementMode.FALLING:
		falling_movement_physics(delta, move_speed)
	elif movement_mode == MovementMode.DEBUG_FLY:
		movement_controller.debug_flying_physics(delta, move_speed)
	if !GameInstance.networking.is_server() and is_multiplayer_authority():
		send_move_data()

var last_player_basis: Basis
var last_mouse_rotation: Vector3
var last_mouse_rotation_delta: Vector2
var last_mouse_y_rotation: float = 0.0

func update_camera(delta):
	mouse_rotation.x += tilt_input * delta * mouse_sensitivity
	mouse_rotation.x = clamp(mouse_rotation.x, tilt_lower_limit, tilt_upper_limit)
	mouse_rotation.y += rotation_input * delta * mouse_sensitivity
	
	last_mouse_rotation_delta.x = last_mouse_rotation.x - mouse_rotation.x
	last_mouse_rotation_delta.y = last_mouse_rotation.y - mouse_rotation.y
	last_mouse_rotation = mouse_rotation

	player_rotation = Vector3(0.0, mouse_rotation.y, 0.0)
	camera_rotation = Vector3(mouse_rotation.x, 0.0, 0.0)

	camera.transform.basis = Basis.from_euler(camera_rotation)
	camera.rotation.z = 0.0
	self.rotation.y = mouse_rotation.y

	rotation_input = 0.0
	tilt_input = 0.0

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	if !is_leaning_left and !is_leaning_right: # Don't sway if leaning
		if movement_mode != MovementMode.DEBUG_FLY: # Don't sway if debug flying
			# Head sway (TODO: add speed to influence the amount of sway)
			if input_dir.x > 0:
				camera_pivot.rotation.z = lerp_angle(camera_pivot.rotation.z, deg_to_rad(-2.5), 0.01)
			elif input_dir.x < 0:
				camera_pivot.rotation.z = lerp_angle(camera_pivot.rotation.z, deg_to_rad(2.5), 0.01)
			else:
				camera_pivot.rotation.z = lerp_angle(camera_pivot.rotation.z, deg_to_rad(0), 0.01)

func ground_movement_physics(delta, move_speed):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	last_input_dir = input_dir
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = lerp(velocity.x, direction.x * move_speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * move_speed, delta * 3.0)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
	move_and_slide()
	movement_controller.move_colliding_rigid_bodies()

func falling_movement_physics(_delta, _speed):
	#velocity.y -= gravity * delta
	#Logger.info("gravity: %f, y_veloc: %f" % [gravity, velocity.y])
	move_and_slide()

func _on_animation_player_animation_started(anim_name):
	if anim_name == "Crouch":
		is_crouching = !is_crouching

@rpc("any_peer", "call_local", "reliable")
func start_jump():
	Logger.info("%s:start_jump" % [name])
	velocity.y = jump_velocity
	third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/jump", true)
	play_footstep_audio()

func end_jump():
	third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/jump", false)

@rpc("any_peer", "call_local", "reliable")
func toggle_crouch():
	Logger.info("%s:toggle_crouch: is_crouching: %d, crouch_shapecast: %d" % [name, int(is_crouching), int(crouch_shapecast.is_colliding())])
	if is_crouching == true:
		if crouch_shapecast.is_colliding() == false:
			crouch_animation_player.play("Crouch", -1, -1.0 * crouch_animation_speed)
			is_crouching = false
	else:
		crouch_animation_player.play("Crouch", -1, crouch_animation_speed)
		is_crouching = true

@rpc("any_peer", "call_local", "reliable")
func toggle_debug_fly() -> void:
	is_debug_flying = !is_debug_flying
	if is_debug_flying:
		$CollisionShape3D.visible = false
		$CollisionShape3D.disabled = true
		movement_mode = MovementMode.DEBUG_FLY
	else:
		$CollisionShape3D.visible = true
		$CollisionShape3D.disabled = false
		movement_mode = MovementMode.FALLING

var send_move_data_ticks: int = 0
var sent_one_extra_no_move_data_packet: bool = false
func send_move_data():
	if global_position == last_sent_location \
			and global_rotation_degrees.y == last_sent_rotation_degrees_y \
			and global_rotation_degrees.x == last_sent_rotation_degrees_x \
			and velocity == last_sent_velocity \
			and sent_one_extra_no_move_data_packet == true:
		# player hasn't moved, don't waste the bandwidth
		return

	var inputs1 = network_controller.build_inputs1()
	var movement_states_bitmap = network_controller.build_movement_states_bitmap()

	if global_position != last_sent_location:
		sent_one_extra_no_move_data_packet = false

	if sent_one_extra_no_move_data_packet == false and global_position == last_sent_location:
		print("sent sent_one_extra_no_move_data_packet")
		sent_one_extra_no_move_data_packet = true
		#inputs1 = inputs1 & 0x11110000 # zero out movement (forward/back/left/right) bits
		inputs1 = 0

	GameInstance.networking.client_networking.client_send_player_movement(name.to_int(), 
		global_position, global_rotation_degrees.y, camera.global_rotation_degrees.x,
		inputs1, movement_states_bitmap)
	Logger.info("global_position: %v" % [ global_position ])
	last_sent_location = global_position
	last_sent_rotation_degrees_y = global_rotation_degrees.y
	last_sent_velocity = velocity

@rpc("any_peer", "call_local", "reliable")
func server_teleport_player(new_position: Vector3):
	global_position = new_position

func determine_movement_mode(_delta, last_movement_mode) -> MovementMode:
	var new_movement_mode = last_movement_mode
	if is_on_floor():
		if last_movement_mode == MovementMode.FALLING:
			movement_mode_transition_falling_to_walking()
		new_movement_mode = MovementMode.WALKING
		walking_sub_movement_mode = determine_walking_sub_movement_mode()
	else:	
		if new_movement_mode == MovementMode.WALKING:
			new_movement_mode = MovementMode.FALLING
	return new_movement_mode

func determine_walking_sub_movement_mode() -> WalkingSubMovementMode:
	if is_crouching:
		return WalkingSubMovementMode.CROUCHING
	elif is_sprinting:
		return WalkingSubMovementMode.SPRINTING
	return WalkingSubMovementMode.NONE

func movement_mode_transition_falling_to_walking():
	# TODO: turn off jump animation
	#third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/on_ground", is_on_floor())
	#third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/jump", false)
	play_footstep_audio()

func play_footstep_audio():
	if !footstep_audio_player:
		return
	# Select a random footstep based on the material being walked on.
	var footstep_index = randi_range(0, footstep_streams[ground_material].size() - 1)
	if footstep_index == last_foostep_stream_index: # Select the next sound in the list if we select the same sound 2 times in a row.
		footstep_index = (footstep_index + 1) % footstep_streams[ground_material].size()
	var footstep_stream = footstep_streams[ground_material][footstep_index]
	footstep_audio_player.stream = footstep_stream
	# Randomize some other features to try and make the sound more organic
	# TODO: probably better to have completely different animation players for each ground movement type to better sync up sound to foot landings
	if walking_sub_movement_mode == WalkingSubMovementMode.NONE:
		footstep_audio_player.volume_db = randi_range(-40, -38)
		footstep_audio_player.pitch_scale = randf_range(.95, 1.05)
		footstep_animation_player.speed_scale = 1.0
	elif walking_sub_movement_mode == WalkingSubMovementMode.CROUCHING:
		footstep_audio_player.volume_db = randi_range(-48, -46)
		footstep_audio_player.pitch_scale = randf_range(.85, .95)
		footstep_animation_player.speed_scale = 0.8
	elif walking_sub_movement_mode == WalkingSubMovementMode.SPRINTING:
		footstep_audio_player.volume_db = randi_range(-32, -30)
		footstep_audio_player.pitch_scale = randf_range(1.1, 1.15)
		footstep_animation_player.speed_scale = 1.2
	footstep_audio_player.play()
	last_foostep_stream_index = footstep_index

func respawn():
	#self.health = health_max
	#self.is_alive = true
	#hud.visible = true
	#dead_hud.visible = false
	#heart_beat_audio.stop()
	fade_from_black(1.0)
	
	#if is_multiplayer_authority():
		#first_person.visible = true
	#else:
		#third_person.visible = true

var black_screen_tween: Tween = null
func fade_from_black(duration: float):
	Logger.info("fade_from_black: %f" % [duration])
	black_screen.visible = true
	if black_screen_tween:
		black_screen_tween.kill()
	black_screen_tween = create_tween()
	black_screen.color = Color.BLACK
	black_screen_tween.tween_property(black_screen, "color", Color(0.0, 0.0, 0.0, 0.0), duration)
	black_screen_tween.tween_callback(black_screen_tween_done)

func black_screen_tween_done():
	black_screen_tween = null

func _on_main_menu_button_pressed() -> void:
	GameInstance.return_to_main_menu()

func _on_quit_button_pressed() -> void:
	GameInstance.quit()
