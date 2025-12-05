extends CharacterBody2D

# Estados do Rato
enum State {PATROL, CHASE, ATTACK, HURT, DEAD}
var current_state = State.PATROL

# Estatísticas
@export var max_health: float = 30.0
@export var patrol_speed: float = 80.0
@export var chase_speed: float = 160.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 50.0
@export var detection_range: float = 300.0
@export var patrol_distance: float = 100.0

# Variáveis de controle
var current_health: float
var current_direction: int = 1
var player_ref: CharacterBody2D = null
var spawn_position: Vector2
var patrol_left_bound: float
var patrol_right_bound: float
var can_attack: bool = true
var is_hurt: bool = false
var is_dead: bool = false
var gravity: float = 980.0

# Knockback
var knockback_force: float = 200.0
var is_stunned: bool = false

# Nós
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer
@onready var hurt_timer: Timer = $HurtTimer
@onready var platform_ray_right: RayCast2D = $PlatformRayRight
@onready var platform_ray_left: RayCast2D = $PlatformRayLeft
@onready var health_bar: ProgressBar = $HealthBar

func _ready():
		current_health = max_health
		spawn_position = global_position
		patrol_left_bound = spawn_position.x - patrol_distance
		patrol_right_bound = spawn_position.x + patrol_distance
		
		# Configura barra de vida
		if health_bar:
				health_bar.max_value = max_health
				health_bar.value = current_health
				health_bar.show()
		
		# Conecta sinais
		if detection_area:
				detection_area.body_entered.connect(_on_detection_area_body_entered)
				detection_area.body_exited.connect(_on_detection_area_body_exited)
		
		if attack_timer:
				attack_timer.timeout.connect(_on_attack_timer_timeout)
		
		if hurt_timer:
				hurt_timer.timeout.connect(_on_hurt_timer_timeout)
		
		# Configura sprite
		if sprite:
				sprite.play("idle")
		
		# Procura o jogador
		_find_player()

func _physics_process(delta):
		if is_dead:
				return
		
		# Aplica gravidade
		if not is_on_floor():
				velocity.y += gravity * delta
		else:
				velocity.y = 0
		
		# Se estiver em stun, apenas aplica o movimento
		if is_stunned:
				move_and_slide()
				return
		
		# Atualiza comportamento baseado no estado
		match current_state:
				State.PATROL:
						_patrol_behavior(delta)
				State.CHASE:
						_chase_behavior(delta)
				State.ATTACK:
						_attack_behavior(delta)
				State.HURT:
						velocity.x = 0
		
		# Verifica bordas de plataforma
		_check_platform_edges()
		
		# Move o inimigo
		move_and_slide()
		
		# Atualiza animação
		_update_animation()

func _patrol_behavior(delta):
		# Movimento de patrulha
		velocity.x = patrol_speed * current_direction
		
		# Verifica limites de patrulha
		if global_position.x <= patrol_left_bound and current_direction == -1:
				current_direction = 1
		elif global_position.x >= patrol_right_bound and current_direction == 1:
				current_direction = -1
		
		# Verifica se detectou jogador
		if player_ref and _is_player_in_detection_range():
				_change_state(State.CHASE)

func _chase_behavior(delta):
		if not player_ref:
				_change_state(State.PATROL)
				return
		
		# Move em direção ao jogador
		var direction_to_player = sign(player_ref.global_position.x - global_position.x)
		velocity.x = chase_speed * direction_to_player
		current_direction = direction_to_player
		
		# Verifica se está no alcance de ataque
		var distance_to_player = global_position.distance_to(player_ref.global_position)
		if distance_to_player <= attack_range:
				_change_state(State.ATTACK)
		# Verifica se jogador saiu do alcance
		elif not _is_player_in_detection_range():
				_change_state(State.PATROL)

