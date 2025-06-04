extends Control

# # UI
@onready var address_text_box = $MarginContainer/VBoxContainer/AddressHBoxContainer/AddressLineEdit
@onready var port_text_box = $MarginContainer/VBoxContainer/PortBoxContainer/PortLineEdit
@onready var password_text_box = $MarginContainer/VBoxContainer/PasswordHBoxContainer/PasswordLineEdit
@onready var status_text = $StatusMarginContainer/StatusRichTextLabel
@onready var join_button = $MarginContainer/VBoxContainer/JoinButton
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

# # Audio
@onready var button_hover_audio: AudioStreamPlayer = $Audio/ButtonHoverAudio
@onready var button_pressed_audio: AudioStreamPlayer = $Audio/ButtonPressedAudio

# # Misc
@onready var fade_color_rect = $ColorRect


func _ready():
	fade_in()
	enable_buttons()

func fade_in():
	fade_color_rect.visible = true
	create_tween().tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 0.25)

func disable_buttons() -> void:
	join_button.set_disabled(true)
	back_button.set_disabled(true)

func enable_buttons() -> void:
	join_button.set_disabled(false)
	back_button.set_disabled(false)

func _on_join_button_pressed():
	button_pressed_audio.play()
	disable_buttons()
	var address: String = address_text_box.text
	var port: int = int(port_text_box.text)
	#Log.debug("_on_join_button_pressed. address: %s, port: %d" % [ address, port ])
	GameInstance.networking.set_multiplayer_mode(Networking.MultiplayerMode.DIRECT_CONNECT)
	var join_game_result = GameInstance.networking.direct_connect_lobby.join_game(address, port)
	if join_game_result != Error.OK:
		#Log.error("FAILED TO JOIN GAME!")
		# TODO: display an error message modal?
		pass

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
