extends Label

@export var pickup_group: StringName = &"weapon_pickup"
@export var panel_size: Vector2 = Vector2(520.0, 48.0)
@export var bottom_margin: float = 42.0
@export var refresh_interval: float = 0.05

var _refresh_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	size = panel_size
	custom_minimum_size = panel_size

	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	add_theme_font_size_override("font_size", 24)
	add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)

	text = ""
	_update_position()


func _process(delta: float) -> void:
	_refresh_timer -= delta

	if _refresh_timer > 0.0:
		return

	_refresh_timer = refresh_interval

	_update_hint_text()
	_update_position()


func _update_hint_text() -> void:
	var pickup := _find_active_pickup()

	if pickup == null:
		text = ""
		visible = false
		return

	if not pickup.has_method("get_pickup_hint_text"):
		text = ""
		visible = false
		return

	var hint_text: String = str(pickup.call("get_pickup_hint_text"))

	if hint_text.is_empty():
		text = ""
		visible = false
		return

	text = hint_text
	visible = true


func _find_active_pickup() -> Node:
	var pickups: Array[Node] = get_tree().get_nodes_in_group(pickup_group)

	var best_pickup: Node = null
	var best_distance_squared: float = INF

	var player := get_tree().get_first_node_in_group("player") as Node2D

	for pickup in pickups:
		if pickup == null:
			continue

		if not is_instance_valid(pickup):
			continue

		if not pickup.has_method("has_player_in_range"):
			continue

		if not bool(pickup.call("has_player_in_range")):
			continue

		var distance_squared: float = 0.0

		if player != null and pickup is Node2D:
			distance_squared = player.global_position.distance_squared_to((pickup as Node2D).global_position)

		if best_pickup == null or distance_squared < best_distance_squared:
			best_pickup = pickup
			best_distance_squared = distance_squared

	return best_pickup


func _update_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	size = panel_size
	position = Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		viewport_size.y - panel_size.y - bottom_margin
	)
