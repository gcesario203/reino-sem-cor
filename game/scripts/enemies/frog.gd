extends CharacterBody2D

# Estados do Sapo
enum State {PATROL, PREPARE_JUMP, JUMPING, ATTACK, HURT, DEAD}
var current_state = State.PATROL

# Estatísticas
@export var max_health: float = 40.0
@export var patrol_speed: float = 100.0
@export var jump_speed: float = 300.0
@export var jump_height: float = 300.0
@export var jump_horizontal_range: float = 400.0
@export var attack_damage: float = 12.0
@export var detection_range: float = 400.0
@export var patrol_distance: float = 120.0
@export var jump_cooldown: float = 3.0

# Variáveis de controle
var current_health: float
var current_direction: int = 1
var player_ref: CharacterBody2D = null
var spawn_position: Vector2
var patrol_left_bound: float
var patrol_right_bound: float
var can_jump: bool = true
var is_hurt: bool = false
var is_dead: bool = false
var is_jumping: bool = false
var jump_target: Vector2
var jump_start_pos: Vector2
var jump_progress: float = 0.0
var gravity: float = 980.0
var prepare_time: float = 0.0

# Knockback
var knockback_force: float = 200.0
var is_stunned: bool = false

# Nós
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var jump_cooldown_timer: Timer = $JumpCooldownTimer
@onready var hurt_timer: Timer = $HurtTimer
@onready var platform_ray_right: RayCast2D = $PlatformRayRight
@onready var platform_ray_left: RayCast2D = $PlatformRayLeft
@onready var health_bar: ProgressBar = $HealthBar

func _ready():
	current_health = max_health
	spawn_position = global_position
	patrol_left_bound = spawn_position.x - patrol_distance
	patrol_right_bound = spawn_position.x + patrol_distance
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.show()
	
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if jump_cooldown_timer:
		jump_cooldown_timer.timeout.connect(_on_jump_cooldown_timeout)
	
	if hurt_timer:
		hurt_timer.timeout.connect(_on_hurt_timer_timeout)
	
	if sprite:
		sprite.play("idle")
	
	_find_player()

func _physics_process(delta):
	if is_dead:
		return
	
	if not is_jumping:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.y = 0
	
	if is_stunned:
		move_and_slide()
		return
	
	match current_state:
		State.PATROL:
			_patrol_behavior(delta)
		State.PREPARE_JUMP:
			_prepare_jump_behavior(delta)
		State.JUMPING:
			_jumping_behavior(delta)
		State.ATTACK:
			_attack_behavior(delta)
		State.HURT:
			velocity.x = 0
	
	if current_state == State.PATROL:
		_check_platform_edges()
	
	move_and_slide()
	_update_animation()

func _patrol_behavior(delta):
	velocity.x = patrol_speed * current_direction
	
	if global_position.x <= patrol_left_bound and current_direction == -1:
		current_direction = 1
	elif global_position.x >= patrol_right_bound and current_direction == 1:
		current_direction = -1
	
	if player_ref and can_jump and _is_player_in_detection_range():
		_change_state(State.PREPARE_JUMP)

func _prepare_jump_behavior(delta):
	velocity.x = 0
	prepare_time += delta
	
	if prepare_time >= 1.0:
		prepare_time = 0.0
		_execute_jump()

func _execute_jump():
	if not player_ref:
		_change_state(State.PATROL)
		return
	
	jump_start_pos = global_position
	jump_target = player_ref.global_position
	jump_progress = 0.0
	is_jumping = true
	can_jump = false
	
	if jump_cooldown_timer:
		jump_cooldown_timer.start(jump_cooldown)
	
	_change_state(State.JUMPING)

