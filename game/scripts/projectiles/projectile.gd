extends Area2D

# Configurações do projétil
var speed: float = 550.0
var damage: float = 15.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 2.0
var magic_type: String = ""
var shooter_position: Vector2 = Vector2.ZERO

# Visual
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready():
		# Configurar o projétil
		body_entered.connect(_on_body_entered)
		
		# Timer de vida
		await get_tree().create_timer(lifetime).timeout
		queue_free()

func _physics_process(delta):
		# Mover o projétil
		position += direction * speed * delta

func setup(start_pos: Vector2, target_direction: Vector2, projectile_damage: float, magic_modifier: String = "", attacker_pos: Vector2 = Vector2.ZERO):
		global_position = start_pos
		direction = target_direction.normalized()
		damage = projectile_damage
		magic_type = magic_modifier
		shooter_position = attacker_pos
		
		# Rotacionar sprite na direção do movimento
		if sprite:
				rotation = direction.angle()

func _on_body_entered(body):
		# Se atingiu um inimigo
		if body.has_method("take_damage") and not body.is_in_group("player"):
				body.take_damage(damage, magic_type, shooter_position)
				queue_free()
		
		# Se atingiu uma parede/plataforma
		if body.is_in_group("walls") or body.collision_layer & 1:  # Layer 1 = mundo
				queue_free()
