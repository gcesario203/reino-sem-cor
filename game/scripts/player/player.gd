extends CharacterBody2D

# ===== CONSTANTES DE MOVIMENTO =====
const WALK_SPEED = 200.0
const RUN_SPEED = 350.0
const JUMP_VELOCITY = -600.0
const COYOTE_TIME = 0.15

# Aceleração e fricção para controles mais responsivos
const ACCELERATION = 1500.0  # Aceleração no chão
const FRICTION = 1200.0      # Desaceleração no chão
const AIR_ACCELERATION = 1000.0  # Controle no ar
const AIR_FRICTION = 600.0       # Desaceleração no ar

# ===== RECURSOS (HP, MP, STAMINA) =====
var max_hp = 100.0
var current_hp = 100.0

var max_mp = 100.0
var current_mp = 100.0
const MP_REGEN_RATE = 5.0  # Por segundo, fora de combate

var max_stamina = 100.0
var current_stamina = 100.0
const STAMINA_REGEN_IDLE = 30.0  # Parado
const STAMINA_REGEN_WALK = 15.0   # Andando
const STAMINA_REGEN_RUN = 0.0    # Correndo (não regenera)
const STAMINA_COST_RUN = 3.0    # Por segundo
const STAMINA_COST_JUMP = 3.0
const STAMINA_COST_ATTACK = 2.0
const STAMINA_COST_BLOCK = 2.0   # Por segundo

# ===== SISTEMA DE COMBATE =====
var attack_damage = 15.0
var is_attacking = false
var attack_cooldown = 0.5
var attack_timer = 0.0
var is_blocking = false
var block_damage_reduction = 0.5

# ===== SISTEMA DE MAGIAS =====
var magic_red_active = false
var magic_red_cooldown = 3.0
var magic_red_timer = 0.0
var magic_red_cost = 15.0
var magic_red_damage_multiplier = 1.5

var magic_green_cooldown = 5.0
var magic_green_timer = 0.0
var magic_green_cost = 20.0
var magic_green_heal_amount = 30.0

var magic_blue_active = false
var magic_blue_shield = 0.0
var magic_blue_max_shield = 50.0
var magic_blue_cooldown = 10.0
var magic_blue_timer = 0.0
var magic_blue_cost = 25.0
var magic_blue_duration = 8.0
var magic_blue_duration_timer = 0.0

# ===== SISTEMA DE PENALIDADES =====
var low_stamina_threshold = 20.0
var stamina_penalty_active = false

# ===== SISTEMA DE INVENCIBILIDADE =====
var is_invincible = false
var invincibility_duration = 1.2  # Aumentado de 0.5 para 1.2 segundos
var invincibility_timer = 0.0

# ===== SISTEMA DE KNOCKBACK =====
var knockback_force = 450.0  # Aumentado de 300.0 para 450.0
var is_taking_damage = false

# ===== COYOTE TIME =====
var coyote_timer = 0.0
var was_on_floor = false

# ===== REFERÊNCIAS =====
@onready var sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var attack_area = $AttackArea
@onready var attack_collision = $AttackArea/CollisionShape2D
var attack_area_base_position: Vector2  # Posição original da AttackArea

func _ready():
	# Inicializar recursos
	current_hp = max_hp
	current_mp = max_mp
	current_stamina = max_stamina

	# Salvar a posição original da AttackArea
	if attack_area:
		attack_area_base_position = attack_area.position

	# Adicionar ao grupo "player" para detecção de inimigos
	add_to_group("player")

	# Desabilitar área de ataque inicialmente
	if attack_area:
		attack_area.monitoring = false

func _physics_process(delta):
	# Aplicar gravidade
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Atualizar timers
	update_timers(delta)

	# Regenerar recursos
	regenerate_resources(delta)

	# Atualizar invencibilidade
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			sprite.modulate = Color.WHITE

	# Verificar penalidades de stamina
	check_stamina_penalties()

	# Processar input apenas se não estiver atacando
	if not is_attacking:
		handle_input(delta)

	# Atualizar coyote time
	update_coyote_time(delta)

	# Mover personagem
	move_and_slide()

	# Atualizar animação
	update_animation()

	# Debug: Reiniciar com R
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

