
extends CharacterBody3D
class_name Character

enum CharacterMovementMode {}

# #################
# Members
# #################

# Seed
var rng: RandomNumberGenerator

# Validity
var is_alive: bool = true

# Position
var current_floor: int = 0

# Movement
@export var nav_agent: NavigationAgent3D
@export var footstep_audio_animation: AnimationPlayer
@export var speed = 1.25

var target_position: Vector3
var distance_to_target: float = 1000.0


# Perception
@export var vision_start: Node3D

# Audio
@export var footstep_audio_player: AudioStreamPlayer3D
var ground_material = "default"
var last_foostep_stream_index = -1
var footstep_streams = {
	"default": [
		preload("res://Assets/Audio/Foley/Footsteps/LightStep01.wav"),
		preload("res://Assets/Audio/Foley/Footsteps/LightStep02.wav"),
		preload("res://Assets/Audio/Foley/Footsteps/LightStep03.wav"),
		preload("res://Assets/Audio/Foley/Footsteps/LightStep04.wav"),
		preload("res://Assets/Audio/Foley/Footsteps/LightStep05.wav"),
		preload("res://Assets/Audio/Foley/Footsteps/LightStep06.wav"),
	]
	# TODO: more materials: metal/plastic/??? maybe make an enum?
}

# Metrics
var kill_count: int = 0
var total_damage_taken: float = 0.0
var total_damage_done: float = 0.0

# Debug
var raycast_debug_draw_layer: int = 0x01

# #################
# Functions
# #################

func _ready():
	GameInstance.debug_run_current_scene(self)
	
	pass

#func _process(delta: float) -> void:
	#if !visible:
		#return
	#pass

## Simple raycast helper function that should really be built into godot...
func raycast(start: Vector3, end: Vector3) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	# use global coordinates, not local to node
	var raycast_col_mask: int = 0x01
	var query = PhysicsRayQueryParameters3D.create(start, end, raycast_col_mask)
	query.hit_back_faces = false
	var result = space_state.intersect_ray(query)
	#if GameInstance.debug_draw:
		#if GameInstance.debug_draw_mask && raycast_debug_draw_layer:
			#DebugDraw3D.draw_line(start, end, Color(0.0, 1.0, 0.0, 1.0), 0.25)
	return result

func play_footstep_audio():
	if !footstep_audio_player:
		return
	# Select a random footstep based on the material being walked on.
	var footstep_index = randi_range(0, footstep_streams[ground_material].size() - 1)
	if footstep_index == last_foostep_stream_index: # Select the next sound in the list if we select the same sound 2 times in a row.
		footstep_index = (footstep_index + 1) % footstep_streams[ground_material].size()
	var footstep_stream = footstep_streams[ground_material][footstep_index]
	footstep_audio_player.stream = footstep_stream
	footstep_audio_player.play()
	last_foostep_stream_index = footstep_index
	## Randomize some other features to try and make the sound more organic (still stounds really robotic tho)
	#if walking_sub_movement_mode == WalkingSubMovementMode.NONE:
		#footstep_audio_player.volume_db = randi_range(-40, -38)
		#footstep_audio_player.pitch_scale = randf_range(.95, 1.05)
		##$AnimationPlayer.speed_scale = 1.0
	#elif walking_sub_movement_mode == WalkingSubMovementMode.CROUCHING:
		#footstep_audio_player.volume_db = randi_range(-48, -46)
		#footstep_audio_player.pitch_scale = randf_range(.85, .95)
		##$AnimationPlayer.speed_scale = 0.8
	#elif walking_sub_movement_mode == WalkingSubMovementMode.SPRINTING:
		#footstep_audio_player.volume_db = randi_range(-32, -30)
		#footstep_audio_player.pitch_scale = randf_range(1.1, 1.15)
		##$AnimationPlayer.speed_scale = 1.2
	#footstep_audio_player.play()
	#last_foostep_stream_index = footstep_index

func play_clothes_foley_audio(): 
	pass

func update_target_position(new_target_position):
	if new_target_position:
		target_position = new_target_position
	if nav_agent:
		nav_agent.target_position = target_position

func move_toward_target():
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var new_velocity = (next_location - current_location).normalized() * speed
	velocity = velocity.move_toward(new_velocity, 0.25)
	var look_target = transform.origin + velocity * Vector3(1, 0, 1) # keep look target on a 2d plane
	look_at(look_target, Vector3.UP)
	move_and_slide()
