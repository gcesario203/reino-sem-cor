extends Node
class_name PhaseTransitionManager

# Referências
var player: CharacterBody2D = null
var boss: Node2D = null
var trigger_area: Area2D = null
var transition_ui: ColorRect = null

# Estado
var is_transitioning: bool = false
var has_transitioned: bool = false

# Configurações
@export var fade_duration: float = 0.5
@export var restore_player_resources: bool = true

# Sinais
signal transition_started()
signal transition_completed()

func _ready():
	# Procura referências
	find_references()
	
	# Conecta trigger se encontrado
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
		print("Sistema de transição de fase configurado")

func find_references():
	"""Encontra referências necessárias na cena"""
	# Jogador
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	
	# Boss
	var bosses = get_tree().get_nodes_in_group("boss")
	if bosses.size() > 0:
		boss = bosses[0]
	
	# Trigger de transição
	var triggers = get_tree().get_nodes_in_group("phase_transition_trigger")
	if triggers.size() > 0:
		trigger_area = triggers[0]

func _on_trigger_body_entered(body):
	"""Detecta quando jogador entra no trigger"""
	if has_transitioned or is_transitioning:
		return
	
	if body == player:
		print("Trigger de transição ativado!")
		start_transition()

func start_transition():
	"""Inicia transição para Fase 2"""
	if is_transitioning or has_transitioned:
		return
	
	is_transitioning = true
	has_transitioned = true
	
	transition_started.emit()
	
	# Cria UI de fade
	create_transition_ui()
	
	# Fade out
	await fade_out()
	
	# Executa transição
	perform_transition()
	
	# Fade in
	await fade_in()
	
	# Remove UI de fade
	remove_transition_ui()
	
	is_transitioning = false
	transition_completed.emit()
	
	print("Transição para Fase 2 completa!")

func create_transition_ui():
	"""Cria overlay de fade"""
	transition_ui = ColorRect.new()
	transition_ui.color = Color.BLACK
	transition_ui.modulate.a = 0.0
	
	# Cria como CanvasLayer para ficar acima de tudo
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.name = "TransitionCanvas"
	
	# Configura tamanho para cobrir tela inteira
	transition_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_ui.size = get_viewport().get_visible_rect().size
	
	canvas_layer.add_child(transition_ui)
	get_tree().root.add_child(canvas_layer)

func fade_out():
	"""Fade para preto"""
	if not transition_ui:
		return
	
	var tween = create_tween()
	tween.tween_property(transition_ui, "modulate:a", 1.0, fade_duration)
	await tween.finished

func fade_in():
	"""Fade de preto"""
	if not transition_ui:
		return
	
	var tween = create_tween()
	tween.tween_property(transition_ui, "modulate:a", 0.0, fade_duration)
	await tween.finished

func remove_transition_ui():
	"""Remove overlay de fade"""
	if transition_ui:
		var canvas = transition_ui.get_parent()
		if canvas:
			canvas.queue_free()
		transition_ui = null

func perform_transition():
	"""Executa a transição propriamente dita"""
	# 1. Muda boss para Fase 2
	if boss and boss.has_method("change_to_phase_2"):
		boss.change_to_phase_2()
		
		# Atualiza arena bounds do boss
		if boss.has("arena_bounds"):
			boss.arena_bounds = Rect2(200, 0, 1000, 600)
	
	# 2. Posiciona jogador no spawn da arena
	if player:
		var spawn_points = get_tree().get_nodes_in_group("player_spawn_arena")
		if spawn_points.size() > 0:
			player.global_position = spawn_points[0].global_position
		else:
			# Posição padrão se não houver spawn point
			player.global_position = Vector2(400, 500)
		
		# Reseta velocidade do jogador
		player.velocity = Vector2.ZERO
		
		# Restaura recursos se configurado
		if restore_player_resources:
			restore_player_hp_mp_stamina()
	
	# 3. Desativa trigger de transição
	if trigger_area:
		trigger_area.monitoring = false
		trigger_area.visible = false

func restore_player_hp_mp_stamina():
	"""Restaura HP, MP e Stamina do jogador (opcional)"""
	if not player:
		return
	
	# HP
	if player.has("current_health") and player.has("max_health"):
		player.current_health = player.max_health
		print("HP do jogador restaurado")
	
	# MP
	if player.has("current_mp") and player.has("max_mp"):
		player.current_mp = player.max_mp
		print("MP do jogador restaurado")
	
	# Stamina
	if player.has("current_stamina") and player.has("max_stamina"):
		player.current_stamina = player.max_stamina
		print("Stamina do jogador restaurada")
	
	# Atualiza HUD se existir
	if player.has_method("update_hud"):
		player.update_hud()
