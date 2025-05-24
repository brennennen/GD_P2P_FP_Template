
extends Character

class_name Player

# Enums/Structs
enum EquipmentMode { NONE, FISTS, FISHING_POLE, SWORD, PISTOL, RIFLE }
static func EquipmentMode_str(_equipment_mode: EquipmentMode):
	return EquipmentMode.keys()[_equipment_mode]

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
@onready var projectile_spawn: Node3D = $CameraPivot/PlayerCamera/ProjectileSpawn
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
@onready var network_controller: PlayerNetworkController = $NetworkController
@onready var alive: bool = true

# Data Members
# # Status
var health: float = 100.0
var stamina: float = 100.0

# # Movement/Agency
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
var delay_physics: bool = true
var physics_delay_running_delta: float = 0.0
var physics_delay_time: float = 3.0
var stored_collision_layer: int = 0
var last_global_position: Vector3 = Vector3(0.0, 0.0, 0.0)
var last_input_dir: Vector2 = Vector2(0.0, 0.0)

# # Misc
var equipment_mode: EquipmentMode = EquipmentMode.NONE
var is_paused: bool = false
var is_movement_locked: bool = false
var spawning_delay: float


var multiplayer_id: int = 0

# Functions

func _enter_tree():
	Logger.info("character enter tree. name: %s" % str(name))
	set_multiplayer_authority(str(name).to_int(), true)
	multiplayer_id = name.to_int()

func _ready():
	 # hide any menus that might have been left visible
	spawning_delay = 1.0
	pause_menu.visible = false
	jump_velocity = sqrt(jump_height * gravity * 2)
	stored_collision_layer = collision_layer
	if is_multiplayer_authority():
		authoritative_player_ready() # TODO rename this to something about "autonomouse proxy"
	else:
		peer_player_ready()

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
	third_person_animation_tree.set("parameters/UpperBlend2/blend_amount", 0.0)
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

@rpc("any_peer", "call_local", "reliable")
func change_equipment_mode(new_equipment_mode: EquipmentMode):
	match equipment_mode:
		EquipmentMode.NONE:
			pass
		EquipmentMode.FISTS:
			pass
		EquipmentMode.FISHING_POLE:
			if movement_controller.movement_mode == PlayerMovementController.MovementMode.SWINGING:
				movement_controller.movement_mode_transition_swinging_to_falling()
		_:
			pass
		pass

	match new_equipment_mode:
		EquipmentMode.NONE:
			third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/equip_none", true)
			third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/equip_fists", false)
			third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/equip_fishing_pole", false)
			third_person_animation_tree.set("parameters/UpperBlend2/blend_amount", 0.0)
		EquipmentMode.FISTS:
			third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/equip_none", false)
			third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/equip_fists", true)
			third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/equip_fishing_pole", false)
			third_person_animation_tree.set("parameters/UpperBlend2/blend_amount", 1.0)
		EquipmentMode.FISHING_POLE:
			third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/equip_none", false)
			third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/equip_fishing_pole", true)
			third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/equip_fists", false)
			third_person_animation_tree.set("parameters/UpperBlend2/blend_amount", 1.0)
		_:
			Logger.error("change_equipment_mode: '%s' not implemented" % str(new_equipment_mode))
	equipment_mode = new_equipment_mode

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

@rpc("any_peer", "call_local", "reliable")
func die():
	# TODO: hide all visuals, still allow rotating camera? spectating? etc?
	velocity = Vector3(0.0, 0.0, 0.0)
	third_person.hide()
	alive = false
	movement_controller.change_movement_mode(PlayerMovementController.MovementMode.UNKNOWN)

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
	pass
	# TODO: rewrite to use peers and PeerMetadata
	#for player_label in player_list.get_children():
		#player_label.queue_free()
	#for id: int in GameInstance.networking.player_id_list:
		#var player_label := Label.new()
		#if id == 1:
			#var ping = GameInstance.networking.client_networking.client_latency_ms
			#player_label.text = "%s   %s ms" % [str(id), str(ping)]
		#else:
			#player_label.text = "%s" % [str(id)]
		#player_list.add_child(player_label)

# authority vs any_peer is complicated because we set authority to the local client for the player class
# ideally this would only be callable by the server, need to work through a way to handle this...
@rpc("any_peer", "call_local", "reliable")
func server_lock_movement() -> void:
	Logger.info("server_lock_movement: %s" % [str(name)])
	is_movement_locked = true

@rpc("any_peer", "call_local", "reliable")
func unlock_movement() -> void:
	Logger.info("unlock_movement: %s" % [str(name)])
	is_movement_locked = false

func ghost_level_camera() -> void:
	# reparent? or just move?
	#camera.global_position
	pass

