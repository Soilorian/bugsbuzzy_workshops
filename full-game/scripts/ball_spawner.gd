extends Node3D

# Ball spawning configuration
@export var ball: PackedScene
static var num_total_balls := 4
static var rng

var is_host: bool = false

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	is_host = NetworkManager.is_host
	
	# Only host spawns balls in multiplayer
	if is_host:
		get_tree().create_timer(rng.randf_range(1, 5)).timeout.connect(spawn)

func spawn():
	# Only spawn if we have authority (host)
	if is_multiplayer_authority() and num_total_balls > Ball.num_balls:
		var ball_instance := ball.instantiate() as Ball

		# Host assigns deterministic unique id and name BEFORE adding to the scene
		ball_instance.ball_id = randi() % 1000000
		ball_instance.name = "ball_%d" % ball_instance.ball_id

		# initial velocity and spawn
		ball_instance.initial_velocity = global_basis.x * 10
		get_tree().current_scene.add_child(ball_instance)
		ball_instance.global_position = global_position
		# ensure physics velocity is set immediately for host
		ball_instance.linear_velocity = ball_instance.initial_velocity.normalized() * ball_instance.speed

		# Notify all clients about the new ball (include ID)
		# reliable RPC: spawn + id + position + velocity
		spawn_ball_at_position.rpc(ball_instance.ball_id, ball_instance.global_position, ball_instance.initial_velocity)

	# schedule next spawn
	get_tree().create_timer(rng.randf_range(1, 5)).timeout.connect(spawn)

@rpc("any_peer", "reliable")
func spawn_ball_at_position(id: int, pos: Vector3, vel: Vector3):
	# Only non-authoritative instances spawn balls from RPC
	# (the host already spawned its ball locally)
	if not is_multiplayer_authority():
		var ball_instance := ball.instantiate() as Ball

		# Assign the same ID + name so subsequent RPCs map to the same node path
		ball_instance.ball_id = id
		ball_instance.name = "ball_%d" % id

		ball_instance.initial_velocity = vel
		get_tree().current_scene.add_child(ball_instance)
		ball_instance.global_position = pos
		# Set immediate linear velocity for the client-side instance
		ball_instance.linear_velocity = vel.normalized() * ball_instance.speed
