extends Node

## NetworkManager - Handles all multiplayer networking functionality
## Manages server hosting, client connections, and network state

const GAME_PORT: int = 9001

# Network connection signals
signal peer_connected(id: int)  # Emitted when a peer connects to the server
signal peer_disconnected(id: int)  # Emitted when a peer disconnects from the server
signal server_started  # Emitted when server successfully starts
signal server_stopped  # Emitted when server stops
signal client_connected  # Emitted when client connects to server
signal client_disconnected  # Emitted when client disconnects from server
signal connection_failed  # Emitted when connection attempt fails

# Network state variables
var is_host: bool = false  # True if this instance is hosting the game
var _is_connected: bool = false  # Internal connection state tracking

func _ready():
	# Connect to Godot's multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)

## Starts hosting a multiplayer game on the specified port
## Returns true if successful, false if already connected or creation fails
func start_host() -> bool:
	if _is_connected:
		return false
		
	var server := ENetMultiplayerPeer.new()
	var err := server.create_server(GAME_PORT)
	if err != OK:
		print("Failed to host: ", err)
		return false
	
	multiplayer.multiplayer_peer = server
	is_host = true
	_is_connected = true
	server_started.emit()
	return true

## Connects to a multiplayer game hosted at the specified IP address
## Returns true if connection attempt succeeds, false if already connected or creation fails
func join_server(ip: String) -> bool:
	if _is_connected:
		return false
		
	var client := ENetMultiplayerPeer.new()
	var err := client.create_client(ip, GAME_PORT)
	if err != OK:
		print("Failed to connect: ", err)
		return false
	
	multiplayer.multiplayer_peer = client
	is_host = false
	return true

## Disconnects from the current multiplayer game and resets state
func leave_game():
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	_is_connected = false
	server_stopped.emit()
	client_disconnected.emit()

## Returns the local IP address for hosting
func get_local_ip() -> String:
	return IP.get_local_addresses()[0]

## Returns the unique multiplayer ID of this peer
func get_unique_id() -> int:
	return multiplayer.get_unique_id()

# Internal signal handlers for multiplayer events
func _on_peer_connected(id: int):
	peer_connected.emit(id)

func _on_peer_disconnected(id: int):
	peer_disconnected.emit(id)

func _on_connected_to_server():
	_is_connected = true
	client_connected.emit()

func _on_server_disconnected():
	_is_connected = false
	client_disconnected.emit()

func _on_connection_failed():
	connection_failed.emit()
