extends Control

@onready var username_input = $HBoxContainer/LeftVBoxContainer/usernameHBox/username_input
@onready var ip_input = $HBoxContainer/LeftVBoxContainer/IpHBox/ip_input
@onready var join_ip_input = $HBoxContainer/LeftVBoxContainer/joinIpHBox/join_ip_input
@onready var host_button = $HBoxContainer/LeftVBoxContainer/host_button
@onready var join_button = $HBoxContainer/LeftVBoxContainer/join_button
@onready var leave_button = $HBoxContainer/LeftVBoxContainer/leave_button
@onready var start_button = $HBoxContainer/LeftVBoxContainer/start_button
@onready var status_label = $HBoxContainer/LeftVBoxContainer/status_label

@onready var player_list = $HBoxContainer/RightVBoxContainer/player_list
@onready var chat_log = $HBoxContainer/RightVBoxContainer/chat_log
@onready var chat_input = $HBoxContainer/RightVBoxContainer/usernameHBox/chat_input
@onready var send_button = $HBoxContainer/RightVBoxContainer/usernameHBox/send_button

func _ready():
	_connect_signals()
	ChatManager.message_received.connect(_on_message_received)
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.player_left.connect(_on_player_left)
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.server_stopped.connect(_on_server_stopped)
	NetworkManager.client_connected.connect(_on_client_connected)
	NetworkManager.client_disconnected.connect(_on_client_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)

func _connect_signals():
	host_button.connect("pressed", Callable(self, "_on_host_pressed"))
	join_button.connect("pressed", Callable(self, "_on_join_pressed"))
	leave_button.connect("pressed", Callable(self, "_on_leave_pressed"))
	start_button.connect("pressed", Callable(self, "_on_start_pressed"))
	send_button.connect("pressed", Callable(self, "_on_send_pressed"))
	chat_input.connect("text_submitted", Callable(self, "_on_chat_text_submitted"))

func _on_host_pressed():
	var username = username_input.text.strip_edges()
	if username == "":
		status_label.text = "Enter username first."
		return
	
	if NetworkManager.start_host():
		PlayerManager.register_local_player(username)
		ip_input.text = NetworkManager.get_local_ip()
		status_label.text = "Hosting as %s" % username
		_update_player_list()
		# Disable username field after successful host
		username_input.editable = false

func _on_join_pressed():
	var username = username_input.text.strip_edges()
	if username == "":
		status_label.text = "Enter username first."
		return
		
	var ip = join_ip_input.text.strip_edges()
	if ip == "":
		status_label.text = "Enter IP to join."
		return
	
	if NetworkManager.join_server(ip):
		PlayerManager.register_local_player(username)
		status_label.text = "Connecting to %s..." % ip
		# Disable username field after successful join attempt
		username_input.editable = false

func _on_leave_pressed():
	NetworkManager.leave_game()
	PlayerManager.clear_players()
	ChatManager.clear_chat()
	player_list.clear()
	status_label.text = "Left game."
	# Re-enable username field when leaving
	username_input.editable = true

func _on_start_pressed():
	if not NetworkManager.is_host:
		status_label.text = "Only host can start."
		return
	
	# Tell all clients to start the game
	rpc("start_game")

@rpc("authority", "call_local", "reliable")
func start_game():
	if not is_inside_tree():
		await ready
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/MultiplayerGameScene.tscn")
	else:
		push_error("Scene tree not ready yet.")

func _on_send_pressed():
	var message = chat_input.text.strip_edges()
	if message != "":
		ChatManager.send_message(message)
		chat_input.text = ""

func _on_chat_text_submitted(_text: String):
	_on_send_pressed()

func _on_message_received(message: String):
	if message == "":
		chat_log.text = ""
	else:
		chat_log.text += message + "\n"

func _on_player_joined(_player_data: Dictionary):
	_update_player_list()

func _on_player_left(_player_id: int):
	_update_player_list()

func _update_player_list():
	player_list.clear()
	for player_id in PlayerManager.get_all_players().keys():
		var player_data = PlayerManager.get_player_data(player_id)
		var display_name = player_data.name
		if player_data.get("is_host", false):
			display_name += " (Host)"
		player_list.add_item(display_name)

func _on_server_started():
	status_label.text = "Server started successfully."

func _on_server_stopped():
	status_label.text = "Server stopped."

func _on_client_connected():
	status_label.text = "Connected to server."

func _on_client_disconnected():
	status_label.text = "Disconnected from server."

func _on_connection_failed():
	status_label.text = "Connection failed."
