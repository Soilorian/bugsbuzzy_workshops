extends Node

## ChatManager - Handles in-game chat functionality and system messages
## Manages chat history, message broadcasting, and system notifications

signal message_received(message: String)  # Emitted when a new message is received

var chat_history: Array[String] = []  # Stores all chat messages for persistence

func _ready():
	# Connect to player and network events for system messages
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.player_left.connect(_on_player_left)
	NetworkManager.server_stopped.connect(_on_server_stopped)
	NetworkManager.client_disconnected.connect(_on_client_disconnected)

## Sends a chat message to all players in the game
## Validates the message and broadcasts it via RPC
func send_message(message: String):
	if message.strip_edges() == "":
		return
		
	var sender_id = NetworkManager.get_unique_id()
	var sender_name = PlayerManager.get_player_name(sender_id)
	
	# Send message to all peers
	rpc("receive_message", sender_id, sender_name, message)

## Adds a system message to the chat (e.g., "Player joined")
func add_system_message(message: String):
	var formatted_message = "[System]: %s" % message
	chat_history.append(formatted_message)
	message_received.emit(formatted_message)

## Adds a chat message from a player to the chat history
func add_chat_message(sender_name: String, message: String, is_own_message: bool = false):
	var label = "You" if is_own_message else sender_name
	var formatted_message = "[%s]: %s" % [label, message]
	chat_history.append(formatted_message)
	message_received.emit(formatted_message)

@rpc("any_peer", "call_local", "reliable")
func receive_message(sender_id: int, sender_name: String, message: String):
	var is_own_message = PlayerManager.is_local_player(sender_id)
	add_chat_message(sender_name, message, is_own_message)

func _on_player_joined(player_data: Dictionary):
	var player_name = player_data.name
	var is_host = player_data.get("is_host", false)
	var host_suffix = " (Host)" if is_host else ""
	add_system_message("%s joined%s" % [player_name, host_suffix])

func _on_player_left(player_id: int):
	var player_name = PlayerManager.get_player_name(player_id)
	add_system_message("%s left" % player_name)

func _on_server_stopped():
	add_system_message("Server stopped")

func _on_client_disconnected():
	add_system_message("Disconnected from server")

func clear_chat():
	chat_history.clear()
	message_received.emit("")

func get_chat_history() -> Array[String]:
	return chat_history.duplicate()
