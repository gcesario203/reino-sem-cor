extends Node2D

# ===============================================================
# CONFIGURAÇÃO DO NÍVEL
# Fase vertical invertida (Y diminui ao subir)
# ===============================================================

@export var section_height: float = 1080.0
@export var total_sections: int = 4
@export var arena_y_start: float = 0.0
@export var player_start_y: float = 4320.0

enum PhaseState {
	PHASE_1_ESCAPE,
	TRANSITION,
	PHASE_2_BOSS
}

var current_phase: PhaseState = PhaseState.PHASE_1_ESCAPE
var current_section: int = 1
var checkpoints: Dictionary = {}

# ---------------------------------------------------------------
# Referências
# ---------------------------------------------------------------

@onready var player = $Player
@onready var boss = $Boss
@onready var camera = $Camera2D
@onready var phase_transition = $PhaseTransitionArea
@onready var enemies_container = $Enemies
@onready var potions_container = $Potions
@onready var platforms_container = $Platforms

# ---------------------------------------------------------------
# NOVO: Redução Forte — 1 inimigo por seção, alternando rato/sapo
# ---------------------------------------------------------------

var enemy_spawn_data = {
	1: {
		"rats": [
			{"position": Vector2(300, 4020), "patrol_range": 200}
		],
		"frogs": []
	},
	2: {
		"rats": [],
		"frogs": [
			{"position": Vector2(600, 2270), "patrol_range": 250}
		]
	},
	3: {
		"rats": [
			{"position": Vector2(300, 1920), "patrol_range": 150}
		],
		"frogs": []
	},
	4: {
		"rats": [],
		"frogs": [
			{"position": Vector2(300, 520), "patrol_range": 250}
		]
	}
}

# ---------------------------------------------------------------
# POTIONS (mantidas)
# ---------------------------------------------------------------

var potion_spawn_data = {
	1: [
		{"type": 0, "position": Vector2(250, 4070)},
		{"type": 1, "position": Vector2(950, 4070)}
	],
	2: [
		{"type": 2, "position": Vector2(800, 3170)},
		{"type": 0, "position": Vector2(350, 2870)},
		{"type": 1, "position": Vector2(850, 2570)}
	],
	3: [
		{"type": 0, "position": Vector2(250, 1970)},
		{"type": 2, "position": Vector2(850, 1670)}
	],
	4: [
		{"type": 1, "position": Vector2(850, 870)},
		{"type": 2, "position": Vector2(300, 570)}
	],
	5: [
		{"type": 0, "position": Vector2(250, 300)},
		{"type": 1, "position": Vector2(950, 300)},
		{"type": 2, "position": Vector2(600, 450)}
	]
}

# ---------------------------------------------------------------

func _ready():
	setup_level()
	setup_camera()
	spawn_all_enemies()
	spawn_all_potions()
	setup_checkpoints()
	setup_boss_phase_1()
	connect_signals()

# ---------------------------------------------------------------

func setup_level():
	print("Biblioteca Turquesa - Iniciando fase...")
	current_phase = PhaseState.PHASE_1_ESCAPE

func setup_camera():
	if camera:
		camera.zoom = Vector2(1.5, 1.5)
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.0

		camera.limit_left = 0
		camera.limit_right = 1920
		camera.limit_top = -200
		camera.limit_bottom = 4800

		if player:
			camera.reparent(player)

# ---------------------------------------------------------------

func spawn_all_enemies():
	var rat_scene = preload("res://scenes/enemies/rat.tscn")
	var frog_scene = preload("res://scenes/enemies/frog.tscn")

	for section in enemy_spawn_data.keys():
		var section_data = enemy_spawn_data[section]

		for rat_data in section_data.get("rats", []):
			var rat = rat_scene.instantiate()
			rat.global_position = rat_data["position"]
			rat.patrol_distance = rat_data["patrol_range"]
			enemies_container.add_child(rat)

		for frog_data in section_data.get("frogs", []):
			var frog = frog_scene.instantiate()
			frog.global_position = frog_data["position"]
			frog.patrol_distance = frog_data["patrol_range"]
			enemies_container.add_child(frog)

	print("Inimigos spawnados: ", enemies_container.get_child_count())

# ---------------------------------------------------------------

func spawn_all_potions():
	var potion_scene = preload("res://scenes/items/potion.tscn")

	for section in potion_spawn_data.keys():
		for potion_data in potion_spawn_data[section]:
			var potion = potion_scene.instantiate()
			potion.global_position = potion_data["position"]
			potion.potion_type = potion_data["type"]
			potions_container.add_child(potion)

	print("Frascos de tinta spawnados: ", potions_container.get_child_count())

# ---------------------------------------------------------------

func setup_checkpoints():
	checkpoints[1] = Vector2(600, 4200)
	checkpoints[2] = Vector2(600, 3100)
	checkpoints[3] = Vector2(600, 2000)
	checkpoints[4] = Vector2(600, 900)
	checkpoints[5] = Vector2(600, 300)

# ---------------------------------------------------------------

func setup_boss_phase_1():
	if boss:
		boss.global_position = Vector2(600, 2520)
		boss.current_phase = JellyfishBoss.BossPhase.PHASE_1_CHASE
		boss.player_ref = player

