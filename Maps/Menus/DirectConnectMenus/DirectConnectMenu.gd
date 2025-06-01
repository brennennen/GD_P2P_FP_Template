extends Control

@onready var fade_color_rect = $ColorRect

func _ready():
	fade_in()

func fade_in():
	fade_color_rect.visible = true
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 0.25)

func _on_host_button_pressed():
	fade_out_and_change_scene("res://Maps/Menus/DirectConnectMenus/DirectConnectHostMenu.tscn", 0.25)

func _on_join_button_pressed():
	fade_out_and_change_scene("res://Maps/Menus/DirectConnectMenus/DirectConnectJoinMenu.tscn", 0.25)

func _on_back_button_pressed():
	fade_out_and_change_scene("res://Maps/Menus/PlayMenu.tscn", 0.25)

func fade_out_and_change_scene(scene_path: String, duration: float):
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(fade_color_rect, "self_modulate", Color.BLACK, duration)
	fade_out_tween.tween_callback(
		func(): GameInstance.load_and_change_scene_blocking(scene_path)# GameInstance.load_and_change_scene(scene_path)
	)
