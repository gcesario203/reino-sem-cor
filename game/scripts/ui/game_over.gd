extends Control

@onready var restart_button = $CenterContainer/VBoxContainer/RestartButton
@onready var menu_button = $CenterContainer/VBoxContainer/MenuButton

# Cena do nível principal para reiniciar
const LEVEL_SCENE = "res://scenes/levels/turquoise_library.tscn"

func _ready():
        # Conectar botões
        if restart_button:
                restart_button.pressed.connect(_on_restart_pressed)
        if menu_button:
                menu_button.pressed.connect(_on_menu_pressed)

func _on_restart_pressed():
        # CORRIGIDO: Era reload_current_scene() que recarregava a tela de Game Over
        # Agora carrega diretamente a cena do nível
        get_tree().change_scene_to_file(LEVEL_SCENE)

func _on_menu_pressed():
        # Voltar ao menu principal
        get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
