extends Node

class_name SteamLobby

@export var steam_lobby_match_list_callback: Callable

var lobby_name: String = "My Game Lobby"
var lobby_type: Steam.LobbyType = Steam.LOBBY_TYPE_PUBLIC
var max_members: int = 4

var steam_peer = SteamMultiplayerPeer.new()
var steam_id: int = 0
var steam_lobby_id: int = 0
var steam_lobby_members: Array = []
var steam_lobby_members_max: int = 10
var steam_username: String

# Used to filter out games not the same.
# TODO: use the version (and if is_demo?) of the game here so different game versions can't see each other.
var steam_game_unique_id: String = "godot_casual_multiplayer_demo"

static var steam_lobby_type_strings: Dictionary = {
	Steam.LobbyType.LOBBY_TYPE_PRIVATE: "Private",
	Steam.LobbyType.LOBBY_TYPE_FRIENDS_ONLY: "Friends Only",
	Steam.LobbyType.LOBBY_TYPE_PUBLIC: "Public",
	Steam.LobbyType.LOBBY_TYPE_INVISIBLE: "Invisible",
	Steam.LobbyType.LOBBY_TYPE_PRIVATE_UNIQUE: "Private Unique",
}

# Called when the node enters the scene tree for the first time.
func _ready():
	initialize_steam()
	steam_check_command_line()
	steam_peer.network_connection_status_changed.connect(steam_peer_connection_status_changed)

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func steam_check_command_line() -> void:
	var arguments: Array = OS.get_cmdline_args()
	# There are arguments to process
	if arguments.size() > 0:
		# A Steam connection argument exists
		if arguments[0] == "+connect_lobby":
			# Lobby invite exists so try to connect to it
			if int(arguments[1]) > 0:
				# At this point, you'll probably want to change scenes
				# Something like a loading into lobby screen
				Logger.info("%s:Command line lobby ID: %s" % [ name, arguments[1] ])
				#join_lobby(int(arguments[1]))

func initialize_steam():
	Steam.join_requested.connect(_steam_on_lobby_join_requested)
	Steam.lobby_chat_update.connect(_steam_on_lobby_chat_update)
	Steam.lobby_created.connect(_steam_on_lobby_created)
	Steam.lobby_joined.connect(_steam_on_lobby_joined)
	Steam.lobby_match_list.connect(_steam_on_lobby_match_list)
	
	var initialize_result: Dictionary = Steam.steamInitEx(480)
	Logger.info("steamInitEx result: %s " % initialize_result)
	if initialize_result["status"] == 0:
		var is_on_steam_deck: bool = Steam.isSteamRunningOnSteamDeck()
		var is_online: bool = Steam.loggedOn()
		var is_owned: bool = Steam.isSubscribed()
		steam_username = Steam.getPersonaName()
		Logger.info("user: %s, online: %d, owned: %d, steamid: %d, steam_deck: %d" \
			% [ steam_username, int(is_online), int(is_owned), Steam.getSteamID(), int(is_on_steam_deck) ] )
		#if is_owned == false:
		#	print("User does not own this game")
		#	get_tree().quit()
	elif initialize_result["status"] == 1:
		print("TODO: other error")
	elif initialize_result["status"] == 2:
		print("can't connect to steam, probably not running")
	elif initialize_result["status"] == 3:
		print("steam out of date, todo: exit i guess?")
	set_lobby_filters()

func steam_peer_connection_status_changed(_x, _y, _z):
	print("steam_peer_connection_status_changed")
	print("steam_peer_connection_status_changed?: x: ", typeof(_x))

func host_game():
	Logger.info("Creating steam lobby. type: %s, max_members: %d" % [steam_lobby_type_strings[lobby_type], max_members])
	if steam_lobby_id == 0:
		Steam.createLobby(lobby_type, max_members)
		var error = steam_peer.create_host(0)
		if error != Error.OK:
			Logger.error("%s:host_game error: %d" % [ name, error ])
			return error
		multiplayer.multiplayer_peer = steam_peer
		return Error.OK
	return Error.OK

func _steam_on_lobby_join_requested(_this_lobby_id: int, friend_id: int) -> void:
	# Get the lobby owner's name
	var owner_name: String = Steam.getFriendPersonaName(friend_id)
	print("Joining %s's lobby..." % owner_name)

