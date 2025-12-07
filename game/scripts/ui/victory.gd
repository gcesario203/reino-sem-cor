extends Control

@onready var restart_button = $CenterContainer/VBoxContainer/RestartButton
@onready var menu_button = $CenterContainer/VBoxContainer/MenuButton

func _ready():
	# Conectar botões
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

func _on_restart_pressed():
	# Reiniciar a fase atual
	get_tree().change_scene_to_file("res://scenes/levels/turquoise_library.tscn")

func _on_menu_pressed():
	# Voltar ao menu principal
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
