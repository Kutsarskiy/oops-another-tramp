extends CharacterBody2D
class_name Damageable

signal damaged(amount: int)
signal died

var max_hp: float = 100.0
var current_hp: float


func _ready() -> void:
	current_hp = max_hp


func take_damage(amount: int) -> void:

	current_hp -= amount

	damaged.emit(amount)

	if current_hp <= 0.0:
		current_hp = 0.0
		die()


func heal(amount: int) -> void:

	current_hp = min(
		current_hp + amount,
		max_hp
	)


func die() -> void:

	died.emit()

	queue_free()
