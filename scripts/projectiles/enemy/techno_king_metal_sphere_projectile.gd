extends Node2D
class_name TechnoKingMetalSphereProjectile


const FloorCrackDecalScript: Script = preload("res://scripts/effects/floor_crack_decal.gd")

@export var texture_path: String = "res://assets/projectiles/enemy/techno_king/metal_sphere/metal_sphere.png"
@export var speed: float = 600.0
@export var damage: int = 1
@export var impact_radius: float = 115.0
@export var impact_shake_duration: float = 0.5
@export var impact_shake_strength: float = 25.0
@export var impact_knockback_force: float = 850.0
@export var crack_radius: float = 145.0
@export var start_visual_scale: float = 0.48
@export var peak_visual_scale: float = 1.28
@export var impact_visual_scale: float = 0.86

var start_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var warning_marker: Node = null

var _sprite: Sprite2D = null
var _travel_duration: float = 0.01
var _elapsed: float = 0.0
var _has_impacted: bool = false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_load_texture()
	global_position = start_position
	z_index = 35


func configure(
	new_start_position: Vector2,
	new_target_position: Vector2,
	new_speed: float,
	new_damage: int,
	new_impact_radius: float,
	new_warning_marker: Node = null
) -> void:
	start_position = new_start_position
	target_position = new_target_position
	speed = new_speed
	damage = new_damage
	impact_radius = new_impact_radius
	warning_marker = new_warning_marker

	var distance := start_position.distance_to(target_position)
	_travel_duration = maxf(distance / maxf(speed, 1.0), 0.01)
	_elapsed = 0.0
	_has_impacted = false


func _process(delta: float) -> void:
	if _has_impacted:
		return

	_elapsed += delta
	var progress := clampf(_elapsed / _travel_duration, 0.0, 1.0)
	global_position = start_position.lerp(target_position, progress)
	_update_visual_arc(progress)

	if progress >= 1.0:
		_impact()


func _load_texture() -> void:
	if _sprite == null:
		return

	if ResourceLoader.exists(texture_path):
		var resource := load(texture_path)

		if resource is Texture2D:
			_sprite.texture = resource as Texture2D
			return

	var image := Image.new()
	var error := image.load(texture_path)

	if error != OK:
		push_warning("Metal sphere texture failed to load: %s" % texture_path)
		return

	_sprite.texture = ImageTexture.create_from_image(image)


func _update_visual_arc(progress: float) -> void:
	if _sprite == null:
		return

	var arc_scale := 1.0

	if progress < 0.5:
		arc_scale = lerpf(start_visual_scale, peak_visual_scale, progress / 0.5)
	else:
		arc_scale = lerpf(peak_visual_scale, impact_visual_scale, (progress - 0.5) / 0.5)

	_sprite.scale = Vector2.ONE * arc_scale
	_sprite.rotation = 0.0


func _impact() -> void:
	_has_impacted = true
	global_position = target_position

	if warning_marker != null and is_instance_valid(warning_marker):
		warning_marker.queue_free()

	_spawn_floor_cracks()
	_play_impact_shake()

	var player := get_tree().get_first_node_in_group("player") as Node2D

	if player != null and player.global_position.distance_to(target_position) <= impact_radius:
		if _can_damage_player(player) and player.has_method("take_damage"):
			if player.has_method("apply_heavy_hit_knockback"):
				player.call("apply_heavy_hit_knockback", target_position, impact_knockback_force)

			player.call("take_damage", damage)

	queue_free()


func _spawn_floor_cracks() -> void:
	var parent_node := get_parent()

	if parent_node == null:
		return

	var cracks = FloorCrackDecalScript.new()
	cracks.crack_radius = crack_radius
	parent_node.add_child(cracks)
	cracks.global_position = target_position


func _play_impact_shake() -> void:
	var player := get_tree().get_first_node_in_group("player")

	if player != null and player.has_method("play_phase_transition_feedback"):
		player.call("play_phase_transition_feedback", impact_shake_duration, impact_shake_strength)


func _can_damage_player(player: Node) -> bool:
	if player.has_method("is_invulnerable") and bool(player.call("is_invulnerable")):
		return false

	if player.has_method("is_debug_hurtbox_disabled") and bool(player.call("is_debug_hurtbox_disabled")):
		return false

	return true
