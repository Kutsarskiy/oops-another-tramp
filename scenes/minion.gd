extends CharacterBody2D

const ENEMY_LAYER_BIT: int = 3
const PLAYER_BODY_LAYER_BIT: int = 1
const WALL_COLLISION_LAYER_BIT: int = 0

@export var move_speed: float = 65.0
@export var fire_rate: float = 0.5
@export var start_shoot_delay: float = 1.5
@export var keep_distance: float = 420.0
@export var max_hp: int = 3

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D

var hp: int
var _shoot_cd: float = 0.0
var _player: Node2D = null
var BulletScene: PackedScene = preload("res://scenes/bullet.tscn")


func _ready() -> void:
	hp = max_hp
	add_to_group("enemy")

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1 << ENEMY_LAYER_BIT
	collision_mask = (1 << WALL_COLLISION_LAYER_BIT) | (1 << PLAYER_BODY_LAYER_BIT)

	_configure_hurtbox()
	_ensure_temp_texture()

	_player = get_tree().get_first_node_in_group("player") as Node2D
	_shoot_cd = start_shoot_delay


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized()

	if sprite != null and absf(direction.x) > 0.001:
		sprite.flip_h = direction.x < 0.0

	var move_direction := Vector2.ZERO

	if distance > keep_distance:
		move_direction = direction

	velocity = move_direction * move_speed
	move_and_slide()

	_shoot_cd = maxf(_shoot_cd - delta, 0.0)

	if _shoot_cd <= 0.0:
		_shoot_cd = 1.0 / maxf(fire_rate, 0.01)
		_shoot(direction)


func _shoot(direction: Vector2) -> void:
	var bullet := BulletScene.instantiate() as Area2D

	if bullet == null:
		return

	if bullet.has_method("setup_bullet"):
		bullet.call("setup_bullet", true)

	bullet.set("team", &"enemy")
	bullet.set("direction", direction)
	bullet.global_position = global_position

	get_parent().add_child(bullet)


func take_damage(amount: int) -> void:
	hp -= amount

	if hp <= 0:
		queue_free()


func _configure_hurtbox() -> void:
	if hurtbox == null:
		return

	hurtbox.add_to_group("enemy")
	hurtbox.add_to_group("enemy_hurtbox")
	hurtbox.set_meta("damage_owner", self)
	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)
	hurtbox.collision_layer = 1 << ENEMY_LAYER_BIT
	hurtbox.collision_mask = 0


func _ensure_temp_texture() -> void:
	if sprite == null:
		return

	if sprite.texture != null:
		return

	var image := Image.create(72, 88, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var center := Vector2(36.0, 44.0)
	var body_radius := Vector2(25.0, 34.0)

	for y in range(88):
		for x in range(72):
			var offset := Vector2(float(x), float(y)) - center
			var body_value := pow(offset.x / body_radius.x, 2.0) + pow(offset.y / body_radius.y, 2.0)

			if body_value <= 1.0:
				image.set_pixel(x, y, Color(0.95, 0.32, 0.34, 1.0))

	image.fill_rect(Rect2i(18, 20, 36, 12), Color(0.28, 0.08, 0.10, 1.0))
	image.fill_rect(Rect2i(24, 58, 24, 8), Color(0.28, 0.08, 0.10, 1.0))

	sprite.texture = ImageTexture.create_from_image(image)