func _attack_behavior(delta):
		velocity.x = 0
		
		if not player_ref:
				_change_state(State.PATROL)
				return
		
		var distance_to_player = global_position.distance_to(player_ref.global_position)
		
		# Se jogador saiu do alcance de ataque
		if distance_to_player > attack_range:
				_change_state(State.CHASE)
				return
		
		# Realiza ataque se disponível
		if can_attack and player_ref.has_method("take_damage"):
				player_ref.take_damage(attack_damage, global_position)
				can_attack = false
				attack_timer.start(1.0)  # Cooldown de 1 segundo

func _check_platform_edges():
		# Verifica se há chão à frente para evitar cair
		var will_fall = false
		
		if current_direction > 0 and platform_ray_right:
				will_fall = not platform_ray_right.is_colliding()
		elif current_direction < 0 and platform_ray_left:
				will_fall = not platform_ray_left.is_colliding()
		
		# Inverte direção se estiver na borda
		if will_fall and current_state == State.PATROL:
				current_direction *= -1

func _is_player_in_detection_range() -> bool:
		if not player_ref:
				return false
		
		var distance = global_position.distance_to(player_ref.global_position)
		return distance <= detection_range

func _find_player():
		# Procura o jogador na cena
		var root = get_tree().root
		player_ref = root.find_child("Player", true, false)

func take_damage(amount: float, magic_type: String = "", attacker_position: Vector2 = Vector2.ZERO):
		if is_dead or is_hurt:
				return
		
		# Aplica vulnerabilidade à magia vermelha
		if magic_type == "red":
				amount *= 2.0  # Dano dobrado
		
		current_health -= amount
		current_health = clamp(current_health, 0, max_health)
		
		# Atualiza barra de vida
		if health_bar:
				health_bar.value = current_health
		
		# KNOCKBACK
		if attacker_position != Vector2.ZERO:
				var knockback_direction = (global_position - attacker_position).normalized()
				velocity = knockback_direction * knockback_force
				is_stunned = true
		
		# Feedback visual de dano
		_flash_red()
		
		# Fim do stun após tempo
		await get_tree().create_timer(0.3).timeout
		is_stunned = false
		
		if current_health <= 0:
				_die()
		else:
				_change_state(State.HURT)
				is_hurt = true
				hurt_timer.start(0.4)  # Tempo de stun ao receber dano

func _die():
		if is_dead:
				return
		
		is_dead = true
		_change_state(State.DEAD)
		
		# Desabilita colisão
		if collision_shape:
				collision_shape.disabled = true
		
		# Desabilita área de detecção
		if detection_area:
				detection_area.monitoring = false
		
		# Toca animação de morte
		if sprite:
				sprite.play("death")
				await sprite.animation_finished
		
		queue_free()

func _flash_red():
		# Efeito visual de dano
		if sprite:
				sprite.modulate = Color(1.5, 0.5, 0.5)
				await get_tree().create_timer(0.1).timeout
				sprite.modulate = Color.WHITE

func _change_state(new_state: State):
		if current_state == new_state:
				return
		
		current_state = new_state

func _update_animation():
		if not sprite:
				return
		
		match current_state:
				State.PATROL, State.CHASE:
						if abs(velocity.x) > 0:
								sprite.play("walk")
						else:
								sprite.play("idle")
						# Flipar sprite baseado na direção
						sprite.flip_h = current_direction < 0
				
				State.ATTACK:
						if sprite.animation != "attack":
								sprite.play("attack")
				
				State.HURT:
						if sprite.animation != "hurt":
								sprite.play("hurt")
				
				State.DEAD:
						if sprite.animation != "death":
								sprite.play("death")

# Sinais
func _on_detection_area_body_entered(body):
		if body.is_in_group("player"):
				player_ref = body

func _on_detection_area_body_exited(body):
		if body == player_ref and current_state == State.CHASE:
				# Verifica distância antes de sair do chase
				if not _is_player_in_detection_range():
						_change_state(State.PATROL)

func _on_attack_timer_timeout():
		can_attack = true

func _on_hurt_timer_timeout():
		is_hurt = false
		if current_state == State.HURT:
				_change_state(State.PATROL)
