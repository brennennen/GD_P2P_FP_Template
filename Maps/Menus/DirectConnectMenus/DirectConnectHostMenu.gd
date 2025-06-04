extends Control

# # UI
@onready var port_line_edit = $MarginContainer/VBoxContainer/PortHBoxContainer/PortLineEdit
@onready var password_line_edit = $MarginContainer/VBoxContainer/PasswordHBoxContainer/PasswordLineEdit

# # Audio
@onready var button_hover_audio: AudioStreamPlayer = $Audio/ButtonHoverAudio
@onready var button_pressed_audio: AudioStreamPlayer = $Audio/ButtonPressedAudio

# # Misc
@onready var fade_color_rect = $ColorRect


func _ready():
	fade_in()

func fade_in():
	fade_color_rect.visible = true
	create_tween().tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 0.25)

func _on_host_button_pressed():
	button_pressed_audio.play()
	#Log.debug("_on_host_button_pressed")
	GameInstance.networking.set_multiplayer_mode(Networking.MultiplayerMode.DIRECT_CONNECT)
	GameInstance.networking.direct_connect_lobby.port = int(port_line_edit.text)
	var host_game_result = GameInstance.networking.host_game()
	if host_game_result == Error.OK:
		#GameInstance.load_and_change_scene("res://Maps/HUBLevel/HUBLevel.tscn")
		fade_out_and_change_scene("res://Maps/HUBLevel/HUBLevel.tscn", 0.5)


func _on_back_button_pressed():
	button_pressed_audio.play()
	fade_out_and_change_scene("res://Maps/Menus/DirectConnectMenus/DirectConnectMenu.tscn", 0.5)

func fade_out_and_change_scene(scene_path: String, duration: float):
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(fade_color_rect, "self_modulate", Color.BLACK, duration)
	fade_out_tween.tween_callback(
		func(): GameInstance.load_and_change_scene_blocking(scene_path)# GameInstance.load_and_change_scene(scene_path)
	)

func _on_any_button_mouse_entered() -> void:
	button_hover_audio.play()
