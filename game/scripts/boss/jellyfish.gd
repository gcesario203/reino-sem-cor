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
var is_invincible: bool = true
var is_attacking: bool = false
var player_ref: Node2D = null

# Knockback
var knockback_force: float = 150.0
var is_damage_invulnerable: bool = false
var invulnerability_duration: float = 0.5
var is_stunned: bool = false

# Danos
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
var vertical_chase_offset: float = 200.0

# Movimento Fase 2
var arena_bounds: Rect2 = Rect2(0, 0, 1200, 600)
var horizontal_direction: int = 1

# Dash
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_telegraph_timer: float = 0.0
var dash_return_position: Vector2 = Vector2.ZERO

# Ray
var is_charging_ray: bool = false
var ray_telegraph_timer: float = 0.0
var ray_directions: Array = []

# Discharge
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
	
	if sprite:
		sprite.play("float")
	
	if health_bar:
		health_bar.visible = false
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	rat_scene = load("res://scenes/enemies/rat.tscn")
	fragment_scene = load("res://scenes/items/turquoise_fragment.tscn")
	
	collision_layer = 4
	collision_mask = 2
	
	print("Boss Água-viva inicializado - Fase 1 (Invencível, atravessa plataformas)")

func _physics_process(delta):
	update_timers(delta)
	
	if is_stunned:
		move_and_slide()
		return
	
	match current_phase:
		BossPhase.PHASE_1_CHASE:
			phase_1_behavior(delta)
		BossPhase.PHASE_2_ARENA:
			phase_2_behavior(delta)
	
	move_and_slide()
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
	
	if dash_telegraph_timer > 0:
		dash_telegraph_timer -= delta
	if ray_telegraph_timer > 0:
		ray_telegraph_timer -= delta
	if discharge_telegraph_timer > 0:
		discharge_telegraph_timer -= delta

# ==================== FASE 1 ====================

func phase_1_behavior(delta):
	if not player_ref:
		return
	
	float_time += delta
	float_offset = Vector2(
		sin(float_time * 2.0) * 30.0,
		cos(float_time * 1.5) * 20.0
	)
	
	var target_position = player_ref.global_position
	target_position.y -= vertical_chase_offset
	target_position += float_offset
	
	var direction = (target_position - global_position).normalized()
	velocity = direction * phase_1_speed
	
	if not is_attacking:
		choose_phase_1_attack()

func choose_phase_1_attack():
	if not player_ref:
		return
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	
	if ray_timer <= 0 and distance_to_player < 500:
		start_ray_attack()
	elif dash_timer <= 0 and distance_to_player < 600:
		start_dash_attack()

func start_ray_attack():
	is_attacking = true
	is_charging_ray = true
	ray_telegraph_timer = 0.5
	
	if player_ref:
		ray_directions = [(player_ref.global_position - global_position).normalized()]
	
	sprite.play("spell-1")
	await get_tree().create_timer(ray_telegraph_timer).timeout
	
	fire_energy_ray()
	
	await get_tree().create_timer(0.18).timeout
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
	
	var sprite_node = Sprite2D.new()
	sprite_node.texture = load("res://assets/sprites/boss/jellyfish/energy_ray.png")
	sprite_node.rotation = direction.angle()
	ray.add_child(sprite_node)
	
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(128, 8)
	collision_shape.shape = shape
	collision_shape.rotation = direction.angle()
	ray.add_child(collision_shape)
	
	get_parent().add_child(ray)
	
	var ray_speed = 400.0
	var lifetime = 2.0
	
	var tween = create_tween()
	tween.tween_property(ray, "position", start_pos + direction * ray_speed * lifetime, lifetime)
	tween.tween_callback(ray.queue_free)
	
	ray.body_entered.connect(func(body):
		if body == player_ref and body.has_method("take_damage"):
			body.take_damage(RAY_DAMAGE, global_position)
			ray.queue_free()
	)

