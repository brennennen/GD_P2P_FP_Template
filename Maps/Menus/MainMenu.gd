extends Node3D

class_name MainMenu


# # Audio
#@onready var button_pressed_audio: AudioStreamPlayer = $Audio/ButtonPressedAudio
#@onready var button_hover_audio: AudioStreamPlayer = $Audio/ButtonHoverAudio

# # Transition
@onready var fade_color_rect = $MainMenuControl/ColorRect

func _ready() -> void:
	fade_in()

func fade_in():
	fade_color_rect.visible = true
	create_tween().tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 1.0)

func fade_out_and_change_scene(scene_path: String, duration: float):
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(fade_color_rect, "self_modulate", Color.BLACK, duration)
	fade_out_tween.tween_callback(
		func(): GameInstance.load_and_change_scene_blocking(scene_path)# GameInstance.load_and_change_scene(scene_path)
	)

func _on_play_button_pressed() -> void:
	#button_pressed_audio.play()
	fade_out_and_change_scene("res://Maps/Menus/PlayMenu.tscn", 1.0)
	pass # Replace with function body.

func _on_quit_button_pressed() -> void:
	GameInstance.quit()
