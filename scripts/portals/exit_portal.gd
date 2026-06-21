extends Area2D
class_name ExitPortal

signal exit_requested

@export var interact_action: StringName = &"interact"
@export var portal_radius: float = 58.0
@export var interact_radius: float = 72.0
@export var prompt_text: String = "[E] Continue to the next circle"
@export var portal_color: Color = Color(0.25, 0.9, 1.0, 0.9)
@export var glow_color: Color = Color(0.25, 0.9, 1.0, 0.22)

var _player_in_range: Node = null
var _pulse_time: float = 0.0
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	add_to_group("pickup")
	add_to_group("exit_portal")

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
		exit_requested.emit()


func has_player_in_range() -> bool:
	return _player_in_range != null


func get_pickup_hint_text() -> String:
	return prompt_text


func get_pickup_priority_position() -> Vector2:
	return global_position


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
	var pulse := (sin(_pulse_time * 4.0) + 1.0) * 0.5
	var glow_radius := portal_radius + lerpf(10.0, 24.0, pulse)
	var core_radius := portal_radius * lerpf(0.72, 0.9, pulse)

	draw_circle(Vector2.ZERO, glow_radius, glow_color)
	draw_circle(Vector2.ZERO, portal_radius, Color(portal_color.r, portal_color.g, portal_color.b, 0.18))
	draw_arc(Vector2.ZERO, portal_radius, 0.0, TAU, 96, portal_color, 5.0)
	draw_arc(Vector2.ZERO, portal_radius * 0.62, _pulse_time, _pulse_time + TAU * 0.72, 96, portal_color.lightened(0.35), 4.0)
	draw_circle(Vector2.ZERO, core_radius, Color(1.0, 1.0, 1.0, 0.08))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body


func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null
