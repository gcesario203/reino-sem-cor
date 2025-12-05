extends Area2D
class_name TurquoiseFragment

# Sinais
signal fragment_collected(collector: Node2D)

# Configurações
@export var float_amplitude: float = 10.0
@export var float_speed: float = 2.0
@export var rotate_speed: float = 1.0

# Estado
var initial_position: Vector2
var time_passed: float = 0.0
var is_collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = $PointLight2D
@onready var particles: CPUParticles2D = $CPUParticles2D

func _ready():
	initial_position = position
	
	# Conecta sinal de coleta
	body_entered.connect(_on_body_entered)
	
	# Configura partículas se existirem
	if particles:
		particles.emitting = true
	
	print("Fragmento de Cor Azul Turquesa criado")

func _process(delta):
	if is_collected:
		return
	
	time_passed += delta
	
	# Animação de flutuação
	var float_offset = sin(time_passed * float_speed) * float_amplitude
	position.y = initial_position.y + float_offset
	
	# Rotação
	if sprite:
		sprite.rotation += rotate_speed * delta
	
	# Pulsação de luz
	if light:
		light.energy = 1.0 + sin(time_passed * 3.0) * 0.3

func _on_body_entered(body):
	"""Detecta coleta pelo jogador"""
	if is_collected:
		return
	
	if body.is_in_group("player"):
		collect(body)

func collect(collector: Node2D):
	"""Coleta o fragmento"""
	is_collected = true
	
	print("Fragmento de Cor Azul Turquesa coletado por ", collector.name)
	
	# Emite sinal
	fragment_collected.emit(collector)
	
	# Notifica jogador se tiver método
	if collector.has_method("collect_turquoise_fragment"):
		collector.collect_turquoise_fragment()
	
	# Animação de coleta
	play_collect_animation()

func play_collect_animation():
	"""Animação quando coletado"""
	# Para partículas
	if particles:
		particles.emitting = false
	
	# Cria tween para animação de coleta
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Escala aumenta
	tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.3)
	
	# Fade out
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	
	if light:
		tween.tween_property(light, "energy", 3.0, 0.15)
		tween.tween_property(light, "energy", 0.0, 0.15).set_delay(0.15)
	
	# Remove após animação
	await tween.finished
	queue_free()
