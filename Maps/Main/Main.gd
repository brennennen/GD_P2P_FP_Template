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
	Logger.debug("open_main_menu")
	var menu = ResourceLoader.load("res://Maps/Menus/MainMenu.tscn")
	
	#multiplayer.get_default_interface()
	print("mp default interface: %s" % MultiplayerAPI.get_default_interface())
	#multiplayer.multiplayer_peer.close()
	#multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	#change_scene_to_file(menu)
	GameInstance.change_scene(menu)

func change_scene_to_file(resource : Resource):
	Logger.debug("change_scene_to_file: '%s'" % resource.resource_path)
	var node = resource.instantiate()
	for child in get_children():
		#remove_child(child)
		child.queue_free()
	add_child(node)
