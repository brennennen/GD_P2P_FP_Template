extends Control

class_name MainMenu

@onready var error_panel: Panel = $ErrorPanel
@onready var error_content_label: Label = $ErrorPanel/MarginContainer/VBoxContainer/ErrorContentLabel


# # Audio
@onready var button_hover_audio: AudioStreamPlayer = $Audio/ButtonHoverAudio
@onready var button_pressed_audio: AudioStreamPlayer = $Audio/ButtonPressedAudio


# # Transition
@onready var fade_color_rect = $MainMenuControl/ColorRect

func _ready() -> void:
	fade_in()
	# TODO: check if error message is set or not and display a modal?
	if GameInstance.menu_error_message != "":
		error_content_label.text = GameInstance.menu_error_message
		error_panel.show()
	else:
		error_panel.hide()

func fade_in():
	fade_color_rect.visible = true
	create_tween().tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 0.25)

func fade_out_and_change_scene(scene_path: String, duration: float):
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(fade_color_rect, "self_modulate", Color.BLACK, duration)
	fade_out_tween.tween_callback(
		func(): GameInstance.load_and_change_scene_blocking(scene_path)# GameInstance.load_and_change_scene(scene_path)
	)

func _on_play_button_pressed() -> void:
	button_pressed_audio.play()
	fade_out_and_change_scene("res://Maps/Menus/PlayMenu.tscn", 0.5)

func _on_quit_button_pressed() -> void:
	button_pressed_audio.play()
	await get_tree().create_timer(0.5).timeout
	GameInstance.quit()

func _on_error_panel_close_button_pressed() -> void:
	GameInstance.menu_error_message = ""
	error_panel.hide()

func _on_error_panel_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		Logger.info("error panel _on_error_panel_gui_input: %s" % [event.as_text()])
		GameInstance.menu_error_message = ""
		error_panel.hide()

func _on_any_button_mouse_entered() -> void:
	button_hover_audio.play()
