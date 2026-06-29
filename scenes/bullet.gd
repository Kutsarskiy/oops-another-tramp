extends Area2D
class_name Bullet

@export var speed: float = 680.0
@export var lifetime: float = 1.45
@export var radius: float = 9.0
@export var color: Color = Color(1.0, 0.72, 0.18)
@export var texture_path: String = ""
@export var collision_radius_from_texture: bool = false
@export var split_on_impact: bool = false
@export var split_on_timeout: bool = false
@export var split_count: int = 0
@export var split_projectile_scene: PackedScene = null
@export var split_projectile_texture_path: String = ""
@export var split_projectile_speed: float = 360.0
@export var split_projectile_lifetime: float = 2.0
@export var split_projectile_bounces: int = 0
@export var bounces_remaining: int = 0
@export var evaporate_duration: float = 0.25
@export var evaporate_scale_multiplier: float = 1.5
@export var evaporate_jitter: float = 4.0
@export var curve_strength_degrees: float = 0.0
@export var curve_frequency: float = 1.0
@export var impact_shake_duration: float = 0.0
@export var impact_shake_strength: float = 0.0
@export var impact_knockback_force: float = 0.0

@export var damage: int = 1
@export var team: StringName = &"player" # "player" или "enemy"

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var _time_left: float
var _texture: Texture2D = null
var _texture_content_fit_scale: float = 1.0
var _is_evaporating: bool = false
var _evaporate_time_left: float = 0.0
var _evaporate_duration: float = 0.0
var _base_visual_scale: Vector2 = Vector2.ONE
var _has_ballistic_arc: bool = false
var _curve_elapsed: float = 0.0
var _straight_direction: Vector2 = Vector2.RIGHT
var _curve_start_position: Vector2 = Vector2.ZERO
var _curve_arc_height: float = 0.0
var _has_split: bool = false
var _impact_feedback_played: bool = false


func _ready() -> void:
	_ensure_unique_collision_shape()
	_time_left = lifetime
	_curve_start_position = global_position
	_sync_texture_sprite()
	_apply_collision_radius()

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_evaporating:
		_update_evaporation(delta)
		return

	if _has_ballistic_arc:
		_update_ballistic_arc(delta)
	else:
		global_position += direction * speed * delta

	if not split_on_timeout:
		return

	_time_left -= delta

	if _time_left <= 0.0:
		_play_impact_feedback()
		_split_projectile()
		queue_free()


