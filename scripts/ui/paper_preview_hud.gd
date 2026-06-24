extends Control

const BossDatabaseScript: Script = preload("res://scripts/data/boss_database.gd")

@export var boss_name_short_texture_path: String = "res://assets/ui/hud/paper/boss_name_short.png"
@export var boss_name_medium_texture_path: String = "res://assets/ui/hud/paper/boss_name_medium.png"
@export var boss_name_long_texture_path: String = "res://assets/ui/hud/paper/boss_name_long.png"
@export var boss_healthbar_texture_path: String = "res://assets/ui/hud/paper/boss_healthbar.png"
@export var player_healthbar_texture_path: String = "res://assets/ui/hud/paper/player_healthbar.png"
@export var player_name_texture_path: String = "res://assets/ui/hud/paper/player_name.png"
@export var player_current_weapon_texture_path: String = "res://assets/ui/hud/paper/player_current_weapon.png"
@export var heart_red_texture_path: String = "res://assets/ui/hud/paper/heart_red.png"
@export var heart_black_texture_path: String = "res://assets/ui/hud/paper/heart_black.png"
@export var negotiator_texture_path: String = "res://assets/ui/hud/paper/weapons/the_negotiator.png"

@export var top_margin: float = 8.0
@export var boss_name_target_width: float = 165.0
@export var boss_healthbar_target_width: float = 365.0
@export var boss_healthbar_overlap: float = 9.0
@export var bottom_margin: float = 8.0
@export var bottom_side_margin: float = 28.0
@export var bottom_item_target_width: float = 215.0
@export var player_name_target_width: float = 245.0
@export var heart_size: float = 32.0
@export var heart_gap: float = 5.0
@export var shadow_offset: Vector2 = Vector2(4.0, 5.0)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.25)
@export var boss_health_fill_color: Color = Color(0.95, 0.05, 0.03, 1.0)
@export var boss_health_fill_rect: Rect2 = Rect2(0.135, 0.29, 0.745, 0.39)
@export var refresh_interval: float = 0.08

var _boss_name_short: Texture2D = null
var _boss_name_medium: Texture2D = null
var _boss_name_long: Texture2D = null
var _heart_red_texture: Texture2D = null
var _heart_black_texture: Texture2D = null

var _font: SystemFont = null
var _boss: BaseBoss = null
var _weapon_controller: Node = null
var _refresh_timer: float = 0.0