func _jumping_behavior(delta):
	if not is_jumping:
		return
	
	jump_progress += delta * 1.5
	
	if jump_progress >= 1.0:
		is_jumping = false
		jump_progress = 0.0
		
		if player_ref:
			var distance = global_position.distance_to(player_ref.global_position)
			if distance <= 80.0:
				_change_state(State.ATTACK)
			else:
				_change_state(State.PATROL)
		else:
			_change_state(State.PATROL)
		
		return
	
	var t = jump_progress
	
	var horizontal_pos = lerp(jump_start_pos.x, jump_target.x, t)
	
	var vertical_offset = -jump_height * sin(t * PI)
	var vertical_pos = lerp(jump_start_pos.y, jump_target.y, t) + vertical_offset
	
	var target_pos = Vector2(horizontal_pos, vertical_pos)
	velocity = (target_pos - global_position) / delta
	
	if velocity.x != 0:
		current_direction = sign(velocity.x)

func _attack_behavior(delta):
	velocity.x = 0
	
	if not player_ref:
		_change_state(State.PATROL)
		return
	
	if player_ref.has_method("take_damage"):
		player_ref.take_damage(attack_damage, global_position)
	
	if sprite and sprite.animation == "attack":
		await get_tree().create_timer(0.5).timeout
	
	_change_state(State.PATROL)

func _check_platform_edges():
	var will_fall = false
	
	if current_direction > 0 and platform_ray_right:
		will_fall = not platform_ray_right.is_colliding()
	elif current_direction < 0 and platform_ray_left:
		will_fall = not platform_ray_left.is_colliding()
	
	if will_fall:
		current_direction *= -1

func _is_player_in_detection_range() -> bool:
	if not player_ref:
		return false
	return global_position.distance_to(player_ref.global_position) <= detection_range

func _find_player():
	var root = get_tree().root
	player_ref = root.find_child("Player", true, false)

func take_damage(amount: float, magic_type: String = "", attacker_position: Vector2 = Vector2.ZERO):
	if is_dead or is_hurt:
		return
	
	if magic_type == "blue":
		amount *= 2.0
	
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	
	if health_bar:
		health_bar.value = current_health
	
	if attacker_position != Vector2.ZERO:
		var knockback_direction = (global_position - attacker_position).normalized()
		velocity = knockback_direction * knockback_force
		is_stunned = true
	
	_flash_red()
	
	await get_tree().create_timer(0.3).timeout
	is_stunned = false
	
	if current_health <= 0:
		_die()
	else:
		_change_state(State.HURT)
		is_hurt = true
		is_jumping = false
		hurt_timer.start(0.4)

func _die():
	if is_dead:
		return
	
	is_dead = true
	_change_state(State.DEAD)
	
	if collision_shape:
		collision_shape.disabled = true
	
	if detection_area:
		detection_area.monitoring = false
	
	if sprite:
		sprite.play("death")
		await get_tree().create_timer(0.5).timeout
	
	queue_free()

func _flash_red():
	if sprite:
		sprite.modulate = Color(1.5, 0.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

func _change_state(new_state: State):
	if current_state == new_state:
		return
	current_state = new_state
	prepare_time = 0.0

func _update_animation():
	if not sprite:
		return
	
	match current_state:
		State.PATROL:
			if abs(velocity.x) > 0:
				sprite.play("walk")
			else:
				sprite.play("idle")
			sprite.flip_h = current_direction < 0
		
		State.PREPARE_JUMP:
			if sprite.sprite_frames.has_animation("prepare_jump"):
				sprite.play("prepare_jump")
			else:
				sprite.play("idle")
			sprite.flip_h = current_direction < 0
		
		State.JUMPING:
			if velocity.y < 0:
				if sprite.sprite_frames.has_animation("jump"):
					sprite.play("jump")
				else:
					sprite.play("walk")
			else:
				if sprite.sprite_frames.has_animation("fall"):
					sprite.play("fall")
				else:
					sprite.play("walk")
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

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player_ref = body

func _on_detection_area_body_exited(body):
	if body == player_ref:
		pass

func _on_jump_cooldown_timeout():
	can_jump = true

func _on_hurt_timer_timeout():
	is_hurt = false
	if current_state == State.HURT:
		_change_state(State.PATROL)
