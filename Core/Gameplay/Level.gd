extends Node3D

class_name Level

var default_spawn_transform: Transform3D = Transform3D(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0,0.0))
var spawn_points: Array[SpawnPoint] = []
@onready var default_spawn_point: SpawnPoint = SpawnPoint.new()

func _ready() -> void:
	#Logger.info("Level _ready")
	#var default_spawn_point: SpawnPoint = SpawnPoint.new()
	pass

func set_spawn_points(spawn_points_container: Node3D):
	for node in spawn_points_container.get_children():
		if node is SpawnPoint:
			spawn_points.append(node as SpawnPoint)

func get_spawn_point() -> SpawnPoint:
	if spawn_points.size() == 0:
		return default_spawn_point
	spawn_points.shuffle()

	for spawn_point in spawn_points:
		if !spawn_point.is_occupied():
			return spawn_point
	return default_spawn_point
