extends Area2D
class_name TechnoKingHomingRocket


const WALL_COLLISION_LAYER_BIT: int = 0
const PLAYER_HURTBOX_LAYER_BIT: int = 4
const ENEMY_COLLISION_LAYER_BIT: int = 3
const RocketExplosionEffectScript: Script = preload("res://scripts/effects/rocket_explosion_effect.gd")

@export var speed: float = 500.0
@export var max_hp: int = 3
@export var damage: int = 1
@export var turn_rate: float = 4.6
@export var lifetime: float = -1.0
@export var flank_duration: float = 0.75
@export var loop_duration: float = 1.35
@export var wave_strength: float = 1.65
@export var wave_frequency: float = 2.4
@export var orbit_strength: float = 2.6
@export var orbit_frequency: float = 0.82
@export var player_pull_strength: float = 0.35
@export var chase_player_pull_strength: float = 0.72
@export var weave_sign: float = 1.0
@export var texture_root: String = "res://assets/projectiles/enemy/techno_king/missile"
@export var rocket_z_index: int = 45
@export var pulse_frequency: float = 4.0
@export var pulse_amount: float = 0.08
@export var warning_outline_radius: float = 34.0
@export var warning_outline_color: Color = Color(1.0, 0.1, 0.04, 0.9)
@export var miss_explosion_shake_duration: float = 0.5
@export var miss_explosion_shake_strength: float = 15.0
@export var impact_knockback_force: float = 500.0
@export var explosion_visual_radius: float = 62.0

var direction: Vector2 = Vector2.RIGHT
var current_hp: int = 3

var _sprite: Sprite2D = null
var _collision_shape: CollisionShape2D = null
var _time_left: float = 0.0
var _elapsed: float = 0.0
var _textures: Dictionary = {}
var _is_destroyed: bool = false


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("enemy_bullet")
	add_to_group("techno_king_rocket")
	collision_layer = 1 << ENEMY_COLLISION_LAYER_BIT
	collision_mask = (1 << WALL_COLLISION_LAYER_BIT) | (1 << PLAYER_HURTBOX_LAYER_BIT)
	monitoring = true
	monitorable = true

	current_hp = max_hp
	_time_left = lifetime
	z_index = rocket_z_index
	_ensure_nodes()
	_load_direction_textures()
	_update_sprite_direction()

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func configure(
	new_direction: Vector2,
	new_speed: float,
	new_hp: int,
	new_lifetime: float,
	new_weave_sign: float
) -> void:
	direction = new_direction.normalized() if new_direction.length_squared() > 0.001 else Vector2.RIGHT
	speed = new_speed
	max_hp = new_hp
	current_hp = max_hp
	lifetime = new_lifetime
	_time_left = lifetime
	weave_sign = new_weave_sign


func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return

	_elapsed += delta

	if lifetime > 0.0:
		_time_left = maxf(_time_left - delta, 0.0)

		if _time_left <= 0.0:
			_explode_as_miss()
			return

	_update_homing_direction(delta)
	global_position += direction * speed * delta
	_update_visual_attention()
	_update_sprite_direction()
	queue_redraw()


func take_damage(amount: int) -> void:
	if _is_destroyed:
		return

	current_hp -= maxi(amount, 1)

	if current_hp <= 0:
		_explode()


func _ensure_nodes() -> void:
	_sprite = get_node_or_null("Sprite2D") as Sprite2D

	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)

	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D

	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)

	if _collision_shape.shape == null:
		var circle := CircleShape2D.new()
		circle.radius = 22.0
		_collision_shape.shape = circle


func _load_direction_textures() -> void:
	_textures.clear()

	for direction_name in [
		"east",
		"north-east",
		"north",
		"north-west",
		"west",
		"south-west",
		"south",
		"south-east"
	]:
		var path := "%s/%s.png" % [texture_root, direction_name]

		if ResourceLoader.exists(path):
			var resource := load(path)

			if resource is Texture2D:
				_textures[direction_name] = resource
				continue

		var image := Image.new()
		var error := image.load(path)

		if error == OK:
			_textures[direction_name] = ImageTexture.create_from_image(image)


