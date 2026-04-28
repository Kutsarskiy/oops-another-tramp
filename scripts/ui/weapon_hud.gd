extends Label

@export var player_group: StringName = &"player"
@export var panel_size: Vector2 = Vector2(360.0, 110.0)
@export var screen_margin: Vector2 = Vector2(0.0, 0.0)
@export var refresh_interval: float = 0.05

var _weapon_controller: Node = null
var _refresh_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	size = panel_size
	custom_minimum_size = panel_size

	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP

	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)

	_find_weapon_controller()
	_update_text()
	_update_position()


func _process(delta: float) -> void:
	_refresh_timer -= delta

	if _refresh_timer > 0.0:
		return

	_refresh_timer = refresh_interval

	if _weapon_controller == null or not is_instance_valid(_weapon_controller):
		_find_weapon_controller()

	_update_text()
	_update_position()


func _find_weapon_controller() -> void:
	_weapon_controller = null

	var player := get_tree().get_first_node_in_group(player_group)

	if player == null:
		return

	var controller := player.get_node_or_null("WeaponController")

	if controller == null:
		return

	_weapon_controller = controller


func _update_text() -> void:
	if _weapon_controller == null:
		text = "Weapon: -\nAmmo: -"
		return

	var weapon_name := "-"
	var ammo_text := "-"
	var is_reloading := false

	if _weapon_controller.has_method("get_current_weapon_name"):
		weapon_name = str(_weapon_controller.call("get_current_weapon_name"))

	if _weapon_controller.has_method("get_current_ammo_text"):
		ammo_text = str(_weapon_controller.call("get_current_ammo_text"))

	if _weapon_controller.has_method("is_reloading"):
		is_reloading = bool(_weapon_controller.call("is_reloading"))

	text = "Weapon: %s\nAmmo: %s" % [weapon_name, ammo_text]

	if is_reloading:
		text += "\nReloading..."


func _update_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	size = panel_size
	position = Vector2(
		viewport_size.x - panel_size.x - screen_margin.x,
		viewport_size.y - panel_size.y - screen_margin.y
	)
