extends CharacterBody2D

@export var move_speed: float = 200.0
@export var fire_rate: float = 10.0 # выстрелов в секунду

@onready var muzzle: Marker2D = $Muzzle

var _shoot_cd: float = 0.0
var BulletScene = preload("res://scenes/bullet.tscn")

func _physics_process(delta: float) -> void:
	# --- Movement (работает и на стрелках, и на WASD если ты добавил в Input Map) ---
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * move_speed
	move_and_slide()

	# --- Shooting ---
	_shoot_cd = max(_shoot_cd - delta, 0.0)

	if Input.is_action_pressed("shoot") and _shoot_cd <= 0.0:
		_shoot_cd = 1.0 / fire_rate
		_shoot()

func _shoot() -> void:
	var b = BulletScene.instantiate()
	b.global_position = muzzle.global_position

	var v := get_global_mouse_position() - muzzle.global_position
	if v.length_squared() < 0.0001:
		v = Vector2.RIGHT

	b.direction = v.normalized()

	# добавляем пулю на уровень, а не внутрь Player
	get_parent().add_child(b)
