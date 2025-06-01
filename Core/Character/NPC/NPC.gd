extends Character

class_name NPC

# #################
# Members
# #################

var npc_ai_tick_rate: float = 0.25
## TODO: if 100+ enemies raycast at the same frame, might cause some performance issues
## find a way to offset ai ticks between npcs.
var npc_ai_tick_running_delta: float = 0.0
#


# Perception
## Each NPC keeps a cached data (distances, ???, etc) between them and all players that is periodically updated.
@export var player_max_perception_distance: float = 20.0
var player_perception_checks_enabled: bool = false
var player_perceptions: Dictionary = {}
var player_perception_check_running_delta: float = 0.0
var player_perception_check_interval: float = 1.0
var players_in_sight: Array[Player] = []

var interact_text: String

func interactions_enabled() -> bool:
	return true

# #################
# Functions
# #################
func _ready():
	super()
	npc_ai_tick_running_delta = randf_range(0.0, npc_ai_tick_rate)
	#var enemy_tick_running_delta: float = 0.0



func _process(delta: float) -> void:
	#super(delta)
	if !visible:
		return
	if !GameInstance.networking.is_server(): # Only manage perceptions on server.
		return
	npc_ai_tick_running_delta += delta
	if npc_ai_tick_running_delta >= npc_ai_tick_rate:
		npc_tick(npc_ai_tick_running_delta)

func manage_npc_tick(delta: float) -> void:
	npc_ai_tick_running_delta += delta
	if npc_ai_tick_running_delta >= npc_ai_tick_rate:
		npc_tick(npc_ai_tick_running_delta)
		npc_ai_tick_running_delta = 0.0

func npc_tick(delta: float) -> void:
	player_perception_check_running_delta += delta
	if player_perception_check_running_delta >= player_perception_check_interval:
		update_player_perceptions(player_perception_check_running_delta)
		player_perception_check_running_delta = 0.0

func update_player_perceptions(delta: float) -> void:
	#var new_player_perceptions: Dictionary = {}
	for player in GameInstance.get_players():
		if self.current_floor == player.current_floor:
			var distance = global_position.distance_to(player.global_position)
			if player.name not in player_perceptions:
				player_perceptions[player.name] = { "distance": distance, "ray_hit": false, "in_sight": false, "in_sight_time": 0.0 }
			else:
				player_perceptions[player.name]["distance"] = distance
			if distance <= player_max_perception_distance:
				var in_sight = check_player_in_sight(player)
				var ray_hit = in_sight # If the player is in sight, then a raycast does hit
				if !ray_hit: # If the player is not in sight, then we potentially may still be able to hit with a raycast
					ray_hit = check_player_ray_hit(player)
				player_perceptions[player.name]["ray_hit"] = ray_hit
				player_perceptions[player.name]["in_sight"] = in_sight
				if in_sight == true:
					player_perceptions[player.name]["in_sight_time"] += delta
				else:
					player_perceptions[player.name]["in_sight_time"] = 0.0
			else:
				player_perceptions[player.name]["in_sight"] = false
				player_perceptions[player.name]["in_sight_time"] = 0.0

## Check if there is no static objects between the player and an npc, that is you could cast a raycast between the two and it would hit.
func check_player_ray_hit(player: Player) -> bool:
	if !vision_start:
		return false
	var raycast_result = raycast(vision_start.global_position, player.center_of_mass.global_position)
	if !raycast_result.is_empty() and raycast_result["collider"] == player:
		return true
	return false

## Check if the npc is looking at a player, that is the player is both in front of the npc and no objects are between the player and npc.
func check_player_in_sight(player: Player) -> bool:
	if !vision_start:
		return false
	var forward: Vector3 = -global_transform.basis.z
	var dir: Vector3 = vision_start.global_position.direction_to(player.center_of_mass.global_position)
	var dot: float = dir.dot(forward)
	if dot > 0.0:
		var raycast_result = raycast(vision_start.global_position, player.center_of_mass.global_position)
		if !raycast_result.is_empty() and raycast_result["collider"] == player:
			return true
	return false

func check_players_in_sight():
	if !vision_start:
		return
	for player in GameInstance.get_players():
		if check_player_in_sight(player):
			players_in_sight.append(player)

#func handle_sector_event(_event: Sector.SectorEvent) -> void:
	#pass

@rpc("any_peer", "call_local", "reliable")
func queue_free_networked():
	Logger.info("%s:queue_free_networked" % [name])
	queue_free()
