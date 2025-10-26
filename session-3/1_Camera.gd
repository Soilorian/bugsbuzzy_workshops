extends Node3D

@onready var cam_a: Camera3D = $Player/Camera
@onready var cam_b: Camera3D = $Camera3D

var using_a := false

func _ready():
	cam_a.current = false
	cam_b.current = true

func _input(event):
	if event.is_action_pressed("switch_camera"):
		print("HI")
		using_a = not using_a
		cam_a.current = using_a
		cam_b.current = not using_a
		print("Using camera:", cam_a.name if using_a	 else cam_b.name)