var _boss_name_rect: TextureRect = null
var _boss_healthbar_rect: TextureRect = null
var _boss_health_fill: ColorRect = null
var _boss_name_label: Label = null
var _player_healthbar_rect: TextureRect = null
var _player_name_rect: TextureRect = null
var _player_weapon_rect: TextureRect = null
var _weapon_icon_rect: TextureRect = null
var _player_name_label: Label = null
var _ammo_label: Label = null
var _shadow_rects: Dictionary = {}
var _heart_rects: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Segoe UI Semibold", "Arial Bold", "Consolas", "Courier New"])
	_font.font_weight = 600

	_boss_name_short = _load_texture_or_null(boss_name_short_texture_path)
	_boss_name_medium = _load_texture_or_null(boss_name_medium_texture_path)
	_boss_name_long = _load_texture_or_null(boss_name_long_texture_path)
	_heart_red_texture = _load_texture_or_null(heart_red_texture_path)
	_heart_black_texture = _load_texture_or_null(heart_black_texture_path)

	_boss_name_rect = _create_texture_rect("BossName", _pick_boss_name_texture(), -1.4)
	_boss_healthbar_rect = _create_texture_rect("BossHealthbar", _load_texture_or_null(boss_healthbar_texture_path), 1.1)
	_boss_health_fill = _create_boss_health_fill()
	_boss_name_label = _create_label("BossNameText", 17, HORIZONTAL_ALIGNMENT_CENTER)

	_player_healthbar_rect = _create_texture_rect("PlayerHealthbar", _load_texture_or_null(player_healthbar_texture_path), -1.6)
	_player_name_rect = _create_texture_rect("PlayerName", _load_texture_or_null(player_name_texture_path), 1.2)
	_player_weapon_rect = _create_texture_rect("PlayerCurrentWeapon", _load_texture_or_null(player_current_weapon_texture_path), -1.1)
	_weapon_icon_rect = _create_plain_texture_rect("WeaponIcon", _load_texture_or_null(negotiator_texture_path))
	_player_name_label = _create_label("PlayerNameText", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_ammo_label = _create_label("AmmoText", 21, HORIZONTAL_ALIGNMENT_LEFT)

	_create_heart_rects()
	_find_weapon_controller()

	if BossManager != null:
		if not BossManager.boss_spawned.is_connected(_on_boss_spawned):
			BossManager.boss_spawned.connect(_on_boss_spawned)
		if not BossManager.boss_defeated.is_connected(_on_boss_defeated):
			BossManager.boss_defeated.connect(_on_boss_defeated)

	_set_top_visible(false)
	_player_name_label.text = "Donny the Tramp"
	_layout_hud()
	_update_hearts()
	_update_weapon_panel()


func _process(delta: float) -> void:
	_refresh_timer -= delta

	if _refresh_timer > 0.0:
		return

	_refresh_timer = refresh_interval

	if _weapon_controller == null or not is_instance_valid(_weapon_controller):
		_find_weapon_controller()

	_update_hearts()
	_update_weapon_panel()
	_update_boss_health()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_hud()


func _on_boss_spawned(boss: BaseBoss) -> void:
	_boss = boss
	_boss_name_rect.texture = _pick_boss_name_texture(boss.boss_name)
	_set_shadow_texture(_boss_name_rect, _boss_name_rect.texture)
	_boss_name_label.text = boss.boss_name

	if not boss.boss_started.is_connected(_on_boss_started):
		boss.boss_started.connect(_on_boss_started)
	if not boss.boss_damaged.is_connected(_on_boss_damaged):
		boss.boss_damaged.connect(_on_boss_damaged)
	if not boss.boss_defeated.is_connected(_on_boss_defeated):
		boss.boss_defeated.connect(_on_boss_defeated)

	_set_top_visible(boss.is_fight_active())
	_update_boss_health()
	_layout_hud()


func _on_boss_started() -> void:
	_set_top_visible(true)
	_update_boss_health()


func _on_boss_damaged(_current_hp: float) -> void:
	_update_boss_health()


func _on_boss_defeated(_defeated_boss = null) -> void:
	_set_top_visible(false)
	_boss = null


func _create_texture_rect(node_name: String, texture: Texture2D, rotation_degrees_value: float) -> TextureRect:
	var shadow := _create_plain_texture_rect("%sShadow" % node_name, texture)
	shadow.modulate = shadow_color
	shadow.rotation_degrees = rotation_degrees_value

	var rect := _create_plain_texture_rect(node_name, texture)
	rect.rotation_degrees = rotation_degrees_value
	_shadow_rects[rect] = shadow
	return rect


func _create_plain_texture_rect(node_name: String, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(rect)
	return rect


func _create_boss_health_fill() -> ColorRect:
	var fill := ColorRect.new()
	fill.name = "BossHealthFill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = boss_health_fill_color
	add_child(fill)
	return fill


func _create_label(node_name: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.08, 0.065, 0.045, 1.0))
	label.clip_text = false
	add_child(label)
	return label


func _create_heart_rects() -> void:
	for i in range(5):
		var rect := _create_plain_texture_rect("LifeHeart%d" % (i + 1), _heart_red_texture)
		_heart_rects.append(rect)


func _layout_hud() -> void:
	if _boss_name_rect == null:
		return

	var viewport_size := get_viewport_rect().size
	var usable_width := maxf(viewport_size.x - bottom_side_margin * 2.0, 320.0)
	var top_max_width := minf(usable_width * 0.46, boss_healthbar_target_width)

	_place_centered_top(_boss_name_rect, minf(boss_name_target_width, usable_width * 0.25), top_margin)
	_place_centered_top(
		_boss_healthbar_rect,
		top_max_width,
		top_margin + _boss_name_rect.size.y - boss_healthbar_overlap
	)
	_layout_boss_name_label()
	_layout_boss_health_fill()

	var bottom_y := viewport_size.y - bottom_margin
	var side_width := minf(bottom_item_target_width, usable_width * 0.20)
	var name_width := minf(player_name_target_width, usable_width * 0.23)

	_place_bottom_left(_player_healthbar_rect, side_width, bottom_side_margin, bottom_y)
	_place_bottom_center(_player_name_rect, name_width, bottom_y)
	_place_bottom_right(_player_weapon_rect, side_width, bottom_side_margin, bottom_y)
	_layout_hearts()
	_layout_player_name_label()
	_layout_weapon_panel()


func _place_centered_top(rect: TextureRect, target_width: float, y: float) -> void:
	var rect_size := _get_scaled_texture_size(rect.texture, target_width)
	_set_rect_layout(rect, Vector2((get_viewport_rect().size.x - rect_size.x) * 0.5, y), rect_size)


func _place_bottom_left(rect: TextureRect, target_width: float, x: float, bottom_y: float) -> void:
	var rect_size := _get_scaled_texture_size(rect.texture, target_width)
	_set_rect_layout(rect, Vector2(x, bottom_y - rect_size.y), rect_size)


func _place_bottom_center(rect: TextureRect, target_width: float, bottom_y: float) -> void:
	var rect_size := _get_scaled_texture_size(rect.texture, target_width)
	_set_rect_layout(rect, Vector2((get_viewport_rect().size.x - rect_size.x) * 0.5, bottom_y - rect_size.y), rect_size)


func _place_bottom_right(rect: TextureRect, target_width: float, x_margin: float, bottom_y: float) -> void:
	var rect_size := _get_scaled_texture_size(rect.texture, target_width)
	_set_rect_layout(rect, Vector2(get_viewport_rect().size.x - x_margin - rect_size.x, bottom_y - rect_size.y), rect_size)


func _set_rect_layout(rect: TextureRect, rect_position: Vector2, rect_size: Vector2) -> void:
	rect.position = rect_position
	rect.size = rect_size
	rect.pivot_offset = rect_size * 0.5

	var shadow: TextureRect = _shadow_rects.get(rect, null)

	if shadow == null:
		return

	shadow.position = rect_position + shadow_offset
	shadow.size = rect_size
	shadow.pivot_offset = rect_size * 0.5


func _set_shadow_texture(rect: TextureRect, texture: Texture2D) -> void:
	var shadow: TextureRect = _shadow_rects.get(rect, null)

	if shadow != null:
		shadow.texture = texture


func _layout_boss_name_label() -> void:
	var pad_x := _boss_name_rect.size.x * 0.16
	var pad_y := _boss_name_rect.size.y * 0.18
	_boss_name_label.position = _boss_name_rect.position + Vector2(pad_x, pad_y)
	_boss_name_label.size = _boss_name_rect.size - Vector2(pad_x * 2.0, pad_y * 2.0)
	_boss_name_label.rotation_degrees = _boss_name_rect.rotation_degrees
	_boss_name_label.pivot_offset = _boss_name_label.size * 0.5
	_fit_label_font_size(_boss_name_label, _boss_name_label.text, 17, 11)


func _layout_boss_health_fill() -> void:
	var fill_position := _boss_healthbar_rect.position + Vector2(
		_boss_healthbar_rect.size.x * boss_health_fill_rect.position.x,
		_boss_healthbar_rect.size.y * boss_health_fill_rect.position.y
	)
	var fill_size := Vector2(
		_boss_healthbar_rect.size.x * boss_health_fill_rect.size.x,
		_boss_healthbar_rect.size.y * boss_health_fill_rect.size.y
	)

	_boss_health_fill.position = fill_position
	_boss_health_fill.size = fill_size
	_boss_health_fill.rotation_degrees = _boss_healthbar_rect.rotation_degrees
	_boss_health_fill.pivot_offset = Vector2.ZERO
	_boss_health_fill.z_index = _boss_healthbar_rect.z_index + 1
	_boss_health_fill.show_behind_parent = false
	_update_boss_health()


func _layout_hearts() -> void:
	var count := maxf(float(_heart_rects.size()), 1.0)
	var available_width := _player_healthbar_rect.size.x * 0.74
	var available_height := _player_healthbar_rect.size.y * 0.58
	var size_from_width := (available_width - heart_gap * (count - 1.0)) / count
	var final_heart_size := minf(heart_size, minf(size_from_width, available_height))
	var total_width := final_heart_size * count + heart_gap * (count - 1.0)
	var start_position := _player_healthbar_rect.position + Vector2(
		(_player_healthbar_rect.size.x - total_width) * 0.5,
		(_player_healthbar_rect.size.y - final_heart_size) * 0.49
	)

	for i in range(_heart_rects.size()):
		var rect := _heart_rects[i]
		rect.position = start_position + Vector2((final_heart_size + heart_gap) * i, 0.0)
		rect.size = Vector2.ONE * final_heart_size
		rect.pivot_offset = rect.size * 0.5
		rect.rotation_degrees = -1.2 + float(i % 3) * 1.1


func _layout_player_name_label() -> void:
	var pad_x := _player_name_rect.size.x * 0.06
	var pad_y := _player_name_rect.size.y * 0.18
	_player_name_label.position = _player_name_rect.position + Vector2(pad_x, pad_y)
	_player_name_label.size = _player_name_rect.size - Vector2(pad_x * 2.0, pad_y * 2.0)
	_player_name_label.rotation_degrees = _player_name_rect.rotation_degrees
	_player_name_label.pivot_offset = _player_name_label.size * 0.5
	_fit_label_font_size(_player_name_label, _player_name_label.text, 18, 11)


func _layout_weapon_panel() -> void:
	var icon_size := minf(_player_weapon_rect.size.y * 0.52, _player_weapon_rect.size.x * 0.28)
	_weapon_icon_rect.size = Vector2.ONE * icon_size
	_weapon_icon_rect.position = _player_weapon_rect.position + Vector2(
		_player_weapon_rect.size.x * 0.14,
		(_player_weapon_rect.size.y - icon_size) * 0.50
	)
	_weapon_icon_rect.rotation_degrees = _player_weapon_rect.rotation_degrees
	_weapon_icon_rect.pivot_offset = _weapon_icon_rect.size * 0.5

	_ammo_label.position = _player_weapon_rect.position + Vector2(
		_player_weapon_rect.size.x * 0.41,
		_player_weapon_rect.size.y * 0.20
	)
	_ammo_label.size = Vector2(_player_weapon_rect.size.x * 0.52, _player_weapon_rect.size.y * 0.58)
	_ammo_label.rotation_degrees = _player_weapon_rect.rotation_degrees
	_ammo_label.pivot_offset = _ammo_label.size * 0.5
	_fit_label_font_size(_ammo_label, _ammo_label.text, 21, 12)


func _update_hearts() -> void:
	var active_lives := _get_player_life_count()

	for i in range(_heart_rects.size()):
		_heart_rects[i].texture = _heart_red_texture if i < active_lives else _heart_black_texture


func _update_weapon_panel() -> void:
	var ammo_text := "12 / ∞"
	var weapon_id := &""

	if _weapon_controller != null:
		if _weapon_controller.has_method("get_current_ammo_text"):
			ammo_text = str(_weapon_controller.call("get_current_ammo_text"))
		if _weapon_controller.has_method("get_current_weapon_id"):
			weapon_id = _weapon_controller.call("get_current_weapon_id")

	_weapon_icon_rect.visible = weapon_id == &"the_negotiator"
	_ammo_label.text = ammo_text
	_fit_label_font_size(_ammo_label, _ammo_label.text, 21, 12)


func _fit_label_font_size(label: Label, label_text: String, max_font_size: int, min_font_size: int) -> void:
	if label == null or _font == null or label_text.is_empty():
		return

	var font_size := max_font_size

	while font_size > min_font_size:
		var text_size := _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)

		if text_size.x <= label.size.x and text_size.y <= label.size.y:
			break

		font_size -= 1

	label.add_theme_font_size_override("font_size", font_size)


