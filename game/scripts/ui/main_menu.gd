extends Control

@onready var start_button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
        # Tocar música do menu
        if AudioManager:
                AudioManager.play_music("menu")
        
        # Conectar botões
        if start_button:
                start_button.pressed.connect(_on_start_pressed)
                start_button.mouse_entered.connect(_on_button_hover)
        if quit_button:
                quit_button.pressed.connect(_on_quit_pressed)
                quit_button.mouse_entered.connect(_on_button_hover)

func _on_button_hover():
        if AudioManager:
                AudioManager.play_sfx("ui_select")

func _on_start_pressed():
        # Som de confirmação
        if AudioManager:
                AudioManager.play_sfx("ui_confirm")
        # Carregar a fase do jogo
        get_tree().change_scene_to_file("res://scenes/levels/turquoise_library.tscn")

func _on_quit_pressed():
        # Som de cancelar
        if AudioManager:
                AudioManager.play_sfx("ui_cancel")
        # Sair do jogo
        get_tree().quit()