func reconnect_camera_to_player() -> void:
	camera.global_position = camera_pivot.global_position

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
	if event.is_action_pressed("jump"):
		jump_action_pressed()
	if event.is_action_pressed("primary_action"):
		primary_action()
	if event.is_action_pressed("hotbar_1"):
		change_equipment_mode.rpc(EquipmentMode.NONE)
	if event.is_action_pressed("hotbar_2"):
		change_equipment_mode.rpc(EquipmentMode.FISTS)
	if event.is_action_pressed("hotbar_3"):
		change_equipment_mode.rpc(EquipmentMode.FISHING_POLE)
	if event.is_action_pressed("crouch_toggle"):
		toggle_crouch.rpc()
	if event.is_action_pressed("debug_fly_toggle"):
		toggle_debug_fly.rpc()

func set_spawn_rotation(new_rotation: Vector3):
	player_rotation = Vector3(0.0, new_rotation.y, 0.0)
	mouse_rotation = Vector3(0.0, new_rotation.y, 0.0)

func primary_action():
	#Logger.info("primary_action: %s" % [name])
	primary_action_predictive() # perform visual feedback instantly if we predict the server will allow the input to make the client feel more responsive.
	primary_action_server_request.rpc_id(1) # send the input request to the server.

## Play any feedback visuals as soon as the player presses the input if we think the server
## server would allow it (aka: we "predict" the server will allow the input and respond
## accordingly.)
func primary_action_predictive():
	Logger.info("primary_action_predictive: %s" % [name])
	match equipment_mode:
		EquipmentMode.NONE:
			pass
		EquipmentMode.FISTS:
			fists_punch_predictive()
		EquipmentMode.FISHING_POLE:
			fishing_primary_action_predictive()
		_:
			pass
	pass

@rpc("any_peer", "call_local", "reliable")
func primary_action_server_request():
	#Logger.info("primary_action_server_request: from: %s" % [name])
	match equipment_mode:
		EquipmentMode.NONE:
			pass
		EquipmentMode.FISTS:
			fists_punch_server_request()
		EquipmentMode.FISHING_POLE:
			fishing_primary_action_server_request()
			pass
		_:
			pass
	pass

func fists_punch_predictive():
	# TODO: play first person punch animation!
	# TODO: maybe start the "hit" animation for the player in the hitbox?
	pass

func fishing_primary_action_predictive():
	# TODO: play fishing first person panimations!
	pass

func fists_punch_server_request():
	Logger.info("fists_punch_server_request");
	# TODO: determine if the punch is allowed or not?
	fists_punch_third_person_visuals.rpc()

	for player in players_in_punch_hitbox:
		player.receive_punch.rpc(global_position)
	pass

@rpc("any_peer", "call_local", "reliable")
func fists_punch_third_person_visuals():
	third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/punch", true)
	var upper_body_state_machine_playback = third_person_animation_tree.get("parameters/UpperBodyStateMachine/playback") as AnimationNodeStateMachinePlayback
	upper_body_state_machine_playback.travel("boxing-punch-right")

var handle_hit_next_physics_frame: bool = false
var hit_source_position: Vector3 = Vector3(0.0, 0.0, 0.0)
var hit_force: float = 0.0

enum HitType { MELEE, YOINK }
var hit_type: HitType = HitType.MELEE

@rpc("any_peer", "call_local", "reliable")
func receive_punch(puncher_position: Vector3):
	Logger.info("receive_punch: me: %s" % [name])
	#knocked_back = true
	#knocked_back_source_position = puncher_position
	#knocked_back_force = 25.0 # todo send this?
	handle_hit_next_physics_frame = true
	hit_source_position = puncher_position
	hit_type = HitType.MELEE
	hit_force = 10.0
	set_health(health - 10)

@rpc("any_peer", "call_local", "reliable")
func fishing_primary_action_third_person_visuals():
	third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/punch", true)
	var upper_body_state_machine_playback = third_person_animation_tree.get("parameters/UpperBodyStateMachine/playback") as AnimationNodeStateMachinePlayback
	upper_body_state_machine_playback.travel("boxing-punch-right")

func fishing_primary_action_server_request():
	#Logger.info("fishing_primary_action_server_request");
	# TODO: spawn fishing lure projectile
	spawn_fishing_lure_projectile.rpc()
	# TODO: go to "fishing-idle" if we hit water, go to "carrying-fishing-pole-idle" if we didn't,
	# TODO: go to "fishing-yoink" if we hit a "yoinkable" (another player or physics objects), go to grapple-hook swing if we hit a static object and are not on the ground?
	fishing_cast_third_person_visuals.rpc()

var last_fishing_lure_projectile: FishingLureProjectile
var fishing_lure_projectile: FishingLureProjectile