func _update_boss_health() -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.max_hp <= 0.0:
		_boss_health_fill.scale.x = 1.0
		return

	var health_ratio := clampf(_boss.current_hp / _boss.max_hp, 0.0, 1.0)
	_boss_health_fill.scale.x = health_ratio


func _set_top_visible(is_visible: bool) -> void:
	for node in [_boss_name_rect, _boss_healthbar_rect, _boss_health_fill, _boss_name_label]:
		if node != null:
			node.visible = is_visible

	for rect in [_boss_name_rect, _boss_healthbar_rect]:
		var shadow: TextureRect = _shadow_rects.get(rect, null)

		if shadow != null:
			shadow.visible = is_visible


func _find_weapon_controller() -> void:
	_weapon_controller = null

	var player := get_tree().get_first_node_in_group("player")

	if player == null:
		return

	_weapon_controller = player.get_node_or_null("WeaponController")


func _get_player_life_count() -> int:
	var player := get_tree().get_first_node_in_group("player")

	if player == null:
		return 5

	if player.has_method("get_current_life_count"):
		return clampi(int(player.call("get_current_life_count")), 0, 5)

	return 5


func _get_scaled_texture_size(texture: Texture2D, target_width: float) -> Vector2:
	if texture == null:
		return Vector2.ZERO

	var texture_size := texture.get_size()

	if texture_size.x <= 0.0:
		return Vector2.ZERO

	var scale := target_width / texture_size.x
	return texture_size * scale


func _pick_boss_name_texture(boss_name: String = "") -> Texture2D:
	if boss_name.is_empty():
		boss_name = _get_current_boss_name()

	var length := boss_name.length()

	if length <= 10:
		return _boss_name_short

	if length <= 15:
		return _boss_name_medium

	return _boss_name_long


func _get_current_boss_name() -> String:
	if RunManager == null or RunManager.current_boss_id.is_empty():
		return "Sleepy Joe"

	return BossDatabaseScript.get_boss_display_name(RunManager.current_boss_id)


func _load_texture_or_null(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if ResourceLoader.exists(path):
		var resource := load(path)

		if resource is Texture2D:
			return resource as Texture2D

	var image := Image.new()
	var error := image.load(path)

	if error != OK:
		push_warning("HUD texture failed to load: %s" % path)
		return null

	return ImageTexture.create_from_image(image)
