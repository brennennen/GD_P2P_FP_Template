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

var minimum_severity : Severity = Severity.DEBUG

var log_folder: String = "res://Logs"
var user_data_log_folder: String = "user://Logs"


var multiplayer_id: String = "?"

var registered_rich_text_label_outputs: Dictionary = {} # RichTextLabel: log_count


# #####################
# Functions 
# #####################
func _ready() -> void:
	if !OS.has_feature("editor"):
		log_folder = user_data_log_folder
	#print("log_folder: %s" % log_folder)

func set_multiplayer_id(new_id: String) -> void:
	multiplayer_id = new_id

func set_logs_folder(folder : String) -> void:
	log_folder = folder

func register_rich_text_label_output(new_output: RichTextLabel):
	registered_rich_text_label_outputs[new_output] = { "log_count": 0 }

func create_log_file() -> int:
	if (not DirAccess.dir_exists_absolute(log_folder)):
		print("log dir doesn't exist, attempting to create. if godot crashes, manually create the %s folder" % log_folder)
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

func log_message(message : String, severity : Severity) -> void:
	if (minimum_severity <= severity):
		#print_log_message(message)
		#var current_time = Time.get_time_dict_from_system(true)
		# TODO: figure out how to add the function name?
		var datetime_string = Time.get_datetime_string_from_system(true)
		var formatted_message : String = "%s|%s|%s|%s" % \
			[datetime_string, get_severity_name(severity), multiplayer_id, message]
		print_log_message(formatted_message)
		write_to_file(formatted_message)
		#print_to_registered_rich_text_labels(formatted_message)

func print_log_message(message : String) -> void:
	print(message)

func write_to_file(message : String) -> void:
	# Don't write logs for production yet, TODO: figure out how to rotate smartly
	if !OS.has_feature("editor"):
		return

	if current_log_file == null:
		create_log_file()
	if current_log_file != null: # create_log_file() doesn't work with linux file system for some reason
		current_log_file.store_string(message + "\n")
		current_log_file.flush()
		# TODO: log file rolling!

func print_to_registered_rich_text_labels(message: String) -> void:
	for rich_text_label in registered_rich_text_label_outputs:
		if is_instance_valid(rich_text_label):
			rich_text_label.append_text(message)
		pass
