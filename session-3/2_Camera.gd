extends Node3D

@onready var cam_a: Camera3D = $Player/Camera
@onready var cam_b: Camera3D = $Camera3D

var using_a := false

func _ready():
	cam_a.current = false
	cam_b.current = true

func _input(event):
	if event.is_action_pressed("switch_camera"):
		using_a = not using_a
		var target_cam: Camera3D = cam_a if using_a else cam_b
		switch_with_blend(target_cam, 0.6)
		print("Using camera:", cam_a.name if using_a else cam_b.name)


func switch_with_blend(to_cam: Camera3D, duration := 0.6) -> void:
	var trans_cam := Camera3D.new()
	add_child(trans_cam)
	trans_cam.projection = cam_a.projection
	trans_cam.fov = cam_a.fov
	trans_cam.global_transform = cam_a.global_transform if cam_a.current else cam_b.global_transform
	trans_cam.current = true

	var tw = create_tween()
	tw.tween_property(trans_cam, "global_transform", to_cam.global_transform, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(trans_cam, "fov", to_cam.fov, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw.connect("finished", Callable(self, "_on_blend_finished").bind(trans_cam, to_cam))


func _on_blend_finished(trans_cam: Camera3D, target_cam: Camera3D) -> void:
	target_cam.current = true
	if is_instance_valid(trans_cam):
		trans_cam.queue_free()

