extends Node3D

class_name PlayerThirdPerson

@onready var player = $".."

@onready var third_person_animation_tree: AnimationTree = $ThirdPersonAnimationTree
@onready var model_glb: Node3D = $mannequin

func _ready() -> void:
	third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/walk", true)
	third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/crouch", false)
	third_person_animation_tree.set("parameters/LocomotionStateMachine/conditions/fall", false)

func jump_third_person_visuals():
	var locomotion_state_machine_playback = third_person_animation_tree.get("parameters/LocomotionStateMachine/playback") as AnimationNodeStateMachinePlayback
	locomotion_state_machine_playback.travel("jump")

func debug_imgui_handle_3rd_person_animation_window(_delta: float) -> void:
	# TODO: only render if debug flag set
	# TODO: get player name... for editor: 1, 2, 3, 4. for steam: actual account name. random ids reset imgui window position, which sucks
	
	ImGui.Begin("PlayerTPAnim")
	ImGui.Text("name: %s" % [str(player.name)])
	ImGui.Text("Locomotion:")
	ImGui.Text("walk: %s" % [str(third_person_animation_tree.get("parameters/LocomotionStateMachine/conditions/walk"))])
	ImGui.Text("crouch: %s" % [str(third_person_animation_tree.get("parameters/LocomotionStateMachine/conditions/crouch"))])
	ImGui.Text("fall: %s" % [str(third_person_animation_tree.get("parameters/LocomotionStateMachine/conditions/fall"))])
	ImGui.Text("walk_blend: %s" % [str(third_person_animation_tree.get("parameters/LocomotionStateMachine/WalkBlendSpace2D/blend_position"))])
	ImGui.Text("jump: %s" % [str(third_person_animation_tree.get("parameters/LocomotionStateMachine/conditions/jump"))])
	
	ImGui.Text("UpperBody:")
	ImGui.Text("upper_blend: %s" % [str(third_person_animation_tree.get("parameters/UpperBlend2/blend_amount"))])
	ImGui.Text("equip_none: %s" % [str(third_person_animation_tree.get("parameters/UpperBodyStateMachine/conditions/equip_none"))])
	ImGui.Text("equip_fists: %s" % [str(third_person_animation_tree.get("parameters/UpperBodyStateMachine/conditions/equip_fists"))])
	ImGui.Text("equip_fishing_pole: %s" % [str(third_person_animation_tree.get("parameters/UpperBodyStateMachine/conditions/equip_fishing_pole"))])
	ImGui.Separator()
	# TODO: estimated packet loss?
	# TODO: estimated download/receive byte count
	# TODO: estimated
	ImGui.End()
