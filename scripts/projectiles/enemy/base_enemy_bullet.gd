extends "res://scenes/bullet.gd"
class_name BaseEnemyBullet


func _ready() -> void:
	super()

	if not is_in_group("enemy_bullet"):
		setup_bullet(true)
