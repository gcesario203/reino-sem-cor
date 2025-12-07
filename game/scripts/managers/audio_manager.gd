extends Node

# ===============================================================
# AUDIO MANAGER - Gerenciador Global de Áudio
# Controla músicas e efeitos sonoros do jogo
# ===============================================================

# Players de áudio
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# Músicas pré-carregadas
var music_tracks: Dictionary = {}

# Efeitos sonoros pré-carregados
var sfx_sounds: Dictionary = {}

# Volume atual
var music_volume: float = 0.8
var sfx_volume: float = 1.0

# Música atual tocando
var current_music: String = ""

func _ready():
	# Criar players de áudio
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)
	
	# Pré-carregar músicas
	_preload_music()
	
	# Pré-carregar SFX
	_preload_sfx()
	
	print("AudioManager inicializado!")

func _preload_music():
	var music_files = {
		"menu": "res://assets/audio/music/menu_theme.ogg",
		"level": "res://assets/audio/music/level_theme.ogg",
		"boss": "res://assets/audio/music/boss_theme.ogg"
	}
	
	for key in music_files:
		var stream = load(music_files[key])
		if stream:
			music_tracks[key] = stream
			print("  Música carregada: ", key)

func _preload_sfx():
	var sfx_files = {
		"ui_confirm": "res://assets/audio/sfx/ui_confirm.wav",
		"ui_select": "res://assets/audio/sfx/ui_select.wav",
		"ui_cancel": "res://assets/audio/sfx/ui_cancel.wav",
		"player_jump": "res://assets/audio/sfx/player_jump.wav",
		"player_hit": "res://assets/audio/sfx/player_hit.wav",
		"boss_hit": "res://assets/audio/sfx/boss_hit.wav",
		"item_collect": "res://assets/audio/sfx/item_collect.wav",
		"boss_attack": "res://assets/audio/sfx/boss_attack.wav"
	}
	
	for key in sfx_files:
		var stream = load(sfx_files[key])
		if stream:
			sfx_sounds[key] = stream
			print("  SFX carregado: ", key)

# ---------------------------------------------------------------
# CONTROLE DE MÚSICA
# ---------------------------------------------------------------

func play_music(track_name: String, fade_duration: float = 1.0):
	if current_music == track_name and music_player.playing:
		return  # Já está tocando essa música
	
	if not track_name in music_tracks:
		print("Música não encontrada: ", track_name)
		return
	
	# Fade out da música atual
	if music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_duration)
		await tween.finished
	
	# Trocar e tocar nova música
	music_player.stream = music_tracks[track_name]
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()
	current_music = track_name
	
	print("Tocando música: ", track_name)

func stop_music(fade_duration: float = 1.0):
	if not music_player.playing:
		return
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -40.0, fade_duration)
	await tween.finished
	
	music_player.stop()
	current_music = ""

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume)

# ---------------------------------------------------------------
# CONTROLE DE SFX
# ---------------------------------------------------------------

func play_sfx(sound_name: String, volume_scale: float = 1.0):
	if not sound_name in sfx_sounds:
		print("SFX não encontrado: ", sound_name)
		return
	
	# Criar player temporário para permitir múltiplos sons simultâneos
	var temp_player = AudioStreamPlayer.new()
	temp_player.stream = sfx_sounds[sound_name]
	temp_player.volume_db = linear_to_db(sfx_volume * volume_scale)
	add_child(temp_player)
	temp_player.play()
	
	# Auto-destruir após tocar
	temp_player.finished.connect(func(): temp_player.queue_free())

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
