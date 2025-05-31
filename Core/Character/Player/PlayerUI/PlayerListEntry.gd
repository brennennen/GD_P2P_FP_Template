extends Control
class_name PlayerListEntry

@onready var name_label: Label = $PanelContainer/LeftMarginContainer/NameLabel
@onready var ping_label: Label = $PanelContainer/MiddleMarginContainer/PingLabel

@onready var kick_button: Button = $PanelContainer/RightMarginContainer/HBoxContainer/KickButton
@onready var mute_button: Button = $PanelContainer/RightMarginContainer/HBoxContainer/MuteButton

var peer_id: int

func _ready() -> void:
	kick_button.pressed.connect(_on_kick_button_pressed)
	mute_button.pressed.connect(_on_mute_button_pressed)

func set_player_name(new_name: String) -> void:
	name_label.text = new_name

func set_ping(new_ping: float) -> void:
	ping_label.text = "%f" % [new_ping]

func _on_kick_button_pressed() -> void:
	Logger.info("_on_kick_button_pressed: %s" % [name_label])
	if GameInstance.networking.is_server():
		# TODO: force disconnect
		Logger.info("_on_kick_button_pressed on server: %s" % [name_label.text])
		pass
	pass

func _on_mute_button_pressed() -> void:
	Logger.info("_on_mute_button_pressed: %s" % [name_label.text])
	pass