func start_dash_attack():
	is_attacking = true
	is_dashing = false
	dash_telegraph_timer = 0.8
	
	dash_return_position = global_position
	
	if player_ref:
		dash_direction = (player_ref.global_position - global_position).normalized()
	
	sprite.play("dash")
	
	var blink_count = 4
	for i in range(blink_count):
		sprite.modulate.a = 0.5
		await get_tree().create_timer(dash_telegraph_timer / (blink_count * 2)).timeout
		sprite.modulate.a = 1.0
		await get_tree().create_timer(dash_telegraph_timer / (blink_count * 2)).timeout
	
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

# ==================== FASE 2 ====================

func change_to_phase_2():
	current_phase = BossPhase.PHASE_2_ARENA
	is_invincible = false
	
	collision_mask = 3
	
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_health
	
	ray_cooldown = 3.0
	dash_cooldown = 5.0
	
	arena_bounds = Rect2(50, 50, 1100, 550)
	
	print("Boss Água-viva - Fase 2")
	phase_changed.emit(BossPhase.PHASE_2_ARENA)

func phase_2_behavior(delta):
	if not player_ref:
		return
	
	if not is_attacking and not is_dashing:
		velocity.x = phase_2_speed * horizontal_direction
		
		if global_position.x <= arena_bounds.position.x:
			horizontal_direction = 1
		elif global_position.x >= arena_bounds.position.x + arena_bounds.size.x:
			horizontal_direction = -1
		
		float_time += delta
		var target_y = arena_bounds.position.y + 150 + sin(float_time * 1.5) * 50
		velocity.y = (target_y - global_position.y) * 2.0
	
	if not is_attacking:
		choose_phase_2_attack()

func choose_phase_2_attack():
	if not player_ref:
		return
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	var health_percentage = current_health / max_health
	
	if health_percentage < 0.25:
		var cooldown_mult = 0.7
		ray_cooldown = 3.0 * cooldown_mult
		dash_cooldown = 5.0 * cooldown_mult
		discharge_cooldown = 8.0 * cooldown_mult
	
	if health_percentage < 0.5 and summon_timer <= 0:
		if summoned_rats.size() < MAX_SUMMONED_RATS:
			start_summon_attack()
			return
	
	if discharge_timer <= 0 and distance_to_player < 250:
		start_discharge_attack()
		return
	
	if ray_timer <= 0:
		start_ray_attack_improved()
		return
	
	if dash_timer <= 0:
		start_dash_attack_improved()
		return

func start_ray_attack_improved():
	is_attacking = true
	is_charging_ray = true
	ray_telegraph_timer = 0.5
	
	if player_ref:
		var center_dir = (player_ref.global_position - global_position).normalized()
		var angle_offset = deg_to_rad(30)
		
		ray_directions = [
			center_dir,
			center_dir.rotated(angle_offset),
			center_dir.rotated(-angle_offset)
		]
	
	sprite.play("spell-1")
	await get_tree().create_timer(ray_telegraph_timer).timeout
	
	fire_energy_ray()
	
	await get_tree().create_timer(0.18).timeout
	
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
	
	for i in range(4):
		sprite.modulate.a = 0.5
		await get_tree().create_timer(0.1).timeout
		sprite.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout
	
	is_dashing = true
	var dash_distance = 400.0
	var tween = create_tween()
	tween.tween_property(self, "global_position", global_position + dash_direction * dash_distance, 0.4)
	await tween.finished
	
	await get_tree().create_timer(0.2).timeout
	
	dash_direction *= -1
	var tween2 = create_tween()
	tween2.tween_property(self, "global_position", global_position + dash_direction * dash_distance, 0.4)
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
	
	var telegraph_sprite = Sprite2D.new()
	telegraph_sprite.texture = load("res://assets/sprites/boss/jellyfish/electric_discharge.png")
	telegraph_sprite.modulate.a = 0.5
	telegraph_sprite.scale = Vector2(0.5, 0.5)
	add_child(telegraph_sprite)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(telegraph_sprite, "scale", Vector2(1.0, 1.0), discharge_telegraph_timer)
	tween.tween_property(telegraph_sprite, "modulate:a", 1.0, discharge_telegraph_timer)
	
	await get_tree().create_timer(discharge_telegraph_timer).timeout
	
	telegraph_sprite.queue_free()
	
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
	
	var sprite_node = Sprite2D.new()
	sprite_node.texture = load("res://assets/sprites/boss/jellyfish/electric_discharge.png")
	area.add_child(sprite_node)
	
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(sprite_node, "modulate:a", 0.8, 0.1)
	tween.tween_property(sprite_node, "modulate:a", 0.3, 0.1)
	
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 200.0
	collision_shape.shape = shape
	area.add_child(collision_shape)
	
	get_parent().add_child(area)
	
	area.body_entered.connect(func(body):
		if body == player_ref and body.has_method("take_damage"):
			body.take_damage(DISCHARGE_DAMAGE, global_position)
	)
	
	await get_tree().create_timer(0.3).timeout
	area.queue_free()

