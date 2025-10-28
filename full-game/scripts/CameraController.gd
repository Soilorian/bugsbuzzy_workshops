extends Node3D
class_name CameraController

@export var child_camera: Camera3D
@export var target: Node3D
@export var offset: Vector3 = Vector3(0, 10, 8)
@export var smoothness: float = 5.0
@export var shake_max_intensity: float = 0.5

class ShakeEvent:
	var time_remaining: float
	var intensity_scale: float

static var instance: CameraController
var active_shakes: Array[ShakeEvent] = []
var rng: RandomNumberGenerator

func _ready():
	instance = self
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var player_id = NetworkManager.get_unique_id()
	var is_local = PlayerManager.is_local_player(player_id)
	
	if is_local:
		var player_data = PlayerManager.get_player_data(player_id)
		var player_name = player_data.get("name", "Player")
		# Enable input processing for local player only
		set_process_input(true)
		print("Local player ready: ", player_name, " ID: ", player_id)
	else:
		# For remote players, disable input processing
		set_process_input(false)

static func request_shake(duration: float, intensity_scale: float = 1.0):
	if instance != null:
		var shake_event = ShakeEvent.new()
		shake_event.time_remaining = duration
		shake_event.intensity_scale = intensity_scale
		instance.active_shakes.append(shake_event)

func _physics_process(delta):
	if target != null:
		var desired_position: Vector3
		
		# Handle potential object disposal
		if not is_instance_valid(target):
			return
		
		desired_position = target.global_position + offset
		
		global_position = global_position.lerp(desired_position, 
			clamp(smoothness * delta, 0, 1))
		look_at(target.global_position)
		
		# Handle camera shake
		_process_shake(delta)

func _process_shake(delta):
	var total_current_intensity = 0.0
	
	# Process all active shakes
	for i in range(active_shakes.size() - 1, -1, -1):
		var shake = active_shakes[i]
		total_current_intensity += shake.intensity_scale
		
		shake.time_remaining -= delta
		
		if shake.time_remaining <= 0:
			active_shakes.remove_at(i)
	
	# Apply shake to camera
	if total_current_intensity > 0:
		var effective_shake_magnitude = min(shake_max_intensity, total_current_intensity)
		
		var shake_offset = Vector3(
			rng.randf_range(-effective_shake_magnitude, effective_shake_magnitude),
			rng.randf_range(-effective_shake_magnitude, effective_shake_magnitude),
			rng.randf_range(-effective_shake_magnitude, effective_shake_magnitude)
		)
		
		if child_camera:
			child_camera.position = shake_offset
	else:
		# Return camera to normal position
		if child_camera:
			child_camera.position = child_camera.position.lerp(Vector3.ZERO, 
				clamp(10.0 * delta, 0, 1))

func set_target(new_target: Node3D):
	target = new_target

func set_offset(new_offset: Vector3):
	offset = new_offset
