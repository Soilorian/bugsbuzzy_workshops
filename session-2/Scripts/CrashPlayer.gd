# CrashCharacter.gd
extends CharacterBody3D

## ⚙️ MOVEMENT CONSTANTS
# Movement speed on the horizontal plane (X/Z).
const SPEED = 250.0
# Initial vertical velocity for the first jump.
const JUMP_VELOCITY = 10.0
# Initial vertical velocity for the double jump (spin/flip).
const DOUBLE_JUMP_VELOCITY = 10.0
# Gravity acceleration per second.
const GRAVITY = 25.0
# Rate for linear interpolation (lerp) used for smooth acceleration/deceleration.
const ACCEL_RATE = 15.0
# Speed multiplier for rotation input.
const ROTATIONAL_ACCEL = 5.0

## 🪢 NODE REFERENCES
# Reference to the visual 3D model.
@onready var mesh: MeshInstance3D = $MeshInstance3D
# Reference to the AnimationPlayer node, which handles all animation playback.
@onready var animation_player: AnimationPlayer = $MeshInstance3D/AnimationPlayer
# Reference to the SpringArm node, which manages the camera's position relative to the character.
@onready var spring_arm: SpringArm3D = $SpringArm3D

## 🧠 STATE VARIABLES
# Velocity used for horizontal (X/Z) movement, calculated separately from vertical (Y).
var horizontal_velocity = Vector3.ZERO
# Tracks if the character is currently performing a jump.
var is_jumping = false
# Tracks if the character is currently landing.
var is_landing = false
# Tracks if the double jump has been used since the last time the character was grounded.
var has_double_jumped = false
# Stores the name of the animation currently being played.
var current_animation = ""

## --- CORE GODOT FUNCTIONS ---

func _ready():
	# Connect the AnimationPlayer's signal to handle animation transitions once an animation finishes.
	if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	
	# Start the character in the default idle state.
	play_animation("idle")

func _physics_process(delta):
	# Apply gravity to the character's vertical velocity every physics step.
	_apply_gravity(delta)
	
	# Handle the character's forward/backward movement and speed application.
	_handle_horizontal_movement(delta)
	
	# Handle the character's rotation based on input.
	_handle_rotation(delta)
	
	# Apply the final calculated velocity vector to the physics body.
	# This function moves the body and automatically handles collision and sliding.
	move_and_slide()

func _input(event):
	# Handle instantaneous, non-continuous actions like jumps and spins.
	# Using _input is best for discrete events to ensure they only register once per key press.
	
	# Jump/Double Jump input handling (using "ui_accept" action).
	if event.is_action_pressed("ui_accept"):
		_handle_jump()
	
	# Ground Spin/Attack input handling (using "ui_text_submit" action).
	if event.is_action_pressed("ui_text_submit"):
		_handle_spin()

## --- MOVEMENT HELPERS ---

func _apply_gravity(delta):
	# Check if the character has just landed on a solid surface.
	if is_on_floor() and velocity.y <= 0:
		# Keep a tiny negative velocity to ensure constant floor detection.
		velocity.y = -0.1
		is_jumping = false
		has_double_jumped = false # Reset double jump when grounded.
		
		# If we were in the process of landing, transition to idle.
		if is_landing:
			is_landing = false
			play_animation("idle")
	else:
		# Apply gravity, accelerating the fall.
		velocity.y -= GRAVITY * delta
		
		# If the character is falling (velocity is negative) and not intentionally jumping up,
		# ensure the fall animation is playing.
		if velocity.y < -0.1 and not is_jumping:
			is_landing = true
			if current_animation != "jump" and current_animation != "flip":
				play_animation("jump")

func _handle_horizontal_movement(delta):
	var target_speed = 0.0
	var move_forward = Input.is_action_pressed("ui_up") # Only Up Arrow is used for forward movement.

	if move_forward:
		target_speed = SPEED
		# Calculate the forward direction vector based on the character's current visual rotation (mesh).
		var forward_direction = -mesh.global_transform.basis.z
		var target_horizontal_velocity = forward_direction * target_speed
		
		# Smoothly accelerate towards the target speed using linear interpolation (lerp).
		horizontal_velocity = horizontal_velocity.lerp(target_horizontal_velocity, ACCEL_RATE * delta)
		
		# Play the run animation if not currently jumping or landing from a fall/action.
		if not is_jumping and not is_landing and current_animation != "run":
			play_animation("run")
	else:
		# Smoothly decelerate to a stop when no forward input is pressed.
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, ACCEL_RATE * delta)
		
		# Play the idle animation if the character is grounded and not moving.
		if not is_jumping and not is_landing and horizontal_velocity.length_squared() < 0.1:
			play_animation("idle")

	# Update the main velocity vector with the calculated horizontal components.
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

func _handle_rotation(delta):
	# Get rotation input from left/right arrows (Axis value will be -1 for left, 1 for right).
	var rotate_input = Input.get_axis("ui_right", "ui_left")

	# The character can only change its horizontal direction (turn) when grounded.
	if is_on_floor():
		# Continuous rotation based on held time (delta).
		# Rotates the visual mesh instance around the Y-axis.
		mesh.rotation.y += rotate_input * ROTATIONAL_ACCEL * delta
	
	# The SpringArm (and camera) should always follow the character's current facing direction,
	# regardless of whether the character is grounded or airborne.
	spring_arm.rotation.y = mesh.rotation.y

func _handle_jump():
	if is_on_floor():
		# Initial Jump: Apply upward velocity and set jump states.
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		is_landing = false
		play_animation("jump")
	elif is_jumping and not has_double_jumped:
		# Double Jump (Flip): Apply a second upward velocity and prevent further air-jumps.
		has_double_jumped = true
		velocity.y = DOUBLE_JUMP_VELOCITY
		play_animation("flip")

func _handle_spin():
	if is_on_floor() and not is_jumping:
		# Ground Spin: Triggers a short attack animation when grounded.
		play_animation("spin")

## --- ANIMATION & SIGNAL HANDLERS ---

func play_animation(anim_name: String):
	# Only proceed if the animation name is different and exists in the AnimationPlayer.
	if current_animation != anim_name and animation_player.has_animation(anim_name):
		
		# Priority Logic: These animations must play immediately.
		if anim_name in ["jump", "flip", "spin"]:
			animation_player.play(anim_name)
			
		# Non-Priority Logic: Only play idle/run if not currently in a crucial motion state (like spin).
		elif not is_jumping and not is_landing and current_animation not in ["flip", "spin"]:
			animation_player.play(anim_name)
			
		# Update the tracking variable to the animation that was just played.
		current_animation = animation_player.current_animation

func _on_animation_player_animation_finished(anim_name):
	# This function handles what happens AFTER a short, non-looping animation (like a jump or spin) completes.
	
	if anim_name in ["flip", "spin"]:
		if not is_on_floor():
			# If the character finished a flip/spin but is still in the air, transition to the fall animation.
			if current_animation != "jump":
				play_animation("jump")
		else:
			# If the character landed while the animation was playing, transition to the default grounded state.
			is_landing = false
			# Play run or idle based on current input after the action finishes.
			if Input.is_action_pressed("ui_up"):
				play_animation("run")
			else:
				play_animation("idle")
