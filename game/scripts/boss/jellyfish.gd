extends CharacterBody2D
class_name JellyfishBoss

# Estados do Boss
enum BossPhase { PHASE_1_CHASE, PHASE_2_ARENA }
enum AttackState { IDLE, RAY, DASH, DISCHARGE, SUMMONING }

# Referências de fase
var current_phase: BossPhase = BossPhase.PHASE_1_CHASE
var current_attack_state: AttackState = AttackState.IDLE

# Estatísticas
@export var max_health: float = 200.0
@export var phase_1_speed: float = 150.0
@export var phase_2_speed: float = 180.0
@export var dash_speed: float = 450.0

var current_health: float
var is_invincible: bool = true  # Fase 1 é invencível
var is_attacking: bool = false
var player_ref: Node2D = null

# Knockback e invencibilidade temporária
var knockback_force: float = 150.0
var is_damage_invulnerable: bool = false
var invulnerability_duration: float = 0.5
var is_stunned: bool = false

# Danos dos ataques
const RAY_DAMAGE = 20
const DASH_DAMAGE = 25
const DISCHARGE_DAMAGE = 30

# Cooldowns
var ray_cooldown: float = 2.0
var dash_cooldown: float = 4.0
var discharge_cooldown: float = 8.0
var summon_cooldown: float = 15.0

var ray_timer: float = 0.0
var dash_timer: float = 0.0
var discharge_timer: float = 0.0
var summon_timer: float = 0.0

# Movimento Fase 1
var float_offset: Vector2 = Vector2.ZERO
var float_time: float = 0.0
var vertical_chase_offset: float = 200.0  # INVERTIDO: Fica acima do jogador (persegue enquanto ele sobe)

# Movimento Fase 2
var arena_bounds: Rect2 = Rect2(0, 0, 1200, 600)
var horizontal_direction: int = 1

# Ataque Dash
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_telegraph_timer: float = 0.0
var dash_return_position: Vector2 = Vector2.ZERO

# Ataque Ray
var is_charging_ray: bool = false
var ray_telegraph_timer: float = 0.0
var ray_directions: Array = []

# Ataque Discharge
var is_charging_discharge: bool = false
var discharge_telegraph_timer: float = 0.0

# Invocação
var summoned_rats: Array = []
const MAX_SUMMONED_RATS = 4

# Cenas
var rat_scene: PackedScene
var fragment_scene: PackedScene

# Nodes
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar

# Sinais
signal phase_changed(new_phase: BossPhase)
signal boss_defeated()

func _ready():
								current_health = max_health
								setup_references()
								find_player()
								
								# Configura animações
								if sprite:
																sprite.play("float")
								
								# Health bar só aparece na Fase 2
								if health_bar:
																health_bar.visible = false
																health_bar.max_value = max_health
																health_bar.value = current_health
								
								# Carrega cenas de inimigos e objetos
								rat_scene = load("res://scenes/enemies/rat.tscn")
								fragment_scene = load("res://scenes/items/turquoise_fragment.tscn")
								
								# Fase 1: Boss atravessa plataformas
								# Layer 1 = plataformas, Layer 2 = jogador, Layer 3 = boss
								# Para atravessar plataformas: collision_mask = 2 (só detecta jogador)
								# E collision_layer = 4 (layer 3) para não ser afetado por plataformas
								collision_layer = 4  # Layer 3 (boss)
								collision_mask = 2   # Só colide com jogador (layer 2)
								
								print("Boss Água-viva inicializado - Fase 1 (Invencível, atravessa plataformas)")

func _physics_process(delta):
								# Atualiza timers
								update_timers(delta)
								
								# Se estiver em stun, apenas aplica o movimento
								if is_stunned:
																move_and_slide()
																return
								
								# Comportamento baseado na fase
								match current_phase:
																BossPhase.PHASE_1_CHASE:
																								phase_1_behavior(delta)
																BossPhase.PHASE_2_ARENA:
																								phase_2_behavior(delta)
								
								# Aplica movimento
								move_and_slide()
								
								# Atualiza animações
								update_animations()

func setup_references():
								if attack_area:
																attack_area.body_entered.connect(_on_attack_area_body_entered)

