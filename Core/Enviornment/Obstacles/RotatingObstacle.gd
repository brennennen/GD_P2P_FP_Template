extends Node3D

class_name RotatingObstacle


@export var enable_rotate: bool = true

@export var rotation_axis: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var rotation_amount: float = 0.05

@export var rotating_node: Node3D

func _physics_process(_delta: float) -> void:
	if enable_rotate:
		rotating_node.rotate(rotation_axis, rotation_amount)
