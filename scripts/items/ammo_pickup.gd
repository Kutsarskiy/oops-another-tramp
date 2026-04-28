extends Area2D
class_name AmmoPickup

@export_enum("universal", "sidearm", "shotgun", "rifle", "heavy") var ammo_type: String = "universal"
@export var pickup_radius: float = 44.0
@export var draw_size: Vector2 = Vector2(34.0, 26.0)
@export var refill_fraction_override: float = -1.0
@export var interact_action: StringName = &"interact"

var _player_in_range: Node = null
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	add_to_group("pickup")
	add_to_group("ammo_pickup")

	monitoring = true
	monitorable = true

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
		_try_pick_up()


func has_player_in_range() -> bool:
	return _player_in_range != null


func get_pickup_hint_text() -> String:
	return "[E] Pick up %s\n%s" % [
		_get_display_name(),
		_get_description()
	]


func get_pickup_priority_position() -> Vector2:
	return global_position


func _try_pick_up() -> void:
	if _player_in_range == null:
		return

	var weapon_controller := _player_in_range.get_node_or_null("WeaponController")

	if weapon_controller == null:
		return

	if not weapon_controller.has_method("pickup_ammo"):
		return

	var picked_up: bool = bool(weapon_controller.call(
		"pickup_ammo",
		ammo_type,
		_get_refill_fraction(),
		_get_display_name()
	))

	if picked_up:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = body


func _on_body_exited(body: Node) -> void:
	if body == _player_in_range:
		_player_in_range = null


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

	circle_shape.radius = pickup_radius


func _draw() -> void:
	var color: Color = _get_draw_color()

	var box_rect := Rect2(
		Vector2(-draw_size.x * 0.5, -draw_size.y * 0.5),
		draw_size
	)

	var stripe_rect := Rect2(
		Vector2(-draw_size.x * 0.5, -draw_size.y * 0.12),
		Vector2(draw_size.x, draw_size.y * 0.24)
	)

	draw_circle(Vector2.ZERO, pickup_radius, Color(1.0, 1.0, 1.0, 0.05))
	draw_rect(box_rect, color)
	draw_rect(stripe_rect, color.darkened(0.35))


func _get_refill_fraction() -> float:
	if refill_fraction_override > 0.0:
		return refill_fraction_override

	match ammo_type:
		"universal":
			return 0.10
		"sidearm":
			return 0.25
		"shotgun":
			return 0.25
		"rifle":
			return 0.25
		"heavy":
			return 0.25
		_:
			return 0.10


func _get_display_name() -> String:
	match ammo_type:
		"universal":
			return "Universal Ammo"
		"sidearm":
			return "Sidearm Ammo"
		"shotgun":
			return "Shotgun Ammo"
		"rifle":
			return "Rifle Ammo"
		"heavy":
			return "Heavy Ammo"
		_:
			return "Ammo"


func _get_description() -> String:
	match ammo_type:
		"universal":
			return "A little bit of everything. Somehow fits everything."
		"sidearm":
			return "Small arguments for small arms."
		"shotgun":
			return "For when one answer is not enough."
		"rifle":
			return "Keeps constitutional arguments going."
		"heavy":
			return "Too heavy for nuance."
		_:
			return "Extra ammunition."


func _get_draw_color() -> Color:
	match ammo_type:
		"universal":
			return Color(0.85, 0.85, 0.85)
		"sidearm":
			return Color(1.0, 0.9, 0.2)
		"shotgun":
			return Color(1.0, 0.55, 0.2)
		"rifle":
			return Color(0.85, 0.9, 1.0)
		"heavy":
			return Color(0.9, 0.25, 0.25)
		_:
			return Color(1.0, 1.0, 1.0)
