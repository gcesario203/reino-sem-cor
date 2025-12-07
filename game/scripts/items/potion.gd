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

# CORRIGIDO: Referência ao sprite com verificação de tipo
@onready var sprite = $AnimatedSprite2D
@onready var particles = $GPUParticles2D
@onready var collision_shape = $CollisionShape2D
@onready var respawn_timer = $RespawnTimer

func _ready():
				original_position = global_position
				
				# CORRIGIDO: Verificar se o sprite existe e é do tipo correto
				if sprite and sprite is AnimatedSprite2D:
								# Iniciar animação padrão se existir
								if sprite.sprite_frames and sprite.sprite_frames.has_animation("default"):
												sprite.play("default")
				
				setup_visual_by_type()
				
				if respawn_timer:
								respawn_timer.wait_time = respawn_time
								# Conectar sinal do timer de respawn
								if not respawn_timer.timeout.is_connected(_on_respawn_timer_timeout):
												respawn_timer.timeout.connect(_on_respawn_timer_timeout)
				
				body_entered.connect(_on_body_entered)
				
				# Configurar collision mask para detectar player (layer 2)
				collision_mask = 2

func _process(delta):
				if not is_collected:
								# Animação de flutuação
								time_elapsed += delta
								var float_offset = sin(time_elapsed * float_speed) * float_amplitude
								global_position.y = original_position.y + float_offset
								
								# Rotação suave
								rotation += delta * 0.5

func setup_visual_by_type():
				# CORRIGIDO: Verificação mais robusta do sprite
				if not sprite or not is_instance_valid(sprite):
								return
				
				match potion_type:
								PotionType.RED_MP:
												sprite.modulate = Color(1.0, 0.2, 0.2)  # Vermelho
												if particles and is_instance_valid(particles):
																particles.modulate = Color(1.0, 0.0, 0.0, 0.8)
								PotionType.GREEN_HP:
												sprite.modulate = Color(0.2, 1.0, 0.2)  # Verde
												if particles and is_instance_valid(particles):
																particles.modulate = Color(0.0, 1.0, 0.0, 0.8)
								PotionType.BLUE_STAMINA:
												sprite.modulate = Color(0.2, 0.5, 1.0)  # Azul
												if particles and is_instance_valid(particles):
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
				is_collected = true
				
				# Som de coleta
				if AudioManager:
								AudioManager.play_sfx("item_collect")
				
				# Aplica efeito ao jogador
				match potion_type:
								PotionType.RED_MP:
												player.restore_stat("mp", 30)
												show_feedback("+30 MP", Color(1.0, 0.2, 0.2))
								PotionType.GREEN_HP:
												player.restore_stat("hp", 40)
												show_feedback("+40 HP", Color(0.2, 1.0, 0.2))
								PotionType.BLUE_STAMINA:
												player.restore_stat("stamina", 50)
												show_feedback("+50 Stamina", Color(0.2, 0.5, 1.0))
				
				# CORRIGIDO: Esconde visualmente com verificações
				if sprite and is_instance_valid(sprite):
								sprite.visible = false
				if collision_shape and is_instance_valid(collision_shape):
								collision_shape.disabled = true
				if particles and is_instance_valid(particles):
								particles.emitting = false
				
				# Inicia respawn
				if respawn_timer and is_instance_valid(respawn_timer):
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
				
				# CORRIGIDO: Verificações de instância válida
				if sprite and is_instance_valid(sprite):
								sprite.visible = true
								# Efeito de spawn com AnimatedSprite2D
								sprite.scale = Vector2(0.1, 0.1)
								var tween = create_tween()
								tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				
				if collision_shape and is_instance_valid(collision_shape):
								collision_shape.disabled = false
				
				if particles and is_instance_valid(particles):
								particles.emitting = true
