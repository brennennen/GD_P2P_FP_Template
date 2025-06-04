extends Node

func _ready():
	if GameInstance.networking.multiplayer_mode == Networking.MultiplayerMode.IN_EDITOR:
		# if we are running from within the editor, we may sneakly add the main and shuffle around
		# nodes to skip the main menu/start sequence
		return
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 60
	DisplayServer.window_set_min_size(Vector2i(640, 480))
	open_main_menu()

func open_main_menu():
	#Log.debug("open_main_menu")
	var menu = ResourceLoader.load("res://Maps/Menus/MainMenu.tscn")
	GameInstance.change_scene(menu)
