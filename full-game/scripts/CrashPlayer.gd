# CrashCharacter.gd
extends CharacterBody3D
class_name CrashPlayer

## Movement parameters
const SPEED = 250
const JUMP_VELOCITY = 10.0
const DOUBLE_JUMP_VELOCITY = 10.0
const GRAVITY = 25.0
const ACCEL_RATE = 15.0
const ROTATIONAL_ACCEL = 5.0
const WIN_ROTATION_SPEED = 10.0
var score = 0
var lives = 3
var has_key = false
var is_game_over = false
var is_winning = false
##
signal lives_changed(new_lives)
signal key_status_changed(is_collected)
signal dying(is_dead)
signal winning(is_won)

const NEXT_SCENE_PATH = "res://lobby.tscn"

## Node references
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var animation_player: AnimationPlayer = $MeshInstance3D/AnimationPlayer
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var hud = get_tree().get_first_node_in_group("hud")
@onready var scene_change_timer: Timer = $Timer


## State variables
var horizontal_velocity = Vector3.ZERO
var is_jumping = false
var is_landing = false
var has_double_jumped = false
var current_animation = ""

## --- Core Godot Functions ---

func _ready():	
	if is_instance_valid(hud):
		hud.add_to_group("hud")
		
	# Ensure signal is connected
	if not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)
	play_animation("idle")

func _physics_process(delta):
	if is_game_over:
		return
		
	if is_winning:
		# 1. Float upward constantly
		if global_position.y <= 1.5:
			velocity.y = JUMP_VELOCITY * 0.5 # Constant upward float
		else:
			velocity.y = 0.0

		# 2. Spin constantly
		var rotation_change = WIN_ROTATION_SPEED * delta
		mesh.rotation.y += rotation_change
		#spring_arm.rotation.y += rotation_change

		# Since velocity is set, call move_and_slide and return to skip normal movement/gravity
		move_and_slide()
		play_animation("idle")
		return
		
	if global_position.y <= -5.0:
		take_damage()
		return
		
	# --- 1. Gravity and Floor Check ---
	if is_on_floor() and velocity.y <= 0: # Checks if on floor AND not moving upwards from jump
		velocity.y = -0.1
		is_jumping = false
		has_double_jumped = false # Reset double jump when grounded
		
		if is_landing:
			is_landing = false
			play_animation("idle")
	else:
		velocity.y -= GRAVITY * delta
		
		# Check for falling state
		if velocity.y < -0.1 and not is_jumping:
			is_landing = true
			if current_animation != "jump" and current_animation != "flip":
				play_animation("jump") # Play jump/fall animation
			
	# --- 2. Horizontal Movement ---
	var target_speed = 0.0
	var move_forward = Input.is_action_pressed("crash_forward") # Only Up Arrow moves forward

	if move_forward:
		target_speed = SPEED
		# Calculate forward direction based on the current mesh rotation
		var forward_direction = -mesh.global_transform.basis.z 
		var target_horizontal_velocity = forward_direction * target_speed
		
		# Smoothly transition velocity for acceleration
		horizontal_velocity = horizontal_velocity.lerp(target_horizontal_velocity, ACCEL_RATE * delta)
		
		if not is_jumping and not is_landing and current_animation != "run":
			play_animation("run")
	else:
		# Decelerate when no forward input
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, ACCEL_RATE * delta)
		
		if not is_jumping and not is_landing:
			play_animation("idle")

	# Apply final horizontal velocity to the CharacterBody3D's velocity
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	# Move the character
	move_and_slide()

	# --- 3. Continuous Rotation Application ---
	
	# Get rotation input from left/right arrows
	var rotate_input = Input.get_axis("crash_right", "crash_left") 

	# ❌ Change Direction while Jumping (NEW REQUIREMENT)
	# Only allow rotation if the character is NOT air-borne (not jumping AND not landing)
	if not is_jumping and not is_landing:
		# Continuous rotation based on held time (delta)
		# Rotate the mesh instance: positive for left (ui_left), negative for right (ui_right)
		mesh.rotation.y += rotate_input * ROTATIONAL_ACCEL * delta
		
		# Update the SpringArm's rotation to follow the character's facing direction
		spring_arm.rotation.y = mesh.rotation.y
	else:
		# Still ensure the SpringArm follows the character's current rotation while airborne,
		# even though the character itself isn't rotating based on input.
		spring_arm.rotation.y = mesh.rotation.y
	
	# Print position for debug
	#print("Position: ", global_position, " | Velocity magnitude: ", horizontal_velocity.length())

