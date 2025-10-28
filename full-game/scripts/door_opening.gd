extends StaticBody3D

# This variable holds a reference to your AnimationPlayer node.
@onready var animation_player = $AnimationPlayer

# This function is called automatically when the Area3D's "body_entered" signal is emitted.
func _on_area_3d_body_entered(body):
	# We check if the body that entered belongs to the "player" group.
	if body.is_in_group("player"):
		print("Player detected, opening door!")
		# Make sure your open animation is named "Open" in the AnimationPlayer.
		animation_player.play("Open")


# This function is called when the "body_exited" signal is emitted.
func _on_area_3d_body_exited(body):
	# We check if the body that left belongs to the "player" group.
	if body.is_in_group("player"):
		print("Player left, closing door.")
		# Playing the animation backwards is an easy way to close the door.
		animation_player.play_backwards("Open")
