extends CharacterBody3D
class_name Player2

# Player movement and physics parameters
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var stop_acceleration: float = 10.0
@export var start_acceleration: float = 20.0
@export var rotation_speed: float = 0.2
@export var rotation_acceleration: float = 1.0
@export var impulse_multiplier: float = 1.0
@export var impulse_mass: float = 10.0

# Visual and camera references
@export var graphics_node: Node3D
@export var player_cam: Camera3D

# Player state variables
var current_speed: float = 0.0
var current_rotation_speed: float = 0.0
var player_id: int = -1
var player_name: String = ""
var is_local: bool = false

# Multiplayer synchronization - optimized for smoother performance
var last_sync_position: Vector3 = Vector3.ZERO
var last_sync_rotation: Vector3 = Vector3.ZERO
var sync_threshold: float = 0.15  # Increased threshold to reduce network traffic
var sync_timer: float = 0.0
var sync_interval: float = 1.0 / 15.0  # 15 Hz

# Interpolation variables for smooth remote player movement
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
var interpolation_speed: float = 8.0  # How fast to interpolate to target position

func _ready():
	current_speed = walk_speed
	# IMPORTANT: Do NOT assume player_id here. setup_player will assign id and is_local.
	# Input processing will be set in setup_player() depending on is_local.

func _input(_event):
	# Only local player handles input
	if not is_local:
		return
	# Input handled in _physics_process for deterministic movement

func _physics_process(delta):
	# Only process local movement for the authoritative (local) player
	if is_local and is_multiplayer_authority():
		_handle_local_input(delta)
	
	# Apply gravity for all players
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	# Handle collisions with rigid bodies
	var collision_count = get_slide_collision_count()
	for i in range(collision_count):
		var collision = get_slide_collision(i)
		if collision.get_collider() is RigidBody3D:
			var rb = collision.get_collider() as RigidBody3D
			var impulse = -collision.get_normal() * impulse_multiplier
			var point = collision.get_position() - rb.global_position
			rb.apply_force(impulse, point)
	
	# Synchronize position for authoritative/local player with throttling
	if is_local and is_multiplayer_authority():
		sync_timer += delta
		if sync_timer >= sync_interval:
			_sync_position_if_needed()
			sync_timer = 0.0
			
	# Interpolation for remote players (local player will be authoritative so interpolation has no effect)
	_interpolate_to_target(delta)
		

func _handle_local_input(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var target_speed = run_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	current_speed = lerp(current_speed, target_speed, clamp(start_acceleration * delta, 0, 1))
	
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, start_acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, start_acceleration * delta)
		
		# Handle rotation of the visible graphics node
		if graphics_node:
			var rot_from = graphics_node.rotation.y
			var rot_to = atan2(-velocity.x, -velocity.z)
			# Use lerp_angle to smoothly rotate
			var rot = lerp_angle(rot_from, rot_to, clamp(rotation_speed * delta * 10.0, 0, 1))
			graphics_node.rotation = Vector3(0, rot, 0)
	else:
		velocity.x = move_toward(velocity.x, 0, stop_acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, stop_acceleration * delta)
	
	move_and_slide()

func _sync_position_if_needed():
	var position_diff = global_position.distance_to(last_sync_position)
	var rotation_diff = graphics_node.rotation.distance_to(last_sync_rotation) if graphics_node else 0.0
	
	# Adaptive threshold
	var movement_speed = Vector2(velocity.x, velocity.z).length()
	var adaptive_threshold = sync_threshold
	if movement_speed < 1.0:
		adaptive_threshold *= 2.0
	
	if position_diff > adaptive_threshold or rotation_diff > 0.1:
		# Broadcast to all peers (unreliable RPC is fine for frequent transforms)
		rpc("sync_player_transform", player_id, global_position, graphics_node.rotation if graphics_node else Vector3.ZERO)
		last_sync_position = global_position
		last_sync_rotation = graphics_node.rotation if graphics_node else Vector3.ZERO

@rpc("any_peer", "call_local", "unreliable")
func sync_player_transform(_id: int, pos: Vector3, rot: Vector3):
	# Ignore updates for local player's own id (don't overwrite local movement)
	if is_local and player_id == _id:
		return
	
	# If this update describes us (match by id), apply as remote target
	if player_id == _id:
		# If the update is far away, snap to avoid falling through ground or huge lerp artifacts
		if global_position.distance_to(pos) > 4.0:
			global_position = pos
			# also reset velocity y to avoid falling
			velocity.y = 0.0
		else:
			target_position = pos
		target_rotation = rot

## Interpolates remote player towards target position for smooth movement
func _interpolate_to_target(delta: float):
	# Only interpolate for non-local players
	if is_local:
		return
	# Smoothly interpolate position
	global_position = global_position.lerp(target_position, clamp(interpolation_speed * delta, 0, 1))
	
	# Smoothly interpolate rotation of graphics node
	if graphics_node:
		graphics_node.rotation = graphics_node.rotation.lerp(target_rotation, clamp(interpolation_speed * delta, 0, 1))

func set_player_name(new_name: String):
	player_name = new_name
	# Update any UI elements if needed

func setup_player(id: int, username: String, is_local_player: bool):
	player_id = id
	player_name = username
	is_local = is_local_player
	
	# Set multiplayer authority to the player's unique ID for proper authority control
	# (authority should be the peer that "owns" this player)
	set_multiplayer_authority(player_id)
	
	# Initialize interpolation + last sync vars from current transform so remote players don't start at zero
	target_position = global_position
	target_rotation = graphics_node.rotation if graphics_node else Vector3.ZERO
	last_sync_position = global_position
	last_sync_rotation = graphics_node.rotation if graphics_node else Vector3.ZERO
	
	# Process input only for local player
	if is_local:
		set_process_input(true)
		set_physics_process(true)
	else:
		set_process_input(false)
		set_physics_process(true) # still need physics for interpolation and gravity
	

func get_player_data() -> Dictionary:
	return {
		"id": player_id,
		"name": player_name,
		"position": global_position,
		"is_local": is_local
	}
