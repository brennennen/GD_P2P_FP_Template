extends Control

class_name PlayMenu

# # Transition
@onready var fade_color_rect = $PlayMenuControl/ColorRect

@onready var button_hover_audio: AudioStreamPlayer = $Audio/ButtonHoverAudio
@onready var button_pressed_audio: AudioStreamPlayer = $Audio/ButtonPressedAudio


func _ready() -> void:
	fade_in()

func fade_in():
	fade_color_rect.visible = true
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 0.25)

func fade_out_and_change_scene(scene_path: String, duration: float):
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(fade_color_rect, "self_modulate", Color.BLACK, duration)
	fade_out_tween.tween_callback(
		func(): GameInstance.load_and_change_scene_blocking(scene_path)
	)

func _on_single_player_button_pressed() -> void:
	button_pressed_audio.play()
	GameInstance.networking.set_multiplayer_mode(Networking.MultiplayerMode.SINGLE_PLAYER)
	GameInstance.networking.host_game()
	fade_out_and_change_scene("res://Maps/HUBLevel/HUBLevel.tscn", 0.5)

func _on_host_button_pressed() -> void:
	button_pressed_audio.play()
	fade_out_and_change_scene("res://Maps/Menus/SteamMenus/SteamHostMenu.tscn", 0.5)

func _on_join_button_pressed() -> void:
	button_pressed_audio.play()
	fade_out_and_change_scene("res://Maps/Menus/SteamMenus/SteamJoinMenu.tscn", 0.5)

func _on_direct_connect_button_pressed() -> void:
	button_pressed_audio.play()
	fade_out_and_change_scene("res://Maps/Menus/DirectConnectMenus/DirectConnectMenu.tscn", 0.5)

func _on_back_button_pressed() -> void:
	button_pressed_audio.play()
	fade_out_and_change_scene("res://Maps/Menus/MainMenu.tscn", 0.5)

func _on_any_button_mouse_entered() -> void:
	button_hover_audio.play()