# ---------------------------------------------------------------

func connect_signals():
	if phase_transition:
		phase_transition.body_entered.connect(_on_phase_transition_entered)
	if player:
		player.died.connect(_on_player_died)
	if boss:
		boss.phase_changed.connect(_on_boss_phase_changed)
		boss.boss_defeated.connect(_on_boss_defeated)

# ---------------------------------------------------------------

func _process(delta):
	update_current_section()
	update_boss_behavior()

# ---------------------------------------------------------------
# CÁLCULO CORRETO DA SEÇÃO
# ---------------------------------------------------------------

func update_current_section():
	if not player:
		return

	var y = player.global_position.y
	var new_section = get_section_from_y(y)

	if new_section != current_section:
		current_section = new_section
		on_section_changed(current_section)

func get_section_from_y(y: float) -> int:
	if y >= 3240:
		return 1
	elif y >= 2160:
		return 2
	elif y >= 1080:
		return 3
	else:
		return 4

# ---------------------------------------------------------------

func on_section_changed(section: int):
	print("Jogador entrou na Seção ", section)

	if boss and current_phase == PhaseState.PHASE_1_ESCAPE:
		match section:
			2:
				boss.ray_cooldown = 6.0
				boss.dash_cooldown = 8.0
			3:
				boss.ray_cooldown = 4.0
				boss.dash_cooldown = 6.0
			4:
				boss.ray_cooldown = 2.0
				boss.dash_cooldown = 4.0

# ---------------------------------------------------------------

func update_boss_behavior():
	if not boss or current_phase != PhaseState.PHASE_1_ESCAPE:
		return

# ---------------------------------------------------------------

func _on_phase_transition_entered(body):
	if body == player and current_phase == PhaseState.PHASE_1_ESCAPE:
		start_phase_transition()

# turquoise_library.gd - Modificar start_phase_transition()
func start_phase_transition():
	print("Iniciando transição para Fase 2...")
	current_phase = PhaseState.TRANSITION
	
	# Verificar se a câmera ainda existe
	if camera and is_instance_valid(camera):
		var tween = create_tween()
		tween.tween_property(camera, "zoom", Vector2(1.2, 1.2), 1.0)
		tween.tween_callback(start_phase_2)
	else:
		# Fallback: transição imediata
		print("Câmera não encontrada, iniciando Fase 2 imediatamente")
		start_phase_2()

# Também modificar start_phase_2() para usar call_deferred onde necessário
func start_phase_2():
	print("FASE 2: Combate na Arena!")
	current_phase = PhaseState.PHASE_2_BOSS
	
	# Usar call_deferred para operações que podem interferir com física
	call_deferred("_setup_phase_2_arena")

func _setup_phase_2_arena():
	if boss and is_instance_valid(boss):
		boss.global_position = Vector2(600, 300)
		if boss.has_method("change_to_phase_2"):
			boss.change_to_phase_2()
	
	if camera and is_instance_valid(camera):
		camera.limit_top = -200
		camera.limit_bottom = int(arena_y_start + 800)

# ---------------------------------------------------------------

func _on_boss_phase_changed(new_phase):
	print("Boss mudou para fase: ", new_phase)

func _on_boss_defeated():
	print("Boss derrotado! Fragmento de Cor apareceu!")
	current_phase = PhaseState.PHASE_2_BOSS  # Corrigido: não volta para escape

	var fragment_scene = preload("res://scenes/items/turquoise_fragment.tscn")
	var fragment = fragment_scene.instantiate()
	fragment.global_position = Vector2(600, 400)
	add_child(fragment)

# ---------------------------------------------------------------

func _on_player_died():
	print("Jogador morreu! Respawnando no último checkpoint...")
	respawn_player()

func respawn_player():
	if not player:
		return

	var checkpoint_section = current_section
	if current_phase == PhaseState.PHASE_2_BOSS:
		checkpoint_section = 5

	var respawn_pos = checkpoints.get(checkpoint_section, Vector2(600, 100))
	player.global_position = respawn_pos
	player.reset_stats()

	reset_enemies_in_section(checkpoint_section)

# ---------------------------------------------------------------
# RESPAWN: agora usa cálculo correto de seção
# ---------------------------------------------------------------

func reset_enemies_in_section(section: int):
	for enemy in enemies_container.get_children():
		var enemy_section = get_section_from_y(enemy.global_position.y)
		if enemy_section == section:
			enemy.queue_free()

	await get_tree().create_timer(0.5).timeout

	var rat_scene = preload("res://scenes/enemies/rat.tscn")
	var frog_scene = preload("res://scenes/enemies/frog.tscn")

	if section in enemy_spawn_data:
		var data = enemy_spawn_data[section]

		for rat_data in data.get("rats", []):
			var rat = rat_scene.instantiate()
			rat.global_position = rat_data["position"]
			rat.patrol_distance = rat_data["patrol_range"]
			enemies_container.add_child(rat)

		for frog_data in data.get("frogs", []):
			var frog = frog_scene.instantiate()
			frog.global_position = frog_data["position"]
			frog.patrol_distance = frog_data["patrol_range"]
			enemies_container.add_child(frog)
