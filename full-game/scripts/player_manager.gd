extends Node3D

@export var score_label: Label
@export var body: CharacterBody3D

func _enter_tree() -> void:
	(body as PlayerBody).score_label = score_label
	
