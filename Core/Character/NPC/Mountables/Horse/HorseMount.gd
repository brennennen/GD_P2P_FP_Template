extends Node3D

class_name HorseMount


@onready var animation_tree: AnimationTree = $AnimationTree

var locomotion_state_machine_playback: AnimationNodeStateMachinePlayback


func _ready() -> void:
	locomotion_state_machine_playback = animation_tree.get("parameters/LocomotionStateMachine/playback") as AnimationNodeStateMachinePlayback
	locomotion_state_machine_playback.travel("idle")