# --- Input Handling ---

func _input(event):
	# --- Jump/Double Jump (Uses the event type) ---
	# We can still use the event here as it filters itself to only key/button presses
	# This also makes sure the jump/spin action only triggers once per frame.

	# Check for the event *being* the action for jump
	if event.is_action_pressed("ui_accept"):
		if is_on_floor():
			# Initial Jump
			velocity.y = JUMP_VELOCITY
			is_jumping = true
			is_landing = false
			play_animation("jump")
		elif is_jumping and not has_double_jumped:
			# Double Jump (Flip)
			has_double_jumped = true
			velocity.y = DOUBLE_JUMP_VELOCITY
			play_animation("flip")
	
	# --- Ground Spin/Attack (Uses the event type) ---
	if event.is_action_pressed("ui_text_submit"):
		if is_on_floor() and not is_jumping:
			play_animation("spin")


# --- Animation Handling ---

func play_animation(anim_name: String):
	if current_animation != anim_name and animation_player.has_animation(anim_name):
		# Prioritize crucial moves
		if anim_name in ["jump", "flip", "land", "spin"]:
			animation_player.play(anim_name)
		# Only play run/idle if not in a crucial motion state
		elif not is_jumping and not is_landing and current_animation != "flip" and current_animation != "spin":
			animation_player.play(anim_name)
		current_animation = animation_player.current_animation

func _on_animation_player_animation_finished(anim_name):
	# Transitions after motion animations
	if anim_name in ["flip", "spin", "land"]:
		if not is_on_floor():
			# Transition back to the default fall/jump animation state if still air-borne
			if current_animation != "jump":
				play_animation("jump") 
		else:
			is_landing = false
			play_animation("idle")
			
func collect_coin():
	score += 1
	print("Score: ", score) # For console debug
	
	if is_instance_valid(hud):
		hud.update_score(score)


func _on_coin_collected() -> void:
	collect_coin()
	
func take_damage():
	if is_game_over:
		return
	# Only take damage if the character isn't already dying/recovering
	if lives > 0:
		lives -= 1
		lives_changed.emit(lives) # Notify the HUD

		if lives <= 0:
			print("Game Over!")
			# Add game over logic here (e.g., get_tree().reload_current_scene())
			is_game_over = true
			dying.emit(true)
			
		else:
			print("Lives remaining: ", lives)
			#if not has_key:
				#score = 0
			# Simple reposition for quick reset (adjust to your scene's start position)
			global_position = Vector3(0, 1, 0) 
			
func collect_key():
	if not has_key:
		has_key = true
		key_status_changed.emit(true) # Tell the HUD to show the icon
		print("Key collected!")


func _on_key_area_key_collected() -> void:
	collect_key()
	
func on_hit_by_enemy(apply_damage: bool = true) -> bool:
	"""
	Checks if the player is currently spinning (invincible/attacking).
	Returns true if the player is spinning (and should destroy the enemy).
	"""
	# Check if the current animation is 'spin' or 'flip' (if flip is used for spin attack)
	if current_animation == "spin":
		# Player is invincible/attacking, so the enemy should die.
		return true
	
	# Player is vulnerable, so the player should take damage.
	if apply_damage:
		take_damage() # Calls the existing take_damage() function
	return false
	
func win_game():
	if is_game_over or is_winning:
		return

	winning.emit(true)
	is_winning = true
	velocity = Vector3.ZERO # Stop all previous motion
	
	scene_change_timer.start()
	

func _on_scene_change_timer_timeout():
	is_winning = false 
	var error = get_tree().change_scene_to_file(NEXT_SCENE_PATH)
	if error != OK:
		push_error("Failed to change scene: ", error)
 


func _on_win_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		win_game()
