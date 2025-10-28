# Enemy.gd
extends CharacterBody3D

# --- Variables ---
@export var walk_speed: float = 2.0
@export var run_speed: float = 3.0
@export var patrol_range: float = 10.0
@export var rotation_speed: float = 10.0

# References to other nodes.
@onready var anim_player = $AnimationPlayer
@onready var nav_agent = $NavigationAgent3D
@onready var patrol_timer = $PatrolTimer

enum State { IDLE, PATROL, CHASING, ATTACKING, DYING }
var current_state: State = State.IDLE

# Target variable to store a reference to the player.
var player: Node3D = null
var start_position: Vector3

signal died

# --- Godot Functions ---
func _ready():
	start_position = global_position
	patrol_timer.timeout.connect(_on_patrol_timer_timeout)
	# Start in the IDLE state.
	set_state(State.IDLE)


func _physics_process(delta):
	# The state machine logic runs every physics frame.
	match current_state:
		State.IDLE:
			# FIX 2: Stop movement immediately in IDLE, prevent sliding/sliding animation bug
			velocity.x = 0
			velocity.z = 0
			# Start the timer to find a new patrol point.
			if patrol_timer.is_stopped():
				anim_player.play("Idle")
				patrol_timer.start()
				
		State.PATROL:
			# FIX 3: Combine Patrol logic with movement/rotation
			if not nav_agent.is_navigation_finished():
				var next_path_position = nav_agent.get_next_path_position()
				
				# Calculate horizontal velocity
				var direction = (next_path_position - global_position).normalized()
				velocity.x = direction.x * walk_speed
				velocity.z = direction.z * walk_speed
				
				# Smoothly rotate towards the next patrol point.
				rotate_towards(next_path_position, delta)
				
				# Play animation continuously while moving
				if anim_player.current_animation != "Walking_B":
					anim_player.play("Walking_B")
			else:
				# If navigation is finished, transition to IDLE state
				set_state(State.IDLE)

		State.CHASING:
			if player:
				nav_agent.target_position = player.global_position
				
				var next_path_position = nav_agent.get_next_path_position()
				# Calculate horizontal velocity for chasing.
				var new_velocity = (next_path_position - global_position).normalized() * run_speed
				velocity.x = new_velocity.x
				velocity.z = new_velocity.z
				# Smoothly rotate towards the player.
				rotate_towards(player.global_position, delta)
				
				#if anim_player.current_animation != "Running_C":
					#anim_player.play("Running_C")
					
			else:
				anim_player.play("Idle")

		State.ATTACKING:
			# Stop all movement when attacking.
			velocity.x = 0
			velocity.z = 0
			# Optional: Make the enemy face the player while attacking
			if player:
				rotate_towards(player.global_position, delta)

	# The final call to move_and_slide() applies the calculated velocity.
	move_and_slide()


# --- Helper Functions (REPLACED) ---
func rotate_towards(target_position: Vector3, delta: float):
	"""Helper function to handle character rotation smoothly using `look_at`."""
	
	# Calculate the direction vector on the horizontal plane
	var target_y_position = Vector3(target_position.x, global_position.y, target_position.z)
	var direction = (target_y_position - global_position).normalized()
	
	if direction != Vector3.ZERO:
		# Calculate the target rotation (target basis)
		var target_transform = Transform3D.IDENTITY.looking_at(-direction, Vector3.UP)
		
		# Get the Y rotation from the target transform
		var target_angle = target_transform.basis.get_rotation_quaternion().get_euler().y
		var current_angle = transform.basis.get_rotation_quaternion().get_euler().y
		
		# Smoothly interpolate the angle
		var new_angle = lerp_angle(current_angle, target_angle, delta * rotation_speed)
		
		# Apply the new rotation to the root CharacterBody3D
		rotation.y = new_angle
		
# --- Utility Function (Add this at the bottom of the script if it's missing) ---
# This is a standard utility function, vital for smooth rotation.
func lerp_angle(from: float, to: float, weight: float) -> float:
	var difference = fmod(to - from, 2.0 * PI)
	if difference > PI:
		difference -= 2.0 * PI
	elif difference < -PI:
		difference += 2.0 * PI
	return from + difference * weight

# --- State Machine Logic ---
func set_state(new_state: State):
	if current_state == new_state:
		return
		
	current_state = new_state
	
	match current_state:
		State.IDLE:
			# --- FIX: Added an Idle animation ---
			# Make sure you have an animation named "Idle" in your AnimationPlayer.
			anim_player.play("Idle")
		State.PATROL:
			anim_player.play("Walking_B")
			# No need to start the timer here, it's handled in the IDLE state.
		State.CHASING:
			anim_player.play("Running_C")
			patrol_timer.stop()
		State.ATTACKING:
			anim_player.play("Dualwield_Melee_Attack_Slice")


func _on_patrol_timer_timeout():
	# Only find a new patrol point if we are currently idle or patrolling.
	if current_state == State.IDLE or current_state == State.PATROL:
		var random_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		var target_position = start_position + random_direction * patrol_range
		nav_agent.target_position = target_position
		set_state(State.PATROL)


# --- Signal Connections ---
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		print("player entered")
		player = body
		set_state(State.CHASING)

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		print("player exited")
		player = null
		set_state(State.IDLE) # Go to Idle before finding a new patrol point.

func _on_attack_area_body_entered(body):
	if body.is_in_group("player"):
		print("player entered attack area")
		var player_is_attacking = body.on_hit_by_enemy(false)
		if player_is_attacking:
			# Player hit the enemy with a spin: enemy dies immediately.
			start_death_sequence()
			return
		set_state(State.ATTACKING)

func _on_attack_area_body_exited(body):
	if body.is_in_group("player"):
		print("player exited attack area")
		# If the player is still detected, chase them. Otherwise, go back to idle.
		if player != null:
			set_state(State.CHASING)
		else:
			set_state(State.IDLE)
			
func _on_animation_player_animation_finished(anim_name):
	# Only execute the cleanup if the animation that finished was the death animation
	if anim_name == "Death_A":
		# Emit the signal before removal if needed for score/drops
		died.emit()
		
		# Finally, remove the enemy node from the scene tree
		queue_free()
	
	# Handle other animation transitions here if necessary (e.g., ATTACKING back to CHASING)
	if anim_name == "Dualwield_Melee_Attack_Slice" and current_state == State.ATTACKING:
		# If the enemy finishes attacking, go back to chasing
		if is_instance_valid(player):
			set_state(State.CHASING)
		else:
			set_state(State.IDLE)

func deal_damage_to_player():
	# This function is called via the AnimationPlayer "Call Method" track.
	var bodies = $AttackArea.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			print("is getting damage")
			body.take_damage()
			
			
func start_death_sequence():
	# Stop all movement and switch to the dying state
	velocity = Vector3.ZERO
	set_state(State.DYING) # You might need a new State.DYING if you want to track it
	anim_player.play("Death_A")