func find_player():
								var players = get_tree().get_nodes_in_group("player")
								if players.size() > 0:
																player_ref = players[0]
																print("Boss encontrou o jogador")

func update_timers(delta):
								ray_timer = max(0, ray_timer - delta)
								dash_timer = max(0, dash_timer - delta)
								discharge_timer = max(0, discharge_timer - delta)
								summon_timer = max(0, summon_timer - delta)
								
								# Timers de telegraph
								if dash_telegraph_timer > 0:
																dash_telegraph_timer -= delta
								if ray_telegraph_timer > 0:
																ray_telegraph_timer -= delta
								if discharge_telegraph_timer > 0:
																discharge_telegraph_timer -= delta

# ==================== FASE 1: FUGA VERTICAL ====================

func phase_1_behavior(delta):
								if not player_ref:
																return
								
								# Movimento de flutuação
								float_time += delta
								float_offset = Vector2(
																sin(float_time * 2.0) * 30.0,
																cos(float_time * 1.5) * 20.0
								)
								
								# Segue jogador verticalmente com offset (INVERTIDO: offset NEGATIVO para ficar ACIMA)
								var target_position = player_ref.global_position
								target_position.y -= vertical_chase_offset  # Boss fica ACIMA do jogador (Y menor)
								target_position += float_offset
								
								# Move suavemente em direção ao alvo
								# Prioriza movimento vertical (perseguição vertical mais agressiva)
								var direction = (target_position - global_position).normalized()
								velocity = direction * phase_1_speed
								
								# Sistema de ataques
								if not is_attacking:
																choose_phase_1_attack()

func choose_phase_1_attack():
								if not player_ref:
																return
								
								var distance_to_player = global_position.distance_to(player_ref.global_position)
								
								# Raio de energia (prioritário se cooldown disponível)
								if ray_timer <= 0 and distance_to_player < 500:
																start_ray_attack()
								
								# Rasante (se cooldown disponível)
								elif dash_timer <= 0 and distance_to_player < 600:
																start_dash_attack()

func start_ray_attack():
								is_attacking = true
								is_charging_ray = true
								ray_telegraph_timer = 0.5  # Telegraph de 0.5s
								
								# Calcula direção do raio
								if player_ref:
																ray_directions = [(player_ref.global_position - global_position).normalized()]
								
								sprite.play("spell-1")
								
								# Aguarda telegraph
								await get_tree().create_timer(ray_telegraph_timer).timeout
								
								# Dispara raio
								fire_energy_ray()
								
								# Aguarda animação
								await sprite.animation_finished
								
								is_attacking = false
								is_charging_ray = false
								ray_timer = ray_cooldown
								sprite.play("float")

func fire_energy_ray():
								for direction in ray_directions:
																create_energy_ray_projectile(global_position, direction)

func create_energy_ray_projectile(start_pos: Vector2, direction: Vector2):
								var ray = Area2D.new()
								ray.position = start_pos
								ray.z_index = 10
								
								# Sprite do raio
								var sprite_node = Sprite2D.new()
								sprite_node.texture = load("res://assets/sprites/boss/jellyfish/energy_ray.png")
								sprite_node.rotation = direction.angle()
								ray.add_child(sprite_node)
								
								# Colisão
								var collision_shape = CollisionShape2D.new()
								var shape = RectangleShape2D.new()
								shape.size = Vector2(128, 8)
								collision_shape.shape = shape
								collision_shape.rotation = direction.angle()
								ray.add_child(collision_shape)
								
								# Adiciona à cena
								get_parent().add_child(ray)
								
								# Movimento do raio
								var ray_speed = 400.0
								var lifetime = 2.0
								
								# Tween para movimento
								var tween = create_tween()
								tween.tween_property(ray, "position", start_pos + direction * ray_speed * lifetime, lifetime)
								tween.tween_callback(ray.queue_free)
								
								# Detecta colisão com jogador
								ray.body_entered.connect(func(body):
																if body == player_ref and body.has_method("take_damage"):
																								body.take_damage(RAY_DAMAGE, global_position)
																								ray.queue_free()
								)

