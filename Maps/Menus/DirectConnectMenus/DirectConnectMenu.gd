extends Control

@onready var fade_color_rect = $ColorRect

# Called when the node enters the scene tree for the first time.
func _ready():
	fade_in()

func fade_in():
	fade_color_rect.visible = true
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 1.0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _on_host_button_pressed():
	GameInstance.load_and_change_scene_blocking("res://Maps/Menus/DirectConnectMenus/DirectConnectHostMenu.tscn")

func _on_join_button_pressed():
	GameInstance.load_and_change_scene_blocking("res://Maps/Menus/DirectConnectMenus/DirectConnectJoinMenu.tscn")

func _on_back_button_pressed():
	GameInstance.load_and_change_scene_blocking("res://Maps/Menus/PlayMenu.tscn")
