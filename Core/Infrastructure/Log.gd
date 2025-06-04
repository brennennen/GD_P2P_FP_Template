extends Node

##!
# Logg
#
# heavily referenced from https://www.nightquestgames.com/logger-in-gdscript-for-better-debugging/
#

# #####################
# Members
# #####################
const log_file_name_prefix = "Log"


enum Severity { DEBUG, INFO, WARN, ERROR }
var severity_names : Array[String] = [ "Debug", "Info ", "Warn ", "Error" ] # spaces to line up strings in log files for less eye strain
func get_severity_name(severity : Severity):
	return severity_names[severity]

var current_log_file : FileAccess = null

var minimum_severity : Severity = Severity.INFO

var log_folder: String = "res://Logs"
var user_data_log_folder: String = "user://Logs"
var multiplayer_id: String = "?"

var running_in_editor: bool = false

# #####################
# Functions
# #####################
func _ready() -> void:
	if OS.has_feature("editor"):
		running_in_editor = true
	else:
		log_folder = user_data_log_folder

func set_multiplayer_id(new_id: String) -> void:
	multiplayer_id = new_id
	set_default_log_color()

func set_logs_folder(folder : String) -> void:
	log_folder = folder

func create_log_file() -> int:
	if (not DirAccess.dir_exists_absolute(log_folder)):
		print("log dir doesn't exist, attempting to create. if godot crashes, manually create the folder: %s" % [log_folder])
		DirAccess.make_dir_absolute(log_folder)
	var date_string = Time.get_date_string_from_system(true)
	var log_file_full_path = "%s/%s_%s.log" % [log_folder, log_file_name_prefix, date_string]
	current_log_file = FileAccess.open(log_file_full_path, FileAccess.WRITE)
	#print("path: %s, error_code: %d" % [log_file_full_path, FileAccess.get_open_error()])
	return FileAccess.get_open_error()

func debug(message: String) -> void:
	log_message(message, Severity.DEBUG)

func info(message: String) -> void:
	log_message(message, Severity.INFO)

func warn(message: String) -> void:
	log_message(message, Severity.WARN)

func error(message: String) -> void:
	log_message(message, Severity.ERROR)

var log_color: Color = Color.WHITE_SMOKE
func set_default_log_color() -> void:
	if multiplayer_id == "1":
		log_color = Color.WHITE_SMOKE
	else:  
		var multiplayer_id_int := hash(multiplayer_id)
		log_color.s = 0.20
		log_color.v = 1.0
		var hue: float = int(30.0 + (multiplayer_id_int * 137.508)) % 360 # Golden ratio - good balance of minimally overlapping hues to compute cost
		log_color.h = hue / 360

func log_message(message: String, severity: Severity) -> void:
	if running_in_editor:
		editor_log_message(message, severity)
	else:
		production_log_message(message, severity)

func editor_log_message(message: String, severity: Severity) -> void:
	if (minimum_severity <= severity):
		var time_string = Time.get_time_string_from_system(false)
		var formatted_message : String = "%s|%s|%s|%s" % \
			[ time_string, get_severity_name(severity), multiplayer_id, message ]
		match severity:
			Severity.WARN:
				print_rich("[color=%s]%s|%s|%s|[/color][color=yellow]%s[/color]" % \
					[ log_color.to_html(), time_string, get_severity_name(severity), multiplayer_id, message ])
			Severity.ERROR:
				print_rich("[color=%s]%s|%s|%s|[/color][color=red]%s[/color]" % \
					[ log_color.to_html(), time_string, get_severity_name(severity), multiplayer_id, message ])
			_:
				print_rich("[color=%s]" % [log_color.to_html()] + formatted_message + "[/color]")
		write_to_file(formatted_message)

func production_log_message(message: String, severity: Severity) -> void:
	if (minimum_severity <= severity):
		var time_string = Time.get_time_string_from_system(false)
		var formatted_message : String = "%s|%s|%s" % [ time_string, get_severity_name(severity), message ]
		print(formatted_message)
		write_to_file(formatted_message)

func write_to_file(message : String) -> void:
	# Don't write logs for production yet, TODO: figure out how to rotate smartly before tackling this
	if !OS.has_feature("editor"):
		return
	if current_log_file == null:
		create_log_file()
	if current_log_file != null: # create_log_file() doesn't work with linux file system for some reason
		current_log_file.store_string(message + "\n")
		current_log_file.flush() # TODO: consider not flushing every log for performance considerations
		# TODO: log file rolling!
