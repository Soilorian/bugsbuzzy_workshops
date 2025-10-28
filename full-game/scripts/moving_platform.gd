extends AnimatableBody3D

## The distance and direction the platform will travel from its starting point.
## For horizontal movement, only change the 'x' or 'z' value.
@export var travel_distance := Vector3(0.0, 0.0, -6.0)

## The time in seconds it takes to travel one way.
@export var duration: float = 4.0

func _ready():
	# This function is called when the node enters the scene tree.
	# We'll create and start the movement tween here.
	_setup_tween()

func _setup_tween():
	# Get the starting and ending positions for the movement.
	var start_position = position
	var end_position = position + travel_distance

	# A Tween animates a node's properties over time. It's perfect for this.
	var tween = create_tween()

	# Set the tween to loop infinitely.
	tween.set_loops()
	
	# Make the movement smooth by starting and ending slowly.
	tween.set_trans(Tween.TRANS_SINE) # You can also try TRANS_CUBIC

	# Animate the 'position' property from the start to the end point...
	tween.tween_property(self, "position", end_position, duration)
	
	# ...then animate it back from the end to the start point.
	tween.tween_property(self, "position", start_position, duration)
