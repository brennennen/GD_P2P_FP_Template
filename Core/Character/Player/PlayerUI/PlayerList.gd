extends Control
class_name PlayerList

@onready var player_list_entries: VBoxContainer = $VBoxContainer/ScrollContainer/PlayerListEntries

const PLAYER_LIST_ENTRY: Resource = preload("res://Core/Character/Player/PlayerUI/PlayerListEntry.tscn")

func clear():
	for player_entry in player_list_entries.get_children():
		player_entry.queue_free()

func add_player(peer_id: int, player_name: String, ping: float):
	var new_player_entry: PlayerListEntry  = PLAYER_LIST_ENTRY.instantiate()
	new_player_entry.peer_id = peer_id
	player_list_entries.add_child(new_player_entry)
	new_player_entry.set_player_name(player_name)
	new_player_entry.set_ping(ping)
