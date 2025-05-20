extends CenterContainer

class_name Reticle

@export var reticle_speed : float = 0.25
@export var reticle_distance : float = 5.0

@onready var player: Player = $"../.."
@onready var left_line: Line2D = $LeftLine
@onready var right_line: Line2D = $RightLine

func _ready() -> void:
	if !is_multiplayer_authority(): # don't run HUD elements on peer player pawns
		set_process(false)

func _process(_delta: float) -> void:
	# move the left and right reticles further from the center depending on velocity
	var vel = player.get_real_velocity()
	var origin = Vector3(0, 0, 0)
	var pos = Vector2(0, 0)
	var speed = origin.distance_to(vel)
	right_line.position = lerp(right_line.position, pos + Vector2(speed * reticle_distance, 0), reticle_speed)
	left_line.position = lerp(left_line.position, pos + Vector2(-speed * reticle_distance, 0), reticle_speed)
