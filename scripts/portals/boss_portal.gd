extends Area2D
class_name BossPortal

@export var target_circle_id: int = 1
@export var interact_action: StringName = &"interact"
@export var prompt_text: String = "[E] Enter boss room"
@export var portal_radius: float = 42.0
@export var interact_radius: float = 62.0
@export var portal_color: Color = Color(0.85, 0.25, 0.35, 0.9)
@export var glow_color: Color = Color(0.85, 0.25, 0.35, 0.20)

var _player_in_range: Node = null
var _pulse_time: float = 0.0
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	add_to_group("pickup")
	add_to_group("boss_portal")

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


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()

	if _player_in_range == null:
		return

	if not InputMap.has_action(interact_action):
		return

	if Input.is_action_just_pressed(interact_action):
		_enter_boss_room()


func has_player_in_range() -> bool:
	return _player_in_range != null


func get_pickup_hint_text() -> String:
	return prompt_text


func get_pickup_priority_position() -> Vector2:
	return global_position


func _enter_boss_room() -> void:
	RunManager.save_player_snapshot()

	if not RunManager.load_circle(target_circle_id):
		return

	get_tree().reload_current_scene()


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
	var pulse := (sin(_pulse_time * 3.5) + 1.0) * 0.5
	draw_circle(Vector2.ZERO, portal_radius + lerpf(8.0, 18.0, pulse), glow_color)
	draw_circle(Vector2.ZERO, portal_radius, Color(portal_color.r, portal_color.g, portal_color.b, 0.16))
	draw_arc(Vector2.ZERO, portal_radius, 0.0, TAU, 80, portal_color, 4.0)
	draw_arc(Vector2.ZERO, portal_radius * 0.58, -_pulse_time, -_pulse_time + TAU * 0.66, 80, portal_color.lightened(0.35), 3.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body


func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null