@rpc("any_peer", "call_local", "reliable")
func spawn_fishing_lure_projectile():
	if fishing_lure_projectile != null:
		# fishing lure already in flight, don't allow spawning another one until the last one expires
		last_fishing_lure_projectile = fishing_lure_projectile
		fishing_lure_projectile = null
		last_fishing_lure_projectile.queue_free()
	fishing_lure_projectile = preload("res://Core/Projectiles/FishingLureProjectile.tscn").instantiate() as FishingLureProjectile
	GameInstance.projectiles.add_child(fishing_lure_projectile)
	fishing_lure_projectile.global_position = projectile_spawn.global_position
	fishing_lure_projectile.rotation = rotation
	fishing_lure_projectile.start_direction = -projectile_spawn.global_transform.basis.z
	fishing_lure_projectile.start_force = 20.0 # TODO: add more force if left click held?
	fishing_lure_projectile.owning_player = self
	fishing_lure_projectile.launch()

@rpc("any_peer", "call_local", "reliable")
func fishing_cast_third_person_visuals():
	third_person_animation_tree.set("parameters/UpperBodyStateMachine/conditions/punch", true)
	var upper_body_state_machine_playback = third_person_animation_tree.get("parameters/UpperBodyStateMachine/playback") as AnimationNodeStateMachinePlayback
	upper_body_state_machine_playback.travel("cast-fishing-pole")

@rpc("any_peer", "call_local", "reliable")
func receive_fishing_lure_yoink(yoinker_position: Vector3):
	Logger.info("receive_fishing_lure_yoink: me: %s" % [name])
	handle_hit_next_physics_frame = true
	hit_source_position = yoinker_position
	hit_type = HitType.YOINK
	hit_force = 10.0

func _process(delta) -> void:
	debug_imgui_handle_player_window(delta)
	if !is_multiplayer_authority():
		third_person.debug_imgui_handle_3rd_person_animation_window(delta)
	if is_paused:
		load_player_list()

func predictive_physics_process(_delta: float) -> void:
	# TODO: move most of physics process into here
	pass

func _physics_process(delta):
	
	# If we just spawned in, ignore everything for a bit
	if spawning_delay > 0.0:
		spawning_delay -= delta
		return
		
	# delay when just spawned in for a bit to give godot a second to not spaz out
	if delay_physics:
		physics_delay_running_delta += delta
		if physics_delay_running_delta >= physics_delay_time:
			collision_layer = stored_collision_layer
			delay_physics = false
		return
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	last_input_dir = input_dir
	if not self.is_alive: # If the player is dead, allow them to move the camera, but don't do much else.
		update_camera(delta, input_dir)
		return
	
	update_rope()
	
	if not is_multiplayer_authority():
		network_controller.remote_pawn_physics_process(delta)
		return

	update_camera(delta, input_dir)
	network_controller.local_controlled_pawn_physics_process(delta)

	if is_movement_locked:
		return

	movement_controller.movement_mode = movement_controller.determine_movement_mode(delta, movement_controller.movement_mode)

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
	if handle_hit_next_physics_frame:
		physics_process_handle_hit()
		handle_hit_next_physics_frame = false
	movement_controller.player_physics_process(delta, input_dir, jump_pressed)

func physics_process_handle_hit():
	match(hit_type):
		HitType.MELEE:
			var dir = hit_source_position.direction_to(global_position)
			velocity += (Vector3(dir.x, 0.0, dir.z) * hit_force)
			velocity += Vector3(0.0, 5.0, 0.0) # add some up force for flavor
		HitType.YOINK:
			var dir = global_position.direction_to(hit_source_position)
			velocity += (Vector3(dir.x, 0.0, dir.z) * hit_force)
			velocity += Vector3(0.0, 5.0, 0.0) # add some up force for flavor
		_:
			pass

var last_player_basis: Basis
var last_mouse_rotation: Vector3
var last_mouse_rotation_delta: Vector2
var last_mouse_y_rotation: float = 0.0

func update_camera(delta, input_dir):
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

	if !is_leaning_left and !is_leaning_right: # Don't sway if leaning
		if  movement_controller.movement_mode != PlayerMovementController.MovementMode.DEBUG_FLY: # Don't sway if debug flying
			# Head sway (TODO: add speed to influence the amount of sway)
			if input_dir.x > 0:
				camera_pivot.rotation.z = lerp_angle(camera_pivot.rotation.z, deg_to_rad(-2.5), 0.01)
			elif input_dir.x < 0:
				camera_pivot.rotation.z = lerp_angle(camera_pivot.rotation.z, deg_to_rad(2.5), 0.01)
			else:
				camera_pivot.rotation.z = lerp_angle(camera_pivot.rotation.z, deg_to_rad(0), 0.01)

func _on_animation_player_animation_started(anim_name):
	if anim_name == "Crouch":
		is_crouching = !is_crouching


