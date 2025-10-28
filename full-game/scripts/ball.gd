extends RigidBody3D
class_name Ball

# Ball physics parameters
@export var initial_velocity: Vector3
@export var speed: float = 20
var velocity: Vector3
static var num_balls := 0

# Multiplayer synchronization - optimized for performance
var ball_id: int = -1
var last_sync_position: Vector3 = Vector3.ZERO
var last_sync_velocity: Vector3 = Vector3.ZERO
var sync_threshold: float = 0.8  # Increased threshold for balls to reduce network traffic
var sync_timer: float = 0.0
var sync_interval: float = 1.0 / 12.0  # Reduced to 12 Hz for better performance

# Interpolation for smooth ball movement on non-authoritative clients
var target_position: Vector3 = Vector3.ZERO
var target_velocity: Vector3 = Vector3.ZERO
var interpolation_speed: float = 6.0  # Ball interpolation speed

func _ready() -> void:
	# If the host already set ball_id before adding, keep it.
	# Otherwise, if this node is authoritative and no id was assigned, generate one.
	if ball_id == -1 and is_multiplayer_authority():
		ball_id = randi() % 1000000
		name = "ball_%d" % ball_id

	# set initial linear velocity (safe if initial_velocity is zero)
	if initial_velocity != Vector3.ZERO:
		linear_velocity = initial_velocity.normalized() * speed

	num_balls += 1

	# initialize last sync values and targets
	last_sync_position = global_position
	last_sync_velocity = linear_velocity
	target_position = global_position
	target_velocity = linear_velocity

func _physics_process(delta: float) -> void:
	# Only the authoritative instance simulates & broadcasts
	if is_multiplayer_authority():
		velocity = linear_velocity
		
		# Sync ball position for multiplayer with throttling
		sync_timer += delta
		if sync_timer >= sync_interval:
			_sync_ball_state()
			sync_timer = 0.0
		
		# Check if ball fell off the map
		if global_position.y < -2:
			num_balls -= 1
			# reliable destroy RPC so all peers remove the ball
			destroy_ball.rpc(ball_id)
			queue_free()
	else:
		# For non-authoritative clients, interpolate towards target position
		_interpolate_ball_state(delta)
	#print(name, " ", velocity.length())

func _sync_ball_state():
	var position_diff = global_position.distance_to(last_sync_position)
	var velocity_diff = linear_velocity.distance_to(last_sync_velocity)
	
	# Adaptive threshold based on ball speed - sync more frequently for fast-moving balls
	var ball_speed = linear_velocity.length()
	var adaptive_threshold = sync_threshold
	if ball_speed > 15.0:
		adaptive_threshold *= 0.5  # Reduce threshold for fast-moving balls
	
	if position_diff > adaptive_threshold or velocity_diff > 2.0:
		# Broadcast ball transform to all peers (unreliable is fine for frequent transforms)
		rpc("sync_ball_transform", ball_id, global_position, linear_velocity)
		last_sync_position = global_position
		last_sync_velocity = linear_velocity

@rpc("any_peer", "unreliable")
func sync_ball_transform(id: int, pos: Vector3, vel: Vector3):
	# Only respond if this node represents that ball id
	if ball_id == id:
		# Set target positions for smooth interpolation instead of immediate lerp
		target_position = pos
		target_velocity = vel

## Interpolates ball towards target position for smooth movement on non-authoritative clients
func _interpolate_ball_state(delta: float):
	# Smoothly interpolate position and velocity
	global_position = global_position.lerp(target_position, clamp(interpolation_speed * delta, 0, 1))
	linear_velocity = linear_velocity.lerp(target_velocity, clamp(interpolation_speed * delta, 0, 1))

@rpc("any_peer", "reliable")
func destroy_ball(id: int):
	if ball_id == id:
		num_balls -= 1
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("ground"):
		(body as PhysicsBody3D).axis_lock_linear_y = true
	#print("_on_body_entered ", body.name)
	
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var count := state.get_contact_count()
	
	for i in range(count):
		var body := state.get_contact_collider_object(i) as CollisionObject3D
		var normal := state.get_contact_local_normal(i)
		
		# Handle reflection with players and walls
		if body.is_in_group("reflect_ball") and normal.dot(velocity) < 0 and get_collision_layer_value(5):
			state.linear_velocity = velocity.bounce(normal)
			# Sync the bounce to other clients (unreliable)
			rpc("sync_ball_transform", ball_id, global_position, state.linear_velocity)
			
	# Maintain consistent speed but allow for more natural physics
	var current_speed = state.linear_velocity.length()
	if current_speed > 0.1:
		state.linear_velocity = state.linear_velocity.normalized() * speed
