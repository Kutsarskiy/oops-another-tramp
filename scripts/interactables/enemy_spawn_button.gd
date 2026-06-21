extends Area2D
class_name EnemySpawnButton

@export var enemy_scene: PackedScene = preload("res://scenes/minion.tscn")
@export var interact_action: StringName = &"interact"
@export var prompt_text: String = "[E] Spawn test enemy"
@export var interact_radius: float = 58.0
@export var spawn_offset: Vector2 = Vector2(0.0, -150.0)
@export var button_radius: float = 28.0
@export var button_color: Color = Color(1.0, 0.75, 0.18, 0.95)

var _player_in_range: Node = null
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	add_to_group("pickup")
	add_to_group("enemy_spawn_button")

	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	collision_layer = 0
	collision_mask = 1 << 1

	_ensure_collision_shape()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	queue_redraw()


func _process(_delta: float) -> void:
	if _player_in_range == null:
		return

	if not InputMap.has_action(interact_action):
		return

	if Input.is_action_just_pressed(interact_action):
		_spawn_enemy()


func has_player_in_range() -> bool:
	return _player_in_range != null


func get_pickup_hint_text() -> String:
	return prompt_text


func get_pickup_priority_position() -> Vector2:
	return global_position


func _spawn_enemy() -> void:
	if enemy_scene == null:
		return

	var enemy := enemy_scene.instantiate() as Node2D

	if enemy == null:
		return

	get_parent().add_child(enemy)
	enemy.global_position = global_position + spawn_offset


func _ensure_collision_shape() -> void:
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D

	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)

	var circle_shape := _collision_shape.shape as CircleShape2D

	if circle_shape == null:
		circle_shape = CircleShape2D.new()
		_collision_shape.shape = circle_shape

	circle_shape.radius = interact_radius


func _draw() -> void:
	draw_circle(Vector2.ZERO, button_radius + 10.0, Color(button_color.r, button_color.g, button_color.b, 0.16))
	draw_circle(Vector2.ZERO, button_radius, button_color)
	draw_circle(Vector2(0.0, -button_radius * 0.25), button_radius * 0.45, button_color.lightened(0.4))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body


func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null
