extends Node

## PlayerManager - Manages player data and synchronization across the network
## Handles player registration, data sharing, and connection events

# Player management signals
signal player_joined(player_data: Dictionary)  # Emitted when a new player joins
signal player_left(player_id: int)  # Emitted when a player leaves

# Player data storage
var players: Dictionary = {}  # Dictionary of player_id -> player_data
var local_player_id: int = -1  # ID of the local player

func _ready():
	# Connect to network events to manage player synchronization
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.client_connected.connect(_on_client_connected)

## Registers the local player with the given username
## Creates player data and handles network synchronization
func register_local_player(username: String):
	local_player_id = NetworkManager.get_unique_id()
	var player_data = {
		"id": local_player_id,
		"name": username,
		"is_host": NetworkManager.is_host
	}
	players[local_player_id] = player_data
	_sort_players()
	
	# Only emit the joined signal once for the local player
	player_joined.emit(player_data)
	
	# Host sends their data to all clients, but don't emit joined signal again
	if NetworkManager.is_host:
		rpc("register_player", player_data)

func _on_peer_connected(id: int):
	# Request player data from new peer
	rpc_id(id, "request_player_data")

func _on_peer_disconnected(id: int):
	if id in players:
		var _player_data = players[id]
		players.erase(id)
		_sort_players()
		player_left.emit(id)

func _on_client_connected():
	# Client sends their data to host
	if not NetworkManager.is_host and local_player_id != -1:
		rpc_id(1, "register_player", players[local_player_id])

@rpc("any_peer")
func register_player(player_data: Dictionary):
	var id = player_data.id
	
	# Don't process our own player data again
	if id == local_player_id:
		return
		
	players[id] = player_data
	_sort_players()
	
	if NetworkManager.is_host:
		# Host forwards player data to all other clients
		for peer_id in players.keys():
			if peer_id != id and peer_id != NetworkManager.get_unique_id():
				rpc_id(peer_id, "register_player", player_data)
	
	# Only emit joined signal for remote players
	player_joined.emit(player_data)

@rpc("any_peer")
func request_player_data():
	if local_player_id != -1:
		rpc_id(multiplayer.get_remote_sender_id(), "register_player", players[local_player_id])

func get_player_data(player_id: int) -> Dictionary:
	return players.get(player_id, {})

func get_player_name(player_id: int) -> String:
	var data = get_player_data(player_id)
	return data.get("name", "Player " + str(player_id))

func get_all_players() -> Dictionary:
	# Return a *copy* of the sorted dictionary
	return players.duplicate()

func is_local_player(player_id: int) -> bool:
	return player_id == local_player_id

func clear_players():
	players.clear()
	local_player_id = -1

## --- NEW: Helper to keep players sorted by ID ---
func _sort_players():
	if players.is_empty():
		return
	var sorted_keys = players.keys()
	sorted_keys.sort()
	var sorted_dict: Dictionary = {}
	for k in sorted_keys:
		sorted_dict[k] = players[k]
	players = sorted_dict