func jump_action_pressed():
	
	# don't actually jump when pressed, wait until physics process 1/60th a second is fine to wait and it's easier to handle velocity changing behavior there
	if movement_controller.movement_mode == PlayerMovementController.MovementMode.SWINGING:
		movement_controller.change_movement_mode.rpc(PlayerMovementController.MovementMode.FALLING)
		#movement_controller.movement_mode_transition_swinging_to_falling()

@rpc("any_peer", "call_local", "reliable")
func start_jump():
	#Logger.info("%s:start_jump" % [name])
	velocity.y = jump_velocity
	#third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/jump", true)
	third_person.jump_third_person_visuals()
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
		movement_controller.movement_mode = PlayerMovementController.MovementMode.DEBUG_FLY
	else:
		$CollisionShape3D.visible = true
		$CollisionShape3D.disabled = false
		movement_controller.movement_mode = PlayerMovementController.MovementMode.FALLING

@rpc("any_peer", "call_local", "reliable")
func server_teleport_player(new_position: Vector3):
	global_position = new_position

var grapple_hook_point: Vector3

const SWING_ROPE = preload("res://Core/Misc/SwingRope/SwingRope.tscn")
@onready var swing_rope: Node3D = $CameraPivot/PlayerCamera/SwingRope

@rpc("any_peer", "call_local", "reliable")
func start_swinging(hook_point: Vector3):
	Logger.info("starting swing!")
	grapple_hook_point = hook_point
	movement_controller.start_swinging()

func update_rope():
	if movement_controller.movement_mode != PlayerMovementController.MovementMode.SWINGING:
		swing_rope.visible = false
		return
	
	swing_rope.visible = true
	var dist = global_position.distance_to(grapple_hook_point)
	swing_rope.look_at(grapple_hook_point)
	swing_rope.scale = Vector3(1, 1, dist)

@rpc("any_peer", "call_local", "reliable")
func respawn(respawn_position: Vector3, respawn_rot_y: float, spectator: bool = false):
	Logger.info("respawn() player: %s, pos: %v, rot_y: %f, spectator: %s" % [ name, respawn_position, respawn_rot_y, str(spectator) ])
	fade_from_black(1.0)
	movement_controller.change_movement_mode(PlayerMovementController.MovementMode.WALKING)
	if is_multiplayer_authority():
		pass
	else:
		third_person.visible = true
	global_position = respawn_position
	global_rotation_degrees.y = respawn_rot_y
	# TODO: make a simple "reset_networking" or something that resets these to global_position
	network_controller.network_target_position = respawn_position
	network_controller.server_last_valid_target_position = respawn_position
	network_controller.server_last_valid_on_ground_target_position = respawn_position
	spawning_delay = 1.0

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

func fade_to_black(duration: float):
	Logger.info("fade_to_black: %f" % [duration])
	if black_screen_tween:
		black_screen_tween.kill()
	black_screen_tween = create_tween()
	black_screen.color = Color.BLACK
	black_screen.color.a = 0.0
	black_screen_tween.tween_property(black_screen, "color", Color.BLACK, duration)
	black_screen_tween.tween_callback(black_screen_tween_done)

func black_screen_tween_done():
	black_screen_tween = null

func _on_main_menu_button_pressed() -> void:
	GameInstance.return_to_main_menu()

func _on_quit_button_pressed() -> void:
	GameInstance.quit()

func debug_imgui_handle_player_window(_delta: float) -> void:
	ImGui.Begin("Players")
	ImGui.Separator()
	ImGui.Text("name: %s" % [ str(name) ])
	ImGui.Text("mp_auth: %s" % [ str(get_multiplayer_authority()) ])
	ImGui.Text("pos: %v" % [ global_position ])
	ImGui.Text("rot_y: %f" % [ rotation_degrees.y ])
	ImGui.Text("mov_mode: %s" % [ str(PlayerMovementController.MovementMode.keys()[movement_controller.movement_mode]) ])
	ImGui.Text("equipment_mode: %s" % [ EquipmentMode_str(equipment_mode) ])
	ImGui.Text("mov_status: %d" % [network_controller.network_movement_status_bitmap])
	
	ImGui.Text("hit: %s" % [ str(handle_hit_next_physics_frame) ])
	ImGui.End()

var players_in_punch_hitbox: Array[Player] = []
func _on_punch_hitbox_area_3d_body_entered(body: Node3D) -> void:
	if body is Player:
		var player := body as Player
		if player.name == name: # don't allow punching yourself
			return
		if player not in players_in_punch_hitbox:
			players_in_punch_hitbox.append(player)

func _on_punch_hitbox_area_3d_body_exited(body: Node3D) -> void:
	if body is Player:
		var player := body as Player
		if player in players_in_punch_hitbox:
			players_in_punch_hitbox.erase(player)