func handle_input(delta):
	var direction = Input.get_axis("move_left", "move_right")

	# Sistema de bloqueio
	if Input.is_action_pressed("block") and current_stamina >= STAMINA_COST_BLOCK * delta:
		is_blocking = true
		current_stamina -= STAMINA_COST_BLOCK * delta
		# Parar completamente o movimento horizontal ao bloquear
		velocity.x = 0
		# Não retornar aqui para permitir outras ações como pular enquanto bloqueia
	else:
		is_blocking = false

	# Sistema de corrida
	var is_sprinting = Input.is_action_pressed("sprint") and current_stamina > 0 and direction != 0
	var target_speed = RUN_SPEED if is_sprinting else WALK_SPEED

	# Penalidade de velocidade por stamina baixa
	if stamina_penalty_active:
		target_speed *= 0.5

	# Consumir stamina ao correr
	if is_sprinting:
		current_stamina -= STAMINA_COST_RUN * delta
		current_stamina = max(0, current_stamina)

	# Movimento horizontal com aceleração APRIMORADA
	if is_on_floor():
		# No chão: aceleração e fricção mais responsivas
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * target_speed, ACCELERATION * delta)
			
			# Virar sprite e AttackArea quando a direção mudar
			var old_flip = sprite.flip_h
			sprite.flip_h = direction < 0
			
			# Se a direção realmente mudou, atualizar AttackArea
			if old_flip != sprite.flip_h and attack_area:
				update_attack_area_direction()
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	else:
		# No ar: controle aprimorado mas um pouco menos responsivo
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * target_speed, AIR_ACCELERATION * delta)
			
			# Virar sprite e AttackArea quando a direção mudar
			var old_flip = sprite.flip_h
			sprite.flip_h = direction < 0
			
			# Se a direção realmente mudou, atualizar AttackArea
			if old_flip != sprite.flip_h and attack_area:
				update_attack_area_direction()
		else:
			velocity.x = move_toward(velocity.x, 0, AIR_FRICTION * delta)

	# Sistema de pulo com coyote time
	if Input.is_action_just_pressed("jump") and can_jump():
		if current_stamina >= STAMINA_COST_JUMP:
			var jump_power = JUMP_VELOCITY
			# Penalidade de pulo por stamina baixa
			if stamina_penalty_active:
				jump_power *= 0.7
			velocity.y = jump_power
			current_stamina -= STAMINA_COST_JUMP
			coyote_timer = 0  # Resetar coyote time após pular
		else:
			# Mesmo que não tenha stamina suficiente, ainda assim consumir um pouco para evitar spam
			current_stamina = max(0, current_stamina - STAMINA_COST_JUMP * 0.5)

	# Sistema de ataque
	if Input.is_action_just_pressed("attack") and attack_timer <= 0:
		if current_stamina >= STAMINA_COST_ATTACK:
			perform_attack()
		else:
			# Mesmo que não tenha stamina suficiente, ainda assim consumir um pouco para evitar spam
			current_stamina = max(0, current_stamina - STAMINA_COST_ATTACK * 0.5)

	# Sistema de magias
	if Input.is_action_just_pressed("magic_red"):
		cast_magic_red()

	if Input.is_action_just_pressed("magic_green"):
		cast_magic_green()

	if Input.is_action_just_pressed("magic_blue"):
		cast_magic_blue()

func can_jump() -> bool:
	return is_on_floor() or (coyote_timer > 0 and not was_on_floor)

func update_coyote_time(delta):
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		was_on_floor = true
	else:
		if was_on_floor:
			coyote_timer -= delta
		was_on_floor = false

func perform_attack():
	is_attacking = true
	current_stamina -= STAMINA_COST_ATTACK
	sprite.play("attack")

	# Garantir que a AttackArea esteja na direção correta antes do ataque
	update_attack_area_direction()

	# Penalidade de cooldown por stamina baixa
	var cooldown = attack_cooldown
	if stamina_penalty_active:
		cooldown *= 1.5
	attack_timer = cooldown

	# Ativar hitbox de ataque
	if attack_area:
		attack_area.monitoring = true
		await get_tree().create_timer(0.1).timeout

		# Aplicar dano aos inimigos na área
		for body in attack_area.get_overlapping_bodies():
			if body.has_method("take_damage"):
				var damage = attack_damage
				var magic_type = ""

				# Aplicar multiplicador de magia vermelha
				if magic_red_active:
					damage *= magic_red_damage_multiplier
					magic_type = "red"
					magic_red_active = false

				# Passar tipo de magia e posição do atacante para inimigo
				body.take_damage(damage, magic_type, global_position)

		attack_area.monitoring = false

	# Aguardar fim da animação
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

