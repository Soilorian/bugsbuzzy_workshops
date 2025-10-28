# DeadTrapTrigger.gd
extends Area3D

func _ready():
	# Connect the signal in code
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	# Check if the colliding body is the player group
	if body.is_in_group("player"):
		# Call the damage function on the player instance
		if body.has_method("take_damage"):
			body.take_damage()
