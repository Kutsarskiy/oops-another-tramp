extends Area2D
class_name WeaponPickup

@export_enum("the_final_offer", "the_negotiator", "the_second_amendment") var debug_weapon_id: String = "the_final_offer"
@export var create_weapon_on_ready: bool = false
@export var pickup_radius: float = 44.0
@export var draw_size: Vector2 = Vector2(46.0, 22.0)
@export var draw_color: Color = Color(1.0, 0.55, 0.2, 1.0)
@export var interact_action: StringName = &"interact"

var weapon_instance: WeaponInstance = null

var _player_in_range: Node = null
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	add_to_group("pickup")
	add_to_group("weapon_pickup")

	monitoring = true
	monitorable = true

	collision_layer = 0
	collision_mask = 1 << 1

	_ensure_collision_shape()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if weapon_instance == null and create_weapon_on_ready:
		weapon_instance = _create_weapon_instance_by_id(debug_weapon_id)

	_apply_visual_from_weapon()
	queue_redraw()


func _process(_delta: float) -> void:
	if _player_in_range == null:
		return

	if weapon_instance == null:
		return

	if not InputMap.has_action(interact_action):
		return

	if Input.is_action_just_pressed(interact_action):
		_try_pick_up()


func setup_weapon(new_weapon_instance: WeaponInstance) -> void:
	weapon_instance = new_weapon_instance
	_apply_visual_from_weapon()
	queue_redraw()


func has_player_in_range() -> bool:
	return _player_in_range != null


func get_pickup_hint_text() -> String:
	if weapon_instance == null:
		return ""

	if weapon_instance.data == null:
		return ""

	var weapon_controller := _get_player_weapon_controller()

	if weapon_controller != null and weapon_controller.has_method("get_pickup_hint_for_weapon"):
		return str(weapon_controller.call("get_pickup_hint_for_weapon", weapon_instance))

	var description: String = weapon_instance.data.description

	if description.is_empty():
		return "[E] Pick up %s" % weapon_instance.data.display_name

	return "[E] Pick up %s\n%s" % [
		weapon_instance.data.display_name,
		description
	]


func get_pickup_priority_position() -> Vector2:
	return global_position


func _try_pick_up() -> void:
	if _player_in_range == null:
		return

	if weapon_instance == null:
		return

	var weapon_controller := _get_player_weapon_controller()

	if weapon_controller == null:
		return

	if not weapon_controller.has_method("pickup_weapon_instance"):
		return

	var picked_up: bool = bool(weapon_controller.call(
		"pickup_weapon_instance",
		weapon_instance,
		global_position
	))

	if picked_up:
		print("Picked up:", weapon_instance.data.display_name)
		weapon_instance = null
		queue_free()


func _get_player_weapon_controller() -> Node:
	if _player_in_range == null:
		return null

	return _player_in_range.get_node_or_null("WeaponController")


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


func _apply_visual_from_weapon() -> void:
	if weapon_instance == null:
		return

	if weapon_instance.data == null:
		return

	name = "WeaponPickup_%s" % weapon_instance.data.id
	draw_color = weapon_instance.data.bullet_color


func _draw() -> void:
	var body_height: float = draw_size.y * 0.45
	var grip_width: float = draw_size.x * 0.22
	var grip_height: float = draw_size.y * 0.70

	var body_rect := Rect2(
		Vector2(-draw_size.x * 0.5, -draw_size.y * 0.5),
		Vector2(draw_size.x, body_height)
	)

	var grip_rect := Rect2(
		Vector2(-draw_size.x * 0.18, -draw_size.y * 0.08),
		Vector2(grip_width, grip_height)
	)

	draw_circle(Vector2.ZERO, pickup_radius, Color(1.0, 1.0, 1.0, 0.05))
	draw_rect(body_rect, draw_color)
	draw_rect(grip_rect, draw_color.darkened(0.35))


func _create_weapon_instance_by_id(weapon_id: String) -> WeaponInstance:
	var weapon_data_script: Script = load("res://scripts/weapons/weapon_data.gd")
	var weapon_data = null

	match weapon_id:
		"the_negotiator":
			weapon_data = weapon_data_script.call("create_the_negotiator")
		"the_final_offer":
			weapon_data = weapon_data_script.call("create_the_final_offer")
		"the_second_amendment":
			weapon_data = weapon_data_script.call("create_the_second_amendment")
		_:
			weapon_data = weapon_data_script.call("create_the_final_offer")

	return WeaponInstance.new(weapon_data)
