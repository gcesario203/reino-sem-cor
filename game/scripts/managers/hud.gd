extends CanvasLayer

# --- Referências às barras ---
@onready var hp_bar = $MarginContainer/VBoxContainer/HPBar
@onready var mp_bar = $MarginContainer/VBoxContainer/MPBar
@onready var stamina_bar = $MarginContainer/VBoxContainer/StaminaBar

# --- Labels ---
@onready var hp_label = $MarginContainer/VBoxContainer/HPLabel
@onready var mp_label = $MarginContainer/VBoxContainer/MPLabel
@onready var stamina_label = $MarginContainer/VBoxContainer/StaminaLabel

# --- Indicadores de cooldown ---
@onready var magic_red_cooldown = $MagicContainer/MagicCooldowns/RedCooldown
@onready var magic_green_cooldown = $MagicContainer/MagicCooldowns/GreenCooldown
@onready var magic_blue_cooldown = $MagicContainer/MagicCooldowns/BlueCooldown

var player: Node = null

func _ready():
	# Cores das barras
	if hp_bar:
		hp_bar.modulate = Color(1.0, 0.2, 0.2) # Vermelho
	if mp_bar:
		mp_bar.modulate = Color(0.2, 0.5, 1.0) # Azul
	if stamina_bar:
		stamina_bar.modulate = Color(1.0, 0.8, 0.0) # Amarelo/Dourado
	
	# Esperar um frame antes de procurar o jogador
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

	if not player:
		print("⚠️ HUD: Jogador não encontrado!")


func _process(_delta):
	if player:
		update_hud()


func update_hud():
	# ----------------------- HP -----------------------
	if hp_bar:
		hp_bar.value = (player.current_hp / player.max_hp) * 100
	if hp_label:
		hp_label.text = "HP: %d/%d" % [player.current_hp, player.max_hp]

	# ----------------------- MP -----------------------
	if mp_bar:
		mp_bar.value = (player.current_mp / player.max_mp) * 100
	if mp_label:
		mp_label.text = "MP: %d/%d" % [player.current_mp, player.max_mp]

	# --------------------- Stamina ---------------------
	if stamina_bar:
		stamina_bar.value = (player.current_stamina / player.max_stamina) * 100

		if player.stamina_penalty_active:
			stamina_bar.modulate = Color(1.0, 0.5, 0.0) # Laranja (penalidade)
		else:
			stamina_bar.modulate = Color(1.0, 0.8, 0.0) # Amarelo normal

	if stamina_label:
		stamina_label.text = "Stamina: %d/%d" % [
			player.current_stamina,
			player.max_stamina
		]

	# ----------------- Cooldowns das magias -----------------

	# 🔴 Vermelha
	if magic_red_cooldown:
		if player.magic_red_timer > 0:
			magic_red_cooldown.text = "🔴 %.1f" % player.magic_red_timer
			magic_red_cooldown.modulate = Color(0.5, 0.5, 0.5)
		else:
			magic_red_cooldown.text = "🔴 [1]"
			magic_red_cooldown.modulate = Color(1, 1, 1)

	# 🟢 Verde
	if magic_green_cooldown:
		if player.magic_green_timer > 0:
			magic_green_cooldown.text = "🟢 %.1f" % player.magic_green_timer
			magic_green_cooldown.modulate = Color(0.5, 0.5, 0.5)
		else:
			magic_green_cooldown.text = "🟢 [2]"
			magic_green_cooldown.modulate = Color(1, 1, 1)

	# 🔵 Azul
	if magic_blue_cooldown:
		if player.magic_blue_timer > 0:
			magic_blue_cooldown.text = "🔵 %.1f" % player.magic_blue_timer
			magic_blue_cooldown.modulate = Color(0.5, 0.5, 0.5)

		elif player.magic_blue_active:
			magic_blue_cooldown.text = "🔵 ATIVO (%.1f)" % player.magic_blue_duration_timer
			magic_blue_cooldown.modulate = Color(0.5, 0.8, 1)

		else:
			magic_blue_cooldown.text = "🔵 [3]"
			magic_blue_cooldown.modulate = Color(1, 1, 1)