# Função para atualizar a direção da AttackArea
func update_attack_area_direction():
	if attack_area:
		# Se o sprite estiver virado para a esquerda, inverter a posição X da AttackArea
		if sprite.flip_h:
			# Para esquerda: usar posição negativa (valor absoluto do X original, mas negativo)
			attack_area.position.x = -abs(attack_area_base_position.x)
		else:
			# Para direita: usar posição positiva
			attack_area.position.x = abs(attack_area_base_position.x)

func cast_magic_red():
	if current_mp >= magic_red_cost and magic_red_timer <= 0:
		current_mp -= magic_red_cost
		magic_red_timer = magic_red_cooldown
		magic_red_active = true
		print("🔴 Magia Vermelha (Golpe Rubi) ativada! Próximo ataque: +50% dano")

		# FEEDBACK VISUAL
		create_magic_flash(Color(1.0, 0.2, 0.2))  # Vermelho

func cast_magic_green():
	if current_mp >= magic_green_cost and magic_green_timer <= 0:
		current_mp -= magic_green_cost
		magic_green_timer = magic_green_cooldown
		current_hp = min(current_hp + magic_green_heal_amount, max_hp)
		print("🟢 Magia Verde (Cura Esmeralda) usada! HP restaurado: +30")

		# FEEDBACK VISUAL
		create_magic_flash(Color(0.2, 1.0, 0.2))  # Verde

func cast_magic_blue():
	if current_mp >= magic_blue_cost and magic_blue_timer <= 0:
		current_mp -= magic_blue_cost
		magic_blue_timer = magic_blue_cooldown
		magic_blue_active = true
		magic_blue_shield = magic_blue_max_shield
		magic_blue_duration_timer = magic_blue_duration
		print("🔵 Magia Azul (Escudo Turquesa) ativado! Escudo: 50 pontos por 8s")

		# FEEDBACK VISUAL
		create_magic_flash(Color(0.2, 0.5, 1.0))  # Azul

# Nova função para criar flash visual
func create_magic_flash(color: Color):
	sprite.modulate = color
	await get_tree().create_timer(0.15).timeout
	sprite.modulate = Color.WHITE

func take_damage(amount: float, attacker_position: Vector2 = Vector2.ZERO):
	# Ignorar dano se estiver invencível
	if is_invincible:
		return

	# Aplicar redução de dano do bloqueio
	if is_blocking:
		# Penalidade no bloqueio por stamina baixa
		var reduction = block_damage_reduction
		if stamina_penalty_active:
			reduction *= 0.7
		amount *= (1.0 - reduction)

	# Aplicar escudo mágico azul
	if magic_blue_active and magic_blue_shield > 0:
		var shield_damage = min(amount, magic_blue_shield)
		magic_blue_shield -= shield_damage
		amount -= shield_damage

		if magic_blue_shield <= 0:
			magic_blue_active = false
			print("🔵 Escudo Turquesa destruído!")

	# Aplicar dano ao HP
	current_hp -= amount
	current_hp = max(0, current_hp)

	# KNOCKBACK APRIMORADO
	if attacker_position != null and attacker_position != Vector2.ZERO:
		var knockback_direction = (global_position - attacker_position).normalized()
		var knockback_multiplier = 0.5

		# Knockback mais forte se atacante está acima (inimigo grudado)
		if attacker_position.y < global_position.y - 20:  # Atacante 20 pixels acima
			knockback_multiplier = 1.8  # 80% mais força
			# Empurrar para baixo e para os lados
			velocity.y = -500  # Impulso para cima adicional

		velocity = knockback_direction * knockback_force * knockback_multiplier
		is_taking_damage = true
	else:
		# Se não houver posição de atacante válida, aplicar knockback padrão para trás
		var facing_direction = -1 if sprite.flip_h else 1
		velocity.x = -facing_direction * knockback_force * 0.5
		is_taking_damage = true

	# Ativar invencibilidade temporária
	if amount > 0:
		is_invincible = true
		invincibility_timer = invincibility_duration
		# Feedback visual (piscar vermelho)
		_flash_red()

	# Reproduzir animação de dano (se não estiver atacando)
	if not is_attacking and amount > 0:
		sprite.play("hurt")

	# Aguardar fim do knockback
	if is_taking_damage:
		await get_tree().create_timer(0.5).timeout
		is_taking_damage = false

	# Verificar morte
	if current_hp <= 0:
		die()

func _flash_red():
	# Efeito visual de dano aprimorado (piscar vermelho mais intenso e mais longo)
	sprite.modulate = Color(2.0, 0.3, 0.3)  # Vermelho mais intenso
	await get_tree().create_timer(0.2).timeout

	# Piscar durante invulnerabilidade
	var blink_count = 6  # 6 piscadas durante 1.2s de invulnerabilidade
	for i in range(blink_count):
		sprite.modulate.a = 0.3  # Quase transparente
		await get_tree().create_timer(0.1).timeout
		sprite.modulate.a = 1.0  # Opaco
		await get_tree().create_timer(0.1).timeout

	sprite.modulate = Color.WHITE

