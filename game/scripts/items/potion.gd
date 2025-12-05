extends Area2D

# Tipos de frasco
enum PotionType {
	RED_MP,      # Restaura 30 MP
	GREEN_HP,    # Restaura 40 HP
	BLUE_STAMINA # Restaura 50 Stamina
}

@export var potion_type: PotionType = PotionType.RED_MP
@export var respawn_time: float = 30.0
@export var float_amplitude: float = 10.0
@export var float_speed: float = 2.0

var is_collected: bool = false
var original_position: Vector2
var time_elapsed: float = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var particles = $GPUParticles2D
@onready var collision_shape = $CollisionShape2D
@onready var respawn_timer = $RespawnTimer

func _ready():
	original_position = global_position
	setup_visual_by_type()
	respawn_timer.wait_time = respawn_time
	body_entered.connect(_on_body_entered)
	
	# ===== DEBUG: VERIFICAR COLLISION LAYERS =====
	# DEBUG: print("\n🧪 ===== POÇÃO CRIADA =====")
	# DEBUG: print("📍 Posição: ", global_position)
	# DEBUG: print("🔷 Collision Layer: ", collision_layer, " (deve ser 8)")
	# DEBUG: print("🔶 Collision Mask: ", collision_mask, " (deve ser 2)")
	# DEBUG: print("🎨 Tipo: ", potion_type)
	# DEBUG: print("👁️ Sprite válido: ", sprite != null)
	# DEBUG: print("===========================\n")

func _process(delta):
	if not is_collected:
		# Animação de flutuação
		time_elapsed += delta
		var float_offset = sin(time_elapsed * float_speed) * float_amplitude
		global_position.y = original_position.y + float_offset
		
		# Rotação suave
		rotation += delta * 0.5

func setup_visual_by_type():
	if not sprite:
		return
	
	match potion_type:
		PotionType.RED_MP:
			sprite.modulate = Color(1.0, 0.2, 0.2)  # Vermelho
			if particles:
				particles.modulate = Color(1.0, 0.0, 0.0, 0.8)
		PotionType.GREEN_HP:
			sprite.modulate = Color(0.2, 1.0, 0.2)  # Verde
			if particles:
				particles.modulate = Color(0.0, 1.0, 0.0, 0.8)
		PotionType.BLUE_STAMINA:
			sprite.modulate = Color(0.2, 0.5, 1.0)  # Azul
			if particles:
				particles.modulate = Color(0.0, 0.5, 1.0, 0.8)

func _on_body_entered(body):
	# DEBUG: print("\n⚡ POÇÃO: Corpo entrou! Nome: ", body.name, " | Grupo: ", body.get_groups())
	
	if is_collected:
		print("❌ Poção já foi coletada, ignorando")
		return
	
	if body.has_method("restore_stat"):
		# DEBUG: print("✅ Corpo tem método restore_stat, coletando!")
		collect(body)
	else:
		print("❌ Corpo NÃO tem método restore_stat")

func collect(player):
	# DEBUG: print("\n🎉 COLETANDO POÇÃO!")
	is_collected = true
	
	# Aplica efeito ao jogador
	match potion_type:
		PotionType.RED_MP:
			# DEBUG: print("🔴 Tipo: RED_MP (+30 MP)")
			player.restore_stat("mp", 30)
			show_feedback("+30 MP", Color(1.0, 0.2, 0.2))
		PotionType.GREEN_HP:
			# DEBUG: print("🟢 Tipo: GREEN_HP (+40 HP)")
			player.restore_stat("hp", 40)
			show_feedback("+40 HP", Color(0.2, 1.0, 0.2))
		PotionType.BLUE_STAMINA:
			# DEBUG: print("🔵 Tipo: BLUE_STAMINA (+50 Stamina)")
			player.restore_stat("stamina", 50)
			show_feedback("+50 Stamina", Color(0.2, 0.5, 1.0))
	
	# Esconde visualmente
	# DEBUG: print("👻 Tornando poção invisível...")
	sprite.visible = false
	collision_shape.disabled = true
	if particles:
		particles.emitting = false
	
	# Inicia respawn
	# DEBUG: print("⏰ Iniciando timer de respawn (", respawn_time, "s)")
	respawn_timer.start()

func show_feedback(text: String, color: Color):
	# Cria label flutuante para feedback visual
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 20)
	label.position = Vector2(-30, -40)
	add_child(label)
	
	# Anima label para cima e depois remove
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func _on_respawn_timer_timeout():
	# Reaparece após o tempo de respawn
	is_collected = false
	sprite.visible = true
	collision_shape.disabled = false
	if particles:
		particles.emitting = true
	
	# Efeito de spawn
	var tween = create_tween()
	sprite.scale = Vector2(0.1, 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
