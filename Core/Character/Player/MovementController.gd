extends Node3D

class_name PlayerMovementController

@onready var player = $".."

@export_category("Movement")
@export var walk_speed: float = 2.5
@export var crouch_speed: float = 1.5
@export var sprint_speed: float = 5.0
@export var swim_speed: float = 3.0
@export var air_strafe_speed: float = 1.0
@export var debug_fly_speed: float = 10.0
@export var jump_height: float = 1.0 # meters

var jump_velocity: float = 0.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	jump_velocity = sqrt(jump_height * gravity * 2)

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

func ground_movement_physics(delta, move_speed):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	player.last_input_dir = input_dir
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		player.velocity.x = lerp(player.velocity.x, direction.x * move_speed, delta * 3.0)
		player.velocity.z = lerp(player.velocity.z, direction.z * move_speed, delta * 3.0)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, move_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, move_speed)
	player.move_and_slide()
	move_colliding_rigid_bodies()

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