func die():
	print("💀 Herói X morreu!")
	died.emit()  # Emite sinal de morte
	sprite.play("death")
	set_physics_process(false)
	await get_tree().create_timer(1.6).timeout
	get_tree().reload_current_scene()

func regenerate_resources(delta):
	# Regenerar MP (fora de combate - simplificado: sempre regenera lentamente)
	if current_mp < max_mp:
		current_mp += MP_REGEN_RATE * delta
		current_mp = min(current_mp, max_mp)

	# Regenerar Stamina
	var regen_rate = 0.0

	if is_blocking or is_attacking:
		# Não regenera durante bloqueio ou ataque
		regen_rate = 0.0
	elif velocity.x == 0 and is_on_floor():
		# Parado
		regen_rate = STAMINA_REGEN_IDLE
	elif Input.is_action_pressed("sprint") and velocity.x != 0:
		# Correndo (não regenera)
		regen_rate = STAMINA_REGEN_RUN
	else:
		# Andando ou parado no ar
		if is_on_floor():
			regen_rate = STAMINA_REGEN_WALK
		else:
			# Regeneração mais lenta no ar
			regen_rate = STAMINA_REGEN_WALK * 0.5

	if current_stamina < max_stamina:
		current_stamina += regen_rate * delta
		current_stamina = min(current_stamina, max_stamina)

	# Atualizar timer do escudo azul
	if magic_blue_active:
		magic_blue_duration_timer -= delta
		if magic_blue_duration_timer <= 0:
			magic_blue_active = false
			magic_blue_shield = 0
			print("🔵 Escudo Turquesa expirou!")

func check_stamina_penalties():
	stamina_penalty_active = current_stamina < low_stamina_threshold

func update_timers(delta):
	if attack_timer > 0:
		attack_timer -= delta

	if magic_red_timer > 0:
		magic_red_timer -= delta

	if magic_green_timer > 0:
		magic_green_timer -= delta

	if magic_blue_timer > 0:
		magic_blue_timer -= delta

func update_animation():
	if is_attacking:
		return  # Não sobrescrever animação de ataque

	if is_blocking:
		# Fallback se animação de bloqueio não existir
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("block"):
			sprite.play("block")
		else:
			sprite.play("idle")
		return

	if not is_on_floor():
		if velocity.y < 0:
			# Fallback para jump
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("jump"):
				sprite.play("jump")
			else:
				sprite.play("idle")
		else:
			# Fallback para fall
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("fall"):
				sprite.play("fall")
			else:
				sprite.play("idle")
	else:
		if velocity.x != 0:
			if Input.is_action_pressed("sprint") and current_stamina > 0:
				# Fallback para run
				if sprite.sprite_frames and sprite.sprite_frames.has_animation("run"):
					sprite.play("run")
				else:
					sprite.play("walk")
			else:
				sprite.play("walk")
		else:
			sprite.play("idle")

# ===== SISTEMA DE COLETA =====
var has_turquoise_fragment = false

# ===== SIGNALS =====
signal died()

func collect_turquoise_fragment():
	has_turquoise_fragment = true
	print("✓ Fragmento de Cor Azul Turquesa coletado!")
	print("  O escudo-godê foi ativado com a cor Turquesa!")

	# Pode adicionar habilidade especial ou buff
	# Por exemplo: aumenta eficácia da magia azul
	magic_blue_max_shield += 25.0

	print("  Bônus: Escudo Azul aumentado para %.0f!" % magic_blue_max_shield)

func restore_stat(stat_name: String, amount: float):
	match stat_name.to_lower():
		"hp":
			current_hp = min(current_hp + amount, max_hp)
			print("+ %.0f HP restaurado!" % amount)
		"mp":
			current_mp = min(current_mp + amount, max_mp)
			print("+ %.0f MP restaurado!" % amount)
		"stamina":
			current_stamina = min(current_stamina + amount, max_stamina)
			print("+ %.0f Stamina restaurada!" % amount)

func reset_stats():
	current_hp = max_hp
	current_mp = max_mp
	current_stamina = max_stamina
	is_invincible = false
	is_attacking = false
	is_blocking = false
	magic_red_active = false
	magic_blue_active = false
	print("✓ Stats do jogador resetados!")