func _draw() -> void:
	var draw_scale := 1.0

	if _is_evaporating:
		var progress := 1.0 - _evaporate_time_left / _evaporate_duration
		draw_scale = lerpf(evaporate_scale_multiplier, evaporate_scale_multiplier * 1.12, progress)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * draw_scale)

	if _texture != null and sprite == null:
		var texture_size := _texture.get_size()
		draw_texture(_texture, -texture_size * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	if sprite != null and sprite.visible:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	draw_circle(Vector2.ZERO, radius + 3.0, Color(color.r, color.g, color.b, 0.18))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(-radius * 0.28, -radius * 0.28), radius * 0.32, Color(1.0, 0.95, 0.62, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func configure_projectile(
	new_damage: int,
	new_speed: float,
	new_lifetime: float,
	new_radius: float,
	new_color: Color,
	new_texture_path: String = ""
) -> void:
	damage = new_damage
	speed = new_speed
	lifetime = new_lifetime
	_time_left = lifetime
	radius = new_radius
	color = new_color
	texture_path = new_texture_path
	_load_projectile_texture()
	_sync_texture_sprite()

	_apply_collision_radius()
	queue_redraw()


func setup_bullet(is_enemy: bool) -> void:
	if is_enemy:
		team = &"enemy"
		add_to_group("enemy_bullet")
		remove_from_group("player_bullet")

		# Слой 1 — стены.
		# Слой 5 — PlayerHurtbox.
		# Вражеские пули больше не бьют основной Player CollisionShape2D.
		collision_mask = (1 << 0) | (1 << 4)

		speed = 560.0
		radius = 10.0
		color = Color(1.0, 0.52, 0.16)
	else:
		team = &"player"
		add_to_group("player_bullet")
		remove_from_group("enemy_bullet")

		# Слой 1 — стены.
		# Слой 4 — враги.
		collision_mask = (1 << 0) | (1 << 3)

		color = Color(1.0, 0.78, 0.20)

	_apply_collision_radius()
	_sync_texture_sprite()
	queue_redraw()


func configure_split_projectile(
	new_split_texture_path: String,
	new_split_count: int,
	new_split_speed: float,
	new_split_lifetime: float,
	new_split_bounces: int,
	should_split_on_impact: bool = true,
	should_split_on_timeout: bool = true,
	new_split_projectile_scene: PackedScene = null
) -> void:
	split_projectile_texture_path = new_split_texture_path
	split_count = new_split_count
	split_projectile_speed = new_split_speed
	split_projectile_lifetime = new_split_lifetime
	split_projectile_bounces = new_split_bounces
	split_on_impact = should_split_on_impact
	split_on_timeout = should_split_on_timeout
	split_projectile_scene = new_split_projectile_scene


func configure_curve(
	new_curve_strength_degrees: float,
	new_curve_frequency: float = 1.0,
	new_curve_sign: float = 0.0
) -> void:
	curve_strength_degrees = new_curve_strength_degrees
	curve_frequency = new_curve_frequency
	_has_ballistic_arc = absf(curve_strength_degrees) > 0.001
	_curve_elapsed = 0.0
	_curve_start_position = global_position

	if not _has_ballistic_arc:
		return

	if direction.length_squared() > 0.001:
		_straight_direction = direction.normalized()

	var expected_travel_distance := speed * maxf(lifetime, 0.01)
	_curve_arc_height = expected_travel_distance * tan(deg_to_rad(absf(curve_strength_degrees))) * maxf(curve_frequency, 0.01)

	if absf(new_curve_sign) > 0.001:
		_curve_arc_height *= signf(new_curve_sign)


func _update_ballistic_arc(delta: float) -> void:
	if not _has_ballistic_arc:
		return

	if _straight_direction.length_squared() <= 0.001:
		_straight_direction = Vector2.RIGHT

	_curve_elapsed += delta
	var curve_duration := maxf(lifetime, 0.01)
	var curve_progress := clampf(_curve_elapsed / curve_duration, 0.0, 1.0)
	var straight_position := _curve_start_position + _straight_direction * speed * _curve_elapsed
	var arc_offset := Vector2.UP * _curve_arc_height * sin(curve_progress * PI)

	global_position = straight_position + arc_offset


func _apply_collision_radius() -> void:
	if collision_radius_from_texture and _texture != null:
		var texture_size := _texture.get_size()
		radius = maxf(texture_size.x, texture_size.y) * _texture_content_fit_scale * 0.5

	if collision_shape == null:
		return

	var circle_shape := collision_shape.shape as CircleShape2D

	if circle_shape == null:
		return

	circle_shape.radius = radius


func _ensure_unique_collision_shape() -> void:
	if collision_shape == null or collision_shape.shape == null:
		return

	collision_shape.shape = collision_shape.shape.duplicate()


func _load_projectile_texture() -> void:
	_texture = null
	_texture_content_fit_scale = 1.0

	if texture_path.is_empty():
		return

	if ResourceLoader.exists(texture_path):
		var resource := load(texture_path)

		if resource is Texture2D:
			_texture = resource as Texture2D
			_texture_content_fit_scale = _calculate_texture_content_fit_scale(_texture)
			return

	var image := Image.new()
	var error := image.load(texture_path)

	if error != OK:
		push_warning("Projectile texture failed to load: %s" % texture_path)
		return

	_texture = ImageTexture.create_from_image(image)
	_texture_content_fit_scale = _calculate_texture_content_fit_scale(_texture)


func _sync_texture_sprite() -> void:
	if sprite == null:
		return

	if _texture == null:
		sprite.visible = false
		sprite.scale = Vector2.ONE
		return

	sprite.visible = true
	sprite.texture = _texture
	_base_visual_scale = Vector2.ONE * _texture_content_fit_scale
	sprite.scale = _base_visual_scale


func evaporate() -> void:
	if _is_evaporating:
		return

	_is_evaporating = true
	_evaporate_duration = maxf(evaporate_duration, 0.01)
	_evaporate_time_left = _evaporate_duration
	speed = 0.0
	split_on_impact = false
	split_on_timeout = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	if sprite != null:
		_base_visual_scale = sprite.scale

	queue_redraw()


func _update_evaporation(delta: float) -> void:
	_evaporate_time_left = maxf(_evaporate_time_left - delta, 0.0)
	var progress := 1.0 - _evaporate_time_left / _evaporate_duration
	var alpha := 1.0 - progress
	var scale_value := lerpf(evaporate_scale_multiplier, evaporate_scale_multiplier * 1.12, progress)
	var jitter := Vector2(
		randf_range(-evaporate_jitter, evaporate_jitter),
		randf_range(-evaporate_jitter, evaporate_jitter)
	) * alpha

	if sprite != null:
		sprite.modulate = Color(0.88, 0.88, 0.88, alpha)
		sprite.scale = _base_visual_scale * scale_value
		sprite.position = jitter
	else:
		color = Color(0.88, 0.88, 0.88, alpha)
		queue_redraw()

	if _evaporate_time_left <= 0.0:
		queue_free()


func _calculate_texture_content_fit_scale(texture: Texture2D) -> float:
	var image := texture.get_image()

	if image == null:
		return 1.0

	var image_size := image.get_size()

	if image_size.x <= 0 or image_size.y <= 0:
		return 1.0

	var min_position := image_size
	var max_position := Vector2i(-1, -1)

	for y in range(image_size.y):
		for x in range(image_size.x):
			if image.get_pixel(x, y).a <= 0.01:
				continue

			min_position.x = mini(min_position.x, x)
			min_position.y = mini(min_position.y, y)
			max_position.x = maxi(max_position.x, x)
			max_position.y = maxi(max_position.y, y)

	if max_position.x < min_position.x or max_position.y < min_position.y:
		return 1.0

	var content_size := Vector2(
		float(max_position.x - min_position.x + 1),
		float(max_position.y - min_position.y + 1)
	)

	if content_size.x <= 0.0 or content_size.y <= 0.0:
		return 1.0

	var fit_scale := minf(
		float(image_size.x) / content_size.x,
		float(image_size.y) / content_size.y
	)

	return maxf(fit_scale, 1.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(team):
		return

	if body.has_method("take_damage"):
		if _should_play_damage_impact_feedback(body):
			_apply_damage_knockback(body)
			_play_impact_feedback()

		body.call("take_damage", damage)
		queue_free()
		return

	if split_on_impact:
		var surface_normal := _get_surface_normal(body)
		_play_impact_feedback()
		_split_projectile(surface_normal)
		queue_free()
		return

	if bounces_remaining > 0:
		bounces_remaining -= 1
		direction = direction.bounce(_get_surface_normal(body)).normalized()
		return

	_play_impact_feedback()
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(team):
		return

	var damage_target: Node = _get_damage_target_from_area(area)

	if damage_target != null:
		if damage_target.is_in_group(team):
			return

		if damage_target.has_method("take_damage"):
			if _should_play_damage_impact_feedback(damage_target):
				_apply_damage_knockback(damage_target)
				_play_impact_feedback()

			damage_target.call("take_damage", damage)

	queue_free()


func _get_damage_target_from_area(area: Area2D) -> Node:
	if area.has_method("take_damage"):
		return area

	if area.has_meta("damage_owner"):
		var damage_owner: Variant = area.get_meta("damage_owner")

		if damage_owner is Node:
			return damage_owner as Node

	var parent_node: Node = area.get_parent()

	if parent_node != null and parent_node.has_method("take_damage"):
		return parent_node

	return null


func _split_projectile(spawn_normal: Vector2 = Vector2.ZERO) -> void:
	if _has_split:
		return

	if split_count <= 0:
		return

	_has_split = true
	split_on_impact = false
	split_on_timeout = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	var parent_node := get_parent()

	if parent_node == null:
		return

	var bullet_scene := split_projectile_scene

	if bullet_scene == null:
		bullet_scene = load("res://scenes/bullet.tscn") as PackedScene

	if bullet_scene == null:
		return

	var base_angle := randf_range(0.0, TAU)
	var spawn_position := global_position

	if spawn_normal.length_squared() > 0.001:
		spawn_position += spawn_normal.normalized() * maxf(radius + 2.0, 4.0)

	for i in range(split_count):
		var bullet := bullet_scene.instantiate()

		if bullet == null:
			continue

		var projectile_radius: float = bullet.radius
		var projectile_color: Color = bullet.color
		parent_node.call_deferred("add_child", bullet)
		bullet.global_position = spawn_position
		bullet.setup_bullet(team == &"enemy")
		bullet.direction = Vector2.RIGHT.rotated(base_angle + TAU * float(i) / float(split_count))
		bullet.bounces_remaining = split_projectile_bounces
		bullet.configure_projectile(
			damage,
			split_projectile_speed,
			split_projectile_lifetime,
			projectile_radius,
			projectile_color,
			split_projectile_texture_path
		)


func _play_impact_feedback() -> void:
	if _impact_feedback_played:
		return

	if impact_shake_duration <= 0.0 or impact_shake_strength <= 0.0:
		return

	_impact_feedback_played = true
	var player := get_tree().get_first_node_in_group("player")

	if player != null and player.has_method("play_phase_transition_feedback"):
		player.call("play_phase_transition_feedback", impact_shake_duration, impact_shake_strength)


func _should_play_damage_impact_feedback(damage_target: Node) -> bool:
	if damage_target.has_method("is_invulnerable") and bool(damage_target.call("is_invulnerable")):
		return false

	if damage_target.has_method("is_debug_hurtbox_disabled") and bool(damage_target.call("is_debug_hurtbox_disabled")):
		return false

	return true


func _apply_damage_knockback(damage_target: Node) -> void:
	if impact_knockback_force <= 0.0:
		return

	if damage_target.has_method("apply_heavy_hit_knockback"):
		damage_target.call("apply_heavy_hit_knockback", global_position, impact_knockback_force)


func _get_surface_normal(body: Node) -> Vector2:
	if body is Node2D:
		var from_body := global_position - (body as Node2D).global_position

		if absf(from_body.x) > absf(from_body.y):
			return Vector2(signf(from_body.x), 0.0)

		if absf(from_body.y) > 0.001:
			return Vector2(0.0, signf(from_body.y))

	return -direction.normalized()
