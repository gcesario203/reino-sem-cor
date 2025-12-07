extends Control

@onready var start_button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
	# Conectar botões
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed():
	# Carregar a fase do jogo
	get_tree().change_scene_to_file("res://scenes/levels/turquoise_library.tscn")

func _on_quit_pressed():
	# Sair do jogo
	get_tree().quit()