func start_dash_attack():
								is_attacking = true
								is_dashing = false
								dash_telegraph_timer = 0.8  # Telegraph de 0.8s
								
								# Salva posição de retorno
								dash_return_position = global_position
								
								# Calcula direção do dash
								if player_ref:
																dash_direction = (player_ref.global_position - global_position).normalized()
								
								sprite.play("dash")
								
								# Telegraph visual (piscar)
								var blink_count = 4
								for i in range(blink_count):
																sprite.modulate.a = 0.5
																await get_tree().create_timer(dash_telegraph_timer / (blink_count * 2)).timeout
																sprite.modulate.a = 1.0
																await get_tree().create_timer(dash_telegraph_timer / (blink_count * 2)).timeout
								
								# Executa dash
								is_dashing = true
								var dash_duration = 0.6
								var dash_timer_local = 0.0
								
								while dash_timer_local < dash_duration:
																velocity = dash_direction * dash_speed
																dash_timer_local += get_physics_process_delta_time()
																await get_tree().process_frame
								
								is_dashing = false
								is_attacking = false
								dash_timer = dash_cooldown
								sprite.play("float")

# ==================== FASE 2: ARENA ====================

func change_to_phase_2():
								current_phase = BossPhase.PHASE_2_ARENA
								is_invincible = false
								
								# Fase 2: Boss colide com plataformas e jogador
								# collision_layer continua 4 (layer 3 - boss)
								# collision_mask = 3 (layers 1 e 2 - plataformas e jogador)
								collision_mask = 3  # Colide com plataformas (layer 1) e jogador (layer 2)
								
								# Mostra barra de HP
								if health_bar:
																health_bar.visible = true
																health_bar.value = current_health
								
								# Ajusta cooldowns (mais agressivo)
								ray_cooldown = 3.0
								dash_cooldown = 5.0
								
								# Ajusta arena bounds para nova posição (TOPO - Y baixo)
								arena_bounds = Rect2(50, 50, 1100, 550)  # Arena no topo
								
								print("Boss Água-viva - Fase 2 (Vulnerável, colide com plataformas)")
								phase_changed.emit(BossPhase.PHASE_2_ARENA)

func phase_2_behavior(delta):
								if not player_ref:
																return
								
								# Movimento horizontal na arena
								if not is_attacking and not is_dashing:
																velocity.x = phase_2_speed * horizontal_direction
																
																# Inverte direção nas bordas da arena
																if global_position.x <= arena_bounds.position.x:
																								horizontal_direction = 1
																elif global_position.x >= arena_bounds.position.x + arena_bounds.size.x:
																								horizontal_direction = -1
																
																# Mantém altura com flutuação
																float_time += delta
																var target_y = arena_bounds.position.y + 150 + sin(float_time * 1.5) * 50
																velocity.y = (target_y - global_position.y) * 2.0
								
								# Sistema de ataques
								if not is_attacking:
																choose_phase_2_attack()

func choose_phase_2_attack():
								if not player_ref:
																return
								
								var distance_to_player = global_position.distance_to(player_ref.global_position)
								var health_percentage = current_health / max_health
								
								# Ajusta cooldowns em HP baixo
								if health_percentage < 0.25:
																# < 25% HP: Cooldowns reduzidos em 30%
																var cooldown_mult = 0.7
																ray_cooldown = 3.0 * cooldown_mult
																dash_cooldown = 5.0 * cooldown_mult
																discharge_cooldown = 8.0 * cooldown_mult
								
								# Invocação de ratos (< 50% HP)
								if health_percentage < 0.5 and summon_timer <= 0:
																if summoned_rats.size() < MAX_SUMMONED_RATS:
																								start_summon_attack()
																								return
								
								# Descarga elétrica
								if discharge_timer <= 0 and distance_to_player < 250:
																start_discharge_attack()
																return
								
								# Raio de energia melhorado (3 raios em leque)
								if ray_timer <= 0:
																start_ray_attack_improved()
																return
								
								# Rasante melhorado (vai e volta)
								if dash_timer <= 0:
																start_dash_attack_improved()
																return

