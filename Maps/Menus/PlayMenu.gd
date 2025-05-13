extends Node3D

class_name PlayMenu

# # Transition
@onready var fade_color_rect = $PlayMenuControl/ColorRect

func _ready() -> void:
	fade_in()

func fade_in():
	fade_color_rect.visible = true
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 1.0)

func fade_out_and_change_scene(scene_path: String, duration: float):
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(fade_color_rect, "self_modulate", Color.BLACK, duration)
	fade_out_tween.tween_callback(
		func(): GameInstance.load_and_change_scene_blocking(scene_path)
	)

func _on_single_player_button_pressed() -> void:
	GameInstance.networking.set_multiplayer_mode(Networking.MultiplayerMode.SINGLE_PLAYER)
	var _host_game_result = GameInstance.networking.host_game()
	GameInstance.load_and_change_scene("res://Maps/HUBLevel/HUBLevel.tscn")

func _on_host_button_pressed() -> void:
	fade_out_and_change_scene("res://Maps/Menus/SteamMenus/SteamHostMenu.tscn", 1.0)

func _on_join_button_pressed() -> void:
	fade_out_and_change_scene("res://Maps/Menus/SteamMenus/SteamJoinMenu.tscn", 1.0)

func _on_direct_connect_button_pressed() -> void:
	fade_out_and_change_scene("res://Maps/Menus/DirectConnectMenus/DirectConnectMenu.tscn", 1.0)

func _on_back_button_pressed() -> void:
	fade_out_and_change_scene("res://Maps/Menus/MainMenu.tscn", 1.0)
