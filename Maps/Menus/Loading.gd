extends Control

class_name Loading

@onready var loading_progress: ProgressBar = $MarginContainer2/ProgressBar

var scene_to_load_path: String

# Called when the node enters the scene tree for the first time.
func _ready():
	scene_to_load_path = GameInstance.scene_to_load_path
	Logger.info("Loading screen ready: %s" % scene_to_load_path)
	pass # Replace with function body.

var running_delta: float = 0.5
func _process(delta: float) -> void:
	running_delta += delta
	if running_delta < 0.5: # wait half a second before checking resources
		return
	
	var progress = []
	var status = ResourceLoader.load_threaded_get_status(scene_to_load_path, progress)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		Logger.error("Error while loading level: THREAD_LOAD_INVALID_RESOURCE, scene: %s" % scene_to_load_path)
		GameInstance.go_to_main_menu_with_error("Error loading scene...")
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		loading_progress.value = progress[0] * 100
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		Logger.info("finished loading scene: %s" % scene_to_load_path)
		loading_progress.value = 100
		var scene = ResourceLoader.load_threaded_get(scene_to_load_path)
		Logger.info("path loaded: %s" % scene_to_load_path)
		set_process(false)
		if scene:
			GameInstance.change_scene(scene)
		else:
			GameInstance.go_to_main_menu_with_error("Error loading scene...")
	else:
		Logger.error("Error while loading status: %s, level: %s" % [ str(status), scene_to_load_path ])
		GameInstance.go_to_main_menu_with_error("Error loading scene...")