func _update_homing_direction(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		return

	var to_player := player.global_position - global_position

	if to_player.length_squared() <= 0.001:
		return

	var desired_direction := to_player.normalized()
	var side_direction := desired_direction.orthogonal() * weave_sign
	var desired_pull := player_pull_strength
	var curve_component := Vector2.ZERO

	if _elapsed < flank_duration:
		var flank_t := _elapsed / maxf(flank_duration, 0.01)
		curve_component = side_direction * lerpf(orbit_strength, orbit_strength * 0.65, flank_t)
		desired_pull = 0.22
	elif _elapsed < flank_duration + loop_duration:
		var loop_t := (_elapsed - flank_duration) / maxf(loop_duration, 0.01)
		var loop_angle := loop_t * TAU * weave_sign
		var loop_direction := desired_direction.rotated(loop_angle).normalized()
		curve_component = loop_direction * orbit_strength
		desired_pull = 0.18
	else:
		var fast_weave := side_direction * sin(_elapsed * TAU * wave_frequency) * wave_strength
		var slow_orbit := side_direction * cos(_elapsed * TAU * orbit_frequency) * orbit_strength * 0.55
		curve_component = fast_weave + slow_orbit
		desired_pull = chase_player_pull_strength

	desired_direction = (desired_direction * desired_pull + curve_component).normalized()
	var turn_weight := clampf(delta * turn_rate, 0.0, 1.0)
	direction = direction.lerp(desired_direction, turn_weight).normalized()


func _update_sprite_direction() -> void:
	if _sprite == null or direction.length_squared() <= 0.001:
		return

	var direction_name := _get_direction_name(direction)
	var texture: Texture2D = _textures.get(direction_name, null)

	if texture != null:
		_sprite.texture = texture


func _update_visual_attention() -> void:
	if _sprite == null:
		return

	var pulse := 1.0 + sin(_elapsed * TAU * pulse_frequency) * pulse_amount
	_sprite.scale = Vector2.ONE * pulse


func _draw() -> void:
	if sin(_elapsed * TAU * 5.0) < -0.2:
		return

	draw_arc(
		Vector2.ZERO,
		warning_outline_radius,
		0.0,
		TAU,
		36,
		warning_outline_color,
		3.0
	)


func _get_direction_name(vector: Vector2) -> String:
	var angle := wrapf(vector.angle(), -PI, PI)
	var index := int(round(angle / (PI / 4.0))) % 8

	if index < 0:
		index += 8

	match index:
		0:
			return "east"
		1:
			return "south-east"
		2:
			return "south"
		3:
			return "south-west"
		4:
			return "west"
		5:
			return "north-west"
		6:
			return "north"
		7:
			return "north-east"

	return "east"


func _on_body_entered(_body: Node) -> void:
	_explode()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		return

	var damage_target := _get_damage_target_from_area(area)

	if damage_target != null:
		_explode_on_player(damage_target)


func _get_damage_target_from_area(area: Area2D) -> Node:
	if area.has_method("take_damage"):
		return area

	if area.has_meta("damage_owner"):
		var damage_owner: Variant = area.get_meta("damage_owner")

		if damage_owner is Node:
			return damage_owner as Node

	var parent_node := area.get_parent()

	if parent_node != null and parent_node.has_method("take_damage"):
		return parent_node

	return null


func _destroy() -> void:
	if _is_destroyed:
		return

	_is_destroyed = true
	queue_free()


func _explode_as_miss() -> void:
	_explode()


func _explode() -> void:
	if _is_destroyed:
		return

	_play_miss_explosion_feedback()
	_spawn_explosion_visual()
	_destroy()


func _explode_on_player(damage_target: Node) -> void:
	if _is_destroyed:
		return

	_play_miss_explosion_feedback()
	_spawn_explosion_visual()

	if _can_apply_player_hit_effects(damage_target) and damage_target.has_method("apply_heavy_hit_knockback"):
		damage_target.call("apply_heavy_hit_knockback", global_position, impact_knockback_force)

	if damage_target.has_method("take_damage"):
		damage_target.call("take_damage", damage)

	_destroy()


func _can_apply_player_hit_effects(damage_target: Node) -> bool:
	if damage_target.has_method("is_invulnerable") and bool(damage_target.call("is_invulnerable")):
		return false

	if damage_target.has_method("is_debug_hurtbox_disabled") and bool(damage_target.call("is_debug_hurtbox_disabled")):
		return false

	return true


func _play_miss_explosion_feedback() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var played_feedback := false

	if player != null and player.has_method("play_phase_transition_feedback"):
		player.call("play_phase_transition_feedback", miss_explosion_shake_duration, miss_explosion_shake_strength)
		played_feedback = true

	if not played_feedback:
		var camera := get_viewport().get_camera_2d()

		if camera != null and camera.has_method("set_shake_offset"):
			var shake_offset := Vector2.RIGHT.rotated(randf() * TAU) * miss_explosion_shake_strength
			camera.call("set_shake_offset", shake_offset)


func _spawn_explosion_visual() -> void:
	var parent_node := get_parent()

	if parent_node == null:
		return

	var explosion = RocketExplosionEffectScript.new()
	explosion.radius = explosion_visual_radius
	explosion.shake_duration = miss_explosion_shake_duration
	explosion.shake_strength = miss_explosion_shake_strength
	parent_node.add_child(explosion)
	explosion.global_position = global_position