func start_ray_attack_improved():
								is_attacking = true
								is_charging_ray = true
								ray_telegraph_timer = 0.5
								
								# Calcula 3 direções em leque
								if player_ref:
																var center_dir = (player_ref.global_position - global_position).normalized()
																var angle_offset = deg_to_rad(30)
																
																ray_directions = [
																								center_dir,  # Centro
																								center_dir.rotated(angle_offset),  # +30°
																								center_dir.rotated(-angle_offset)  # -30°
																]
								
								sprite.play("spell-1")
								
								# Telegraph
								await get_tree().create_timer(ray_telegraph_timer).timeout
								
								# Dispara 3 raios
								fire_energy_ray()
								
								await sprite.animation_finished
								
								is_attacking = false
								is_charging_ray = false
								ray_timer = ray_cooldown
								sprite.play("float")

func start_dash_attack_improved():
								is_attacking = true
								is_dashing = false
								dash_telegraph_timer = 0.8
								
								dash_return_position = global_position
								
								if player_ref:
																dash_direction = (player_ref.global_position - global_position).normalized()
								
								sprite.play("dash")
								
								# Telegraph
								for i in range(4):
																sprite.modulate.a = 0.5
																await get_tree().create_timer(0.1).timeout
																sprite.modulate.a = 1.0
																await get_tree().create_timer(0.1).timeout
								
								# Dash de ida
								is_dashing = true
								var dash_distance = 400.0
								var tween = create_tween()
								tween.tween_property(self, "global_position", 
																global_position + dash_direction * dash_distance, 0.4)
								await tween.finished
								
								# Pausa
								await get_tree().create_timer(0.2).timeout
								
								# Dash de volta
								dash_direction *= -1
								var tween2 = create_tween()
								tween2.tween_property(self, "global_position", 
																global_position + dash_direction * dash_distance, 0.4)
								await tween2.finished
								
								is_dashing = false
								is_attacking = false
								dash_timer = dash_cooldown
								sprite.play("float")

func start_discharge_attack():
								is_attacking = true
								is_charging_discharge = true
								discharge_telegraph_timer = 1.0
								
								velocity = Vector2.ZERO
								sprite.play("spell-2")
								
								# Telegraph visual (círculo pulsante)
								var telegraph_sprite = Sprite2D.new()
								telegraph_sprite.texture = load("res://assets/sprites/boss/jellyfish/electric_discharge.png")
								telegraph_sprite.modulate.a = 0.5
								telegraph_sprite.scale = Vector2(0.5, 0.5)
								add_child(telegraph_sprite)
								
								# Anima telegraph
								var tween = create_tween()
								tween.set_parallel(true)
								tween.tween_property(telegraph_sprite, "scale", Vector2(1.0, 1.0), discharge_telegraph_timer)
								tween.tween_property(telegraph_sprite, "modulate:a", 1.0, discharge_telegraph_timer)
								
								await get_tree().create_timer(discharge_telegraph_timer).timeout
								
								# Remove telegraph
								telegraph_sprite.queue_free()
								
								# Cria área de dano
								create_discharge_area()
								
								await get_tree().create_timer(0.5).timeout
								
								is_attacking = false
								is_charging_discharge = false
								discharge_timer = discharge_cooldown
								sprite.play("float")

func create_discharge_area():
								var area = Area2D.new()
								area.position = global_position
								area.z_index = 5
								
								# Visual
								var sprite_node = Sprite2D.new()
								sprite_node.texture = load("res://assets/sprites/boss/jellyfish/electric_discharge.png")
								area.add_child(sprite_node)
								
								# Anima visual pulsando
								var tween = create_tween()
								tween.set_loops(3)
								tween.tween_property(sprite_node, "modulate:a", 0.8, 0.1)
								tween.tween_property(sprite_node, "modulate:a", 0.3, 0.1)
								
								# Colisão circular
								var collision_shape = CollisionShape2D.new()
								var shape = CircleShape2D.new()
								shape.radius = 200.0
								collision_shape.shape = shape
								area.add_child(collision_shape)
								
								get_parent().add_child(area)
								
								# Detecta jogador na área
								area.body_entered.connect(func(body):
																if body == player_ref and body.has_method("take_damage"):
																								body.take_damage(DISCHARGE_DAMAGE, global_position)
								)
								
								# Remove após duração
								await get_tree().create_timer(0.3).timeout
								area.queue_free()

