extends Label

@export var player_group: StringName = &"player"
@export var panel_size: Vector2 = Vector2(360.0, 110.0)
@export var screen_margin: Vector2 = Vector2(0.0, 0.0)
@export var refresh_interval: float = 0.05
@export var icon_size: Vector2 = Vector2(64.0, 64.0)
@export var icon_offset: Vector2 = Vector2(10.0, 8.0)
@export var text_offset_with_icon: float = 84.0
@export var weapon_icon_texture_paths: Dictionary = {
	&"the_negotiator": "res://assets/ui/hud/paper/weapons/the_negotiator.png",
	&"the_final_offer": "res://assets/ui/hud/paper/weapons/the_final_offer.png",
	&"the_second_amendment": "res://assets/ui/hud/paper/weapons/the_second_amendment.png"
}

var _weapon_controller: Node = null
var _refresh_timer: float = 0.0
var _weapon_icon: TextureRect = null
var _weapon_icon_textures: Dictionary = {}


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

	_load_weapon_icon_textures()
	_configure_weapon_icon()
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


func _load_weapon_icon_textures() -> void:
	_weapon_icon_textures.clear()

	for weapon_id in weapon_icon_texture_paths.keys():
		var texture := _load_texture_or_null(str(weapon_icon_texture_paths[weapon_id]))

		if texture != null:
			_weapon_icon_textures[StringName(str(weapon_id))] = texture


func _configure_weapon_icon() -> void:
	_weapon_icon = TextureRect.new()
	_weapon_icon.name = "WeaponIcon"
	_weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_weapon_icon)


func _update_text() -> void:
	if _weapon_controller == null:
		text = "-\nAmmo: -"
		_update_weapon_icon(&"")
		return

	var weapon_name := "-"
	var weapon_id := &""
	var ammo_text := "-"
	var is_reloading := false

	if _weapon_controller.has_method("get_current_weapon_name"):
		weapon_name = str(_weapon_controller.call("get_current_weapon_name"))

	if _weapon_controller.has_method("get_current_weapon_id"):
		weapon_id = _weapon_controller.call("get_current_weapon_id")

	if _weapon_controller.has_method("get_current_ammo_text"):
		ammo_text = str(_weapon_controller.call("get_current_ammo_text"))

	if _weapon_controller.has_method("is_reloading"):
		is_reloading = bool(_weapon_controller.call("is_reloading"))

	text = "%s\nAmmo: %s" % [weapon_name, ammo_text]
	_update_weapon_icon(weapon_id)

	if is_reloading:
		text += "\nReloading..."


func _update_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	var panel_position := Vector2(
		viewport_size.x - panel_size.x - screen_margin.x,
		viewport_size.y - panel_size.y - screen_margin.y
	)
	position = panel_position + Vector2(text_offset_with_icon, 0.0)
	size = panel_size - Vector2(text_offset_with_icon, 0.0)

	if _weapon_icon != null:
		_weapon_icon.position = icon_offset - Vector2(text_offset_with_icon, 0.0)
		_weapon_icon.size = icon_size


func _update_weapon_icon(weapon_id: StringName) -> void:
	if _weapon_icon == null:
		return

	var texture: Texture2D = _weapon_icon_textures.get(weapon_id, null)
	_weapon_icon.texture = texture
	_weapon_icon.visible = texture != null


func _load_texture_or_null(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if ResourceLoader.exists(path):
		var resource := load(path)

		if resource is Texture2D:
			return resource as Texture2D

	return null