func start_summon_attack():
	is_attacking = true
	current_attack_state = AttackState.SUMMONING
	
	velocity = Vector2.ZERO
	
	var was_invincible = is_invincible
	is_invincible = true
	
	sprite.play("spell-2")
	sprite.modulate = Color(1.0, 0.5, 1.0)
	
	await get_tree().create_timer(1.0).timeout
	
	for i in range(2):
		if summoned_rats.size() < MAX_SUMMONED_RATS:
			summon_rat()
	
	sprite.modulate = Color.WHITE
	is_invincible = was_invincible
	is_attacking = false
	summon_timer = summon_cooldown
	sprite.play("float")

func summon_rat():
	if not rat_scene:
		return
	
	var rat = rat_scene.instantiate()
	var offset = Vector2(randf_range(-150, 150), 100)
	rat.global_position = global_position + offset
	
	get_parent().add_child(rat)
	summoned_rats.append(rat)
	
	rat.tree_exited.connect(func():
		summoned_rats.erase(rat)
	)

# ==================== COMBATE ====================

func take_damage(amount: float, magic_type: String = "", attacker_position: Vector2 = Vector2.ZERO):
	if is_invincible:
		print("Boss está invencível!")
		return
	
	if is_damage_invulnerable:
		return
	
	match magic_type:
		"blue":
			amount *= 1.75
		"red":
			amount *= 1.25
	
	current_health -= amount
	
	if health_bar:
		health_bar.value = current_health
	
	if attacker_position != Vector2.ZERO:
		var knockback_direction = (global_position - attacker_position).normalized()
		velocity = knockback_direction * knockback_force
		is_stunned = true
	
	sprite.play("hurt")
	is_damage_invulnerable = true
	
	for i in range(5):
		sprite.modulate.a = 0.5
		await get_tree().create_timer(0.1).timeout
		sprite.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout
	
	is_damage_invulnerable = false
	is_stunned = false
	sprite.play("float")
	
	print("Boss recebeu %.1f de dano! HP: %.1f/%.1f" % [amount, current_health, max_health])
	
	if current_health <= 0:
		die()

func die():
	print("Boss Água-viva derrotado!")
	
	is_attacking = false
	is_invincible = true
	velocity = Vector2.ZERO
	
	sprite.play("death")
	await get_tree().create_timer(0.5).timeout
	
	drop_fragment()
	boss_defeated.emit()
	queue_free()

func drop_fragment():
	if not fragment_scene:
		print("Erro: Cena do fragmento não carregada!")
		return
	
	var fragment = fragment_scene.instantiate()
	fragment.global_position = global_position
	
	get_parent().add_child(fragment)
	
	print("Fragmento de Cor Azul Turquesa dropado!")

# ==================== ANIMAÇÕES ====================

func update_animations():
	if is_dashing:
		if sprite.animation != "dash":
			sprite.play("dash")
	elif is_attacking:
		pass
	else:
		if sprite.animation != "float":
			sprite.play("float")
	
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

func _on_attack_area_body_entered(body):
	if body == player_ref and is_dashing:
		if body.has_method("take_damage"):
			body.take_damage(DASH_DAMAGE, global_position)
