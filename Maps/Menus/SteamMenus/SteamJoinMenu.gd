extends Control

class_name SteamJoinMenu

# # UI
@onready var refresh_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/RefreshButton
@onready var lobbies_list: VBoxContainer = $MarginContainer/VBoxContainer/VBoxContainer2/ScrollContainer/LobbiesList

# # Audio
@onready var button_hover_audio: AudioStreamPlayer = $Audio/ButtonHoverAudio
@onready var button_pressed_audio: AudioStreamPlayer = $Audio/ButtonPressedAudio

# # Misc
@onready var fade_color_rect: ColorRect = $ColorRect

func _ready():
	fade_in()
	GameInstance.networking.steam_lobby.steam_lobby_match_list_callback = handle_updated_steam_lobby_match_list
	_on_refresh_button_pressed()

func fade_in():
	fade_color_rect.visible = true
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_color_rect, "self_modulate", Color.TRANSPARENT, 0.25)

func clear_lobbies_list() -> void:
	for lobby_entry in lobbies_list.get_children():
		lobby_entry.free()

func _on_refresh_button_pressed() -> void:
	button_pressed_audio.play()
	clear_lobbies_list()
	refresh_button.set_disabled(true)
	GameInstance.networking.steam_lobby.refresh_lobby_list()

func handle_updated_steam_lobby_match_list(steam_lobbies: Array):
	#Log.info("%s:handle_updated_steam_lobby_match_list: lobbies count: %d" % [ name, steam_lobbies.size() ])
	refresh_button.set_disabled(false)

	for steam_lobby in steam_lobbies:
		# Pull lobby data from Steam, these are specific to our example
		#Log.info(steam_lobby)
		var lobby_name: String = Steam.getLobbyData(steam_lobby, "name")
		var lobby_mode: String = Steam.getLobbyData(steam_lobby, "mode")
		var lobby_num_members: int = Steam.getNumLobbyMembers(steam_lobby)
		# Create a button for the lobby
		var lobby_button: Button = Button.new()
		#var lobby_string: String = "Lobby %s: %s [%] - %s Player(s)" % [steam_lobby, lobby_name, lobby_mode, lobby_num_members]
		var lobby_string = "Lobby %s: %s [%s] - %s Player(s)" % [ str(lobby_name), str(lobby_name), str(lobby_mode), str(lobby_num_members) ]
		#Log.info("Found lobby: %s" % str(lobby_string))
		lobby_button.set_name("lobby_" + str(steam_lobby))
		lobby_button.set_text_alignment(HORIZONTAL_ALIGNMENT_LEFT)
		lobby_button.set_text(lobby_string)
		lobby_button.set_size(Vector2(800, 50))
		lobby_button.set_name("lobby_%s" % steam_lobby)
		#lobby_button.set_theme(BUTTON_THEME)
		#lobby_button.connect("pressed", Callable(self, "join_lobby").bind(steam_lobby))
		var lobby_signal: int = lobby_button.connect("pressed", Callable(self, "join_steam_lobby_callback").bind(steam_lobby))
		# Add the new lobby to the list
		lobbies_list.add_child(lobby_button)
		refresh_button.set_disabled(false)

func join_steam_lobby_callback(lobby_id: int):
	#Log.info("Joining steam lobby: %s" % lobby_id)
	GameInstance.networking.set_multiplayer_mode(Networking.MultiplayerMode.STEAM)
	var join_game_result = GameInstance.networking.steam_lobby.join_lobby(lobby_id)

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
