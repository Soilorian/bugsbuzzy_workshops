extends Area3D


# Called when the node enters the scene tree for the first time.



func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_key:
		get_node("AnimationPlayer").play("opening_door")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_key:
		get_node("AnimationPlayer").play("door_closed")
