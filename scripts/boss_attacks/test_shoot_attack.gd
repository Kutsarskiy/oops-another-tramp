extends BossAttack
class_name TestShootAttack


var cooldown: float = 1.5
var timer: float = 0.0

var bullet_scene := preload("res://scenes/bullet.tscn")


func update(delta: float) -> void:

	timer -= delta

	if timer > 0.0:
		return

	timer = cooldown

	shoot()


func shoot() -> void:

	if owner_boss == null:
		return

	var player := owner_boss.get_tree().get_first_node_in_group("player")

	if player == null:
		return

	var bullet = bullet_scene.instantiate()

	owner_boss.get_parent().add_child(bullet)

	bullet.global_position = owner_boss.global_position

	bullet.direction = (
		player.global_position -
		owner_boss.global_position
	).normalized()

	bullet.setup_bullet(true)

	if owner_boss.has_method("on_attack_shot"):
		owner_boss.call("on_attack_shot")
