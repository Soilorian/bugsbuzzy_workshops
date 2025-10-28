# Keyring.gd
extends Area3D

signal key_collected

func _ready():
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	# Check if the colliding body is the player
	if body.is_in_group("player"):
		# 1. Emit the signal to notify the game that the key was found
		key_collected.emit()
		# 2. Remove the key from the scene
		queue_free()
