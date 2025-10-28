extends Node3D

@onready var players_container = $Players
@onready var back_button = $UI/TopPanel/BackButton
@onready var player_info_label = $UI/TopPanel/PlayerInfo
@onready var ball_spawner = $BallSpawner

var player_instances: Dictionary = {}
var local_player_instance: Player = null

# Player spawn positions
var spawn_positions = [
	Vector3(-15, 1, -15),
	Vector3(15, 1, -15),
	Vector3(-15, 1, 15),
	Vector3(15, 1, 15)
]

# Colors for players 1..4 (blue, green, yellow, red)
var player_colors = [
	Color(0.3, 0.7, 1.0),  # Blue - player 1
	Color(0.3, 1.0, 0.3),  # Green - player 2
	Color(1.0, 1.0, 0.2),  # Yellow - player 3
	Color(1.0, 0.3, 0.3)   # Red - player 4
]

func _ready():
	back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	PlayerManager.player_joined.connect(_on_player_joined)
	PlayerManager.player_left.connect(_on_player_left)
	NetworkManager.server_stopped.connect(_on_server_stopped)
	NetworkManager.client_disconnected.connect(_on_client_disconnected)
	
	# Spawn existing players
	_spawn_existing_players()
	_update_player_info()

func _spawn_existing_players():
	for player_id in PlayerManager.get_all_players().keys():
		_spawn_player(player_id)

func _spawn_player(player_id: int):
	var player_data = PlayerManager.get_player_data(player_id)
	if player_data.is_empty():
		return
	
	# Create player instance
	var player_scene = preload("res://scripts/multiplayer_player.gd")
	var player_instance = CharacterBody3D.new()
	player_instance.set_script(player_scene)
	
	# Determine spawn index and spawn position
	var spawn_index = player_instances.size() % spawn_positions.size()
	var spawn_pos = spawn_positions[spawn_index]
	player_instance.global_position = spawn_pos
	
	# Set up player with proper authority and properties
	# Pass is_local boolean so Player.setup_player can set local behaviour
	player_instance.setup_player(player_id, player_data.name, PlayerManager.is_local_player(player_id))
	
	# Initialize sync/interpolation variables on the instance so it doesn't start at Vector3.ZERO
	player_instance.last_sync_position = spawn_pos
	player_instance.last_sync_rotation = Vector3.ZERO
	player_instance.target_position = spawn_pos
	player_instance.target_rotation = Vector3.ZERO
	
	# Create graphics node for the player
	var graphics_node = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1, 2, 1)
	graphics_node.mesh = box_mesh
	
	# Set deterministic color based on spawn slot (so everyone sees same color per slot)
	var color_idx = spawn_index % player_colors.size()
	var material = StandardMaterial3D.new()
	material.albedo_color = player_colors[color_idx]
	graphics_node.material_override = material
	
	player_instance.add_child(graphics_node)
	player_instance.graphics_node = graphics_node
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1, 2, 1)
	collision_shape.shape = box_shape
	player_instance.add_child(collision_shape)
	
	# Create player name label
	var name_label = Label3D.new()
	name_label.text = player_data.name
	name_label.position = Vector3(0, 2.5, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	player_instance.add_child(name_label)
	
	# Add to scene
	player_instance.name = "player_%d" % player_id
	players_container.add_child(player_instance)
	player_instances[player_id] = player_instance
	
	# Set up camera for local player
	if player_instance.is_local:
		local_player_instance = player_instance
		_setup_camera(player_instance)
	

func _setup_camera(player: Player):
	# Before adding a new camera, ensure any existing cameras are not current
	for cam in get_tree().get_nodes_in_group("player_cameras"):
		if cam is Camera3D:
			cam.current = false
	
	# Create camera controller
	var camera_controller = Node3D.new()
	var camera_script = preload("res://scripts/CameraController.gd")
	camera_controller.set_script(camera_script)
	
	# Create camera
	var camera = Camera3D.new()
	# Add camera to a group so we can deactivate others later
	camera.add_to_group("player_cameras")
	camera_controller.add_child(camera)
	camera_controller.child_camera = camera
	camera_controller.target = player
	camera_controller.offset = Vector3(0, 10, 8)
	
	# Add camera controller to scene
	add_child(camera_controller)
	# Make this camera current (local player)
	camera.current = true

func _on_player_joined(player_data: Dictionary):
	var player_id = player_data.id
	if not player_id in player_instances:
		_spawn_player(player_id)
	_update_player_info()

func _on_player_left(player_id: int):
	if player_id in player_instances:
		player_instances[player_id].queue_free()
		player_instances.erase(player_id)
	_update_player_info()

func _update_player_info():
	var player_count = player_instances.size()
	player_info_label.text = "Players: " + str(player_count)

func _on_back_pressed():
	NetworkManager.leave_game()
	PlayerManager.clear_players()
	ChatManager.clear_chat()
	# Use call_deferred to ensure the scene change happens after the current frame
	call_deferred("_change_to_lobby")

func _change_to_lobby():
	if get_tree():
		get_tree().change_scene_to_file("res://lobby.tscn")

func _on_server_stopped():
	if get_tree():
		get_tree().change_scene_to_file("res://lobby.tscn")

func _on_client_disconnected():
	if get_tree():
		get_tree().change_scene_to_file("res://lobby.tscn")
