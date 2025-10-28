# HUD.gd
extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var lives_label = $LivesLabel
@onready var key_icon = $KeyIcon
@onready var game_over = $GameOver
@onready var win_label = $Win

func _ready():
	# Find the Player to connect to its signal
	var player = get_tree().get_first_node_in_group("player")
	
	#if is_instance_valid(player):
		# Connect the custom signal 'lives_changed'
		#player.lives_changed.connect(update_lives)
		# Initialize the display with the starting lives value
		#update_lives(player.lives)
		#player.key_status_changed.connect(update_key_status)
		#player.dying.connect(game_over_show)
		#player.winning.connect(win_label_show)
	#else:
		#print("HUD ERROR: Could not find Player node in group 'player'.")

func update_score(new_score: int):
	score_label.text = "x " + str(new_score)
	
func update_lives(new_lives: int):
	lives_label.text = "x " + str(new_lives)
	
func update_key_status(is_collected: bool):
	# Shows the icon if the key is collected (true)
	key_icon.visible = is_collected
	
func game_over_show(is_dead: bool):
	game_over.visible = is_dead
	
func win_label_show(is_won: bool):
	win_label.visible = is_won