func _steam_on_lobby_chat_update(_this_lobby_id: int, change_id: int, _making_change_id: int, chat_state: int) -> void:
	# Get the user who has made the lobby change
	var changer_name: String = Steam.getFriendPersonaName(change_id)
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		print("%s has joined the lobby." % changer_name)
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		print("%s has left the lobby." % changer_name)
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
		print("%s has been kicked from the lobby." % changer_name)
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
		print("%s has been banned from the lobby." % changer_name)
	else:
		print("%s did... something." % changer_name)

func _steam_on_lobby_created(_connect: int, lobby_id: int) -> void:
	if _connect == 1:
		steam_lobby_id = lobby_id
		Logger.info("Created a lobby: %s" % steam_lobby_id)

		Steam.setLobbyJoinable(steam_lobby_id, true)
		Steam.setLobbyData(steam_lobby_id, "name", "Test Lobby")
		Steam.setLobbyData(steam_lobby_id, "mode", "GodotSteam test")
		Steam.setLobbyData(steam_lobby_id, "game_unique_id", steam_game_unique_id)

		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		Logger.info("Allowing Steam to be relay backup: %s" % set_relay)

func steam_send_p2p_packet(this_target: int, packet_data: Dictionary) -> void:
	# Set the send_type and channel
	var send_type: int = Steam.P2P_SEND_RELIABLE
	var channel: int = 0

	# Create a data array to send the data through
	var this_data: PackedByteArray = []
	this_data.append_array(var_to_bytes(packet_data))
	# If sending a packet to everyone
	if this_target == 0:
		# If there is more than one user, send packets
		if steam_lobby_members.size() > 1:
			# Loop through all members that aren't you
			for this_member in steam_lobby_members:
				if this_member['steam_id'] != steam_id:
					Steam.sendP2PPacket(this_member['steam_id'], this_data, send_type, channel)
	# Else send it to someone specific
	else:
		Steam.sendP2PPacket(this_target, this_data, send_type, channel)

func steam_make_p2p_handshake() -> void:
	print("Sending P2P handshake to the lobby")
	steam_send_p2p_packet(0, {"message": "handshake", "from": steam_id})

func _steam_on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	Logger.info("_steam_on_lobby_joined")
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		# Set this lobby ID as your lobby ID
		steam_lobby_id = this_lobby_id
		steam_get_lobby_members()	# Get the lobby members
		steam_make_p2p_handshake()	# Make the initial handshake
		var owner_id = Steam.getLobbyOwner(steam_lobby_id)
		if owner_id != Steam.getSteamID():
			var _error = steam_peer.create_client(owner_id, 0)
			multiplayer.set_multiplayer_peer(steam_peer)
			print("steam_peer.create_client result: %d" % _error)
			#if on_join_scene_path != "":
			#	print("loading game...")
			#	load_game(on_join_scene_path)
			#	add_player(multiplayer.get_unique_id())
	else:
		var fail_reason: String	# Get the failure reason
		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."
		Logger.error("Failed to join: %s" % fail_reason)

func _steam_on_lobby_match_list(steam_lobbies: Array) -> void:
	Logger.info("%s:lobby list matches found: %d" % [ name, steam_lobbies.size() ])
	if steam_lobby_match_list_callback != null and steam_lobby_match_list_callback.is_valid():
		steam_lobby_match_list_callback.call(steam_lobbies)

func steam_get_lobby_members() -> void:
	steam_lobby_members.clear()
	var num_of_members: int = Steam.getNumLobbyMembers(steam_lobby_id)
	for this_member in range(0, num_of_members):
		# Get the member's Steam ID
		var member_steam_id: int = Steam.getLobbyMemberByIndex(steam_lobby_id, this_member)
		var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)
		steam_lobby_members.append({"steam_id": member_steam_id, "steam_name": member_steam_name})

func set_lobby_filters():
	Logger.info("Setting steam lobby filters. game_unique_id: '%s'" % [steam_game_unique_id])
	Steam.addRequestLobbyListStringFilter("game_unique_id", steam_game_unique_id, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)

func refresh_lobby_list() -> void:
	set_lobby_filters()
	Logger.info("%s:request refresh lobby list..." % [ name ])
	Steam.requestLobbyList()

func join_lobby(lobby_id: int):
	steam_lobby_members.clear()
	Steam.joinLobby(lobby_id)

func debug_imgui_append_steam_debug_window(_delta):
	ImGui.Text("username: %s" % [ str(steam_username) ]);
