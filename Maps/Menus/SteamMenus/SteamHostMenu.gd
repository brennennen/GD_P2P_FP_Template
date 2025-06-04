extends Control

class_name SteamHostMenu

@onready var lobby_name: LineEdit = $MarginContainer/CenterVBoxContainer/LobbyNameHBoxContainer/LineEdit
@onready var lobby_type_options: OptionButton = $MarginContainer/CenterVBoxContainer/LobbyTypeHBoxContainer/LobbyTypeOptionButton
@onready var max_players_line_edit: LineEdit = $MarginContainer/CenterVBoxContainer/MaxPlayersHBoxContainer/MaxPlayersLineEdit
@onready var status_label: RichTextLabel = $StatusPanel/StatusLabel
@onready var fade_color_rect: ColorRect = $ColorRect

@onready var button_hover_audio: AudioStreamPlayer = $Audio/ButtonHoverAudio
@onready var button_pressed_audio: AudioStreamPlayer = $Audio/ButtonPressedAudio


var default_max_players_count: int = 4

func _ready():
	fade_in()
	for key in SteamLobby.steam_lobby_type_strings:
		lobby_type_options.add_item(SteamLobby.steam_lobby_type_strings[key], key)
	lobby_name.text = "%s's Lobby" % [Steam.getPersonaName()]
	lobby_type_options.selected = Steam.LobbyType.LOBBY_TYPE_PUBLIC
	max_players_line_edit.text = str(default_max_players_count)
	if GameInstance.networking.last_status_message != "":
		status_label.text = GameInstance.networking.last_status_message

func fade_in():
	fade_color_rect.visible = true
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 0.25)

func _on_host_button_pressed() -> void:
	button_pressed_audio.play()
	var lobby_type: int = lobby_type_options.get_selected_id()
	var max_players: int = int(max_players_line_edit.text)
	#Log.debug("_on_host_button_pressed: lobby_name.text: %s, lobby_type: %d, max_members: %d" % [lobby_name.text, lobby_type, max_players])
	GameInstance.networking.set_multiplayer_mode(Networking.MultiplayerMode.STEAM)
	GameInstance.networking.steam_lobby.lobby_name = lobby_name.text
	GameInstance.networking.steam_lobby.lobby_type = lobby_type as Steam.LobbyType
	GameInstance.networking.steam_lobby.max_members = max_players
	var host_game_result = GameInstance.networking.host_game()
	if host_game_result == Error.OK:
		#GameInstance.load_and_change_scene("res://Maps/HUBLevel/HUBLevel.tscn")
		fade_out_and_change_scene("res://Maps/HUBLevel/HUBLevel.tscn", 0.5)
	else:
		#Log.error("%s: Failed to host steam game" % [ name ])
		GameInstance.networking.last_status_message = "Failed to host steam game: %d" % [host_game_result]

func _on_back_button_pressed() -> void:
	button_pressed_audio.play()
	fade_out_and_change_scene("res://Maps/Menus/PlayMenu.tscn", 0.5)

func fade_out_and_change_scene(scene_path: String, duration: float):
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(fade_color_rect, "self_modulate", Color.BLACK, duration)
	fade_out_tween.tween_callback(
		func(): GameInstance.load_and_change_scene_blocking(scene_path)
	)

func _on_any_button_mouse_entered() -> void:
	button_hover_audio.play()
