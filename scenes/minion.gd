extends CharacterBody2D

@export var move_speed: float = 90.0
@export var fire_rate: float = 0.5          # 0.5 = один выстрел в две секунды
@export var start_shoot_delay: float = 1.5  # задержка перед первым выстрелом
@export var keep_distance: float = 420.0    # дистанция, на которой миньон останавливается
@export var max_hp: int = 3

@onready var muzzle: Marker2D = $Muzzle

var hp: int
var _shoot_cd: float = 0.0
var BulletScene = preload("res://scenes/bullet.tscn")
var _player: Node2D

func _ready() -> void:
	hp = max_hp
	add_to_group("enemy")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_shoot_cd = start_shoot_delay

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		return

	var to_player = _player.global_position - global_position
	var dist = to_player.length()
	var dir = to_player.normalized()

	# Движение: приближаемся, пока далеко
	var move_dir := Vector2.ZERO
	if dist > keep_distance:
		move_dir = dir

	velocity = move_dir * move_speed
	move_and_slide()

	# Стрельба
	_shoot_cd = max(_shoot_cd - delta, 0.0)
	if _shoot_cd <= 0.0:
		_shoot_cd = 1.0 / fire_rate
		_shoot(dir)

func _shoot(dir: Vector2) -> void:
	var b = BulletScene.instantiate()
	b.setup_bullet(true) # пуля врага (стены + игрок)

	b.team = &"enemy"
	b.color = Color(1, 0.3, 0.3)
	b.direction = dir

	# спавним чуть впереди, чтобы не пересекаться с коллизией
	b.global_position = muzzle.global_position + dir * 20.0
	get_parent().add_child(b)

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
