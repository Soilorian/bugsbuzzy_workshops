extends CharacterBody3D
class_name PlayerBody

@export var max_speed: float = 50
@export var acceleration: float = 450
@export var score_label: Label
@export var collision_shape: CollisionShape3D
@export var mesh_instance: MeshInstance3D

@export var wall_shape: CollisionShape3D
@export var area_shape: CollisionShape3D

var score := 1
var eliminated := false
#var current_speed: float = 0

func _ready() -> void:
	update_score_ui()

func _process(delta: float) -> void:
	if not eliminated:
		var axis := Input.get_axis("left", "right")
		var target_speed := axis * max_speed
		var right_direction = global_basis * Vector3.FORWARD
		var current_velocity := velocity.dot(right_direction)
		var velocity_x_local : float = clamp(move_toward(current_velocity, target_speed, acceleration * delta), -max_speed, max_speed)
		#print(target_speed, " ", right_direction, " ", velocity_x_local)
		#velocity = quaternion * Vector3.RIGHT * velocity_x_local
		velocity = right_direction.normalized() * velocity_x_local
		#quaternion.get_euler()
		#velocity.x = current_speed
		move_and_slide()
		#var collision_count := get_slide_collision_count()
		#for i in range(collision_count):
			#var collision := get_slide_collision(i)
			#print(collision.get_collider())

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is Ball:
		score -= 1
		update_score_ui()
		
		print("balls")
		(body as Ball).set_collision_layer_value(5, false)
		
		if score == 0:
			eliminate()
	#(body as CollisionObject3D).set_collision_mask_value(3, false)
	#print("baba barikallah")

func update_score_ui():
	#print(score)
	score_label.text = str(score)
	
func eliminate():
	position = Vector3.UP * 5
	wall_shape.disabled = false
	area_shape.disabled = true
	collision_shape.disabled = true
	mesh_instance.queue_free()
	
	eliminated = true