func start_summon_attack():
								is_attacking = true
								current_attack_state = AttackState.SUMMONING
								
								velocity = Vector2.ZERO
								
								# Torna invencível durante invocação
								var was_invincible = is_invincible
								is_invincible = true
								
								sprite.play("spell-2")
								
								# Efeito visual de invocação
								sprite.modulate = Color(1.0, 0.5, 1.0)  # Tom roxo
								
								await get_tree().create_timer(1.0).timeout
								
								# Invoca 2 ratos
								for i in range(2):
																if summoned_rats.size() < MAX_SUMMONED_RATS:
																								summon_rat()
								
								# Restaura estado
								sprite.modulate = Color.WHITE
								is_invincible = was_invincible
								is_attacking = false
								summon_timer = summon_cooldown
								sprite.play("float")

func summon_rat():
								if not rat_scene:
																return
								
								var rat = rat_scene.instantiate()
								
								# Posiciona perto do boss
								var offset = Vector2(randf_range(-150, 150), 100)
								rat.global_position = global_position + offset
								
								get_parent().add_child(rat)
								summoned_rats.append(rat)
								
								# Remove da lista quando morrer
								rat.tree_exited.connect(func():
																summoned_rats.erase(rat)
								)

# ==================== COMBATE ====================

func take_damage(amount: float, magic_type: String = "", attacker_position: Vector2 = Vector2.ZERO):
								# Fase 1 é invencível
								if is_invincible:
																print("Boss está invencível!")
																return
								
								# Ignorar dano se estiver em invencibilidade temporária
								if is_damage_invulnerable:
																return
								
								# Aplica vulnerabilidades
								match magic_type:
																"blue":
																								amount *= 1.75  # +75% dano com magia azul
																"red":
																								amount *= 1.25  # +25% dano com magia vermelha
								
								current_health -= amount
								
								# Atualiza barra de HP
								if health_bar:
																health_bar.value = current_health
								
								# KNOCKBACK
								if attacker_position != Vector2.ZERO:
																var knockback_direction = (global_position - attacker_position).normalized()
																velocity = knockback_direction * knockback_force
																is_stunned = true
								
								# Animação de dano
								sprite.play("hurt")
								
								# INVENCIBILIDADE TEMPORÁRIA
								is_damage_invulnerable = true
								
								# Piscar durante invencibilidade
								for i in range(5):
																sprite.modulate.a = 0.5
																await get_tree().create_timer(0.1).timeout
																sprite.modulate.a = 1.0
																await get_tree().create_timer(0.1).timeout
								
								is_damage_invulnerable = false
								is_stunned = false
								
								sprite.play("float")
								
								print("Boss recebeu %.1f de dano! HP: %.1f/%.1f" % [amount, current_health, max_health])
								
								# Verifica morte
								if current_health <= 0:
																die()

func die():
								print("Boss Água-viva derrotado!")
								
								# Para todos os ataques
								is_attacking = false
								is_invincible = true
								velocity = Vector2.ZERO
								
								# Animação de morte
								sprite.play("death")
								await sprite.animation_finished
								
								# Dropa fragmento de cor
								drop_fragment()
								
								# Emite sinal
								boss_defeated.emit()
								
								# Remove boss
								queue_free()

func drop_fragment():
								if not fragment_scene:
																print("Erro: Cena do fragmento não carregada!")
																return
								
								# Instancia fragmento
								var fragment = fragment_scene.instantiate()
								fragment.global_position = global_position
								
								# Adiciona à cena
								get_parent().add_child(fragment)
								
								print("Fragmento de Cor Azul Turquesa dropado!")

# ==================== ANIMAÇÕES E VISUAIS ====================

func update_animations():
								if is_dashing:
																if not sprite.animation == "dash":
																								sprite.play("dash")
								elif is_attacking:
																# As animações são controladas pelos métodos de ataque
																pass
								else:
																if not sprite.animation == "float":
																								sprite.play("float")
								
								# Flip sprite baseado na direção
								if velocity.x != 0:
																sprite.flip_h = velocity.x < 0

func _on_attack_area_body_entered(body):
								if body == player_ref and is_dashing:
																if body.has_method("take_damage"):
																								body.take_damage(DASH_DAMAGE, global_position)
