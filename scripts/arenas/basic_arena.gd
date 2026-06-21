@tool
extends Node2D
class_name BasicArena

const WALL_SCENE: PackedScene = preload("res://scenes/wall.tscn")
const MINION_SCENE: PackedScene = preload("res://scenes/minion.tscn")
const WEAPON_PICKUP_SCENE: PackedScene = preload("res://scenes/weapons/weapon_pickup.tscn")
const AMMO_PICKUP_SCENE: PackedScene = preload("res://scenes/items/ammo_pickup.tscn")

@export var arena_size: Vector2 = Vector2(2160.0, 2160.0) : set = _set_arena_size
@export var arena_color: Color = Color(0.42, 0.45, 0.43, 1.0) : set = _set_arena_color
@export var wall_color: Color = Color(0.25, 0.72, 0.55, 1.0) : set = _set_wall_color
@export var wall_thickness: float = 80.0 : set = _set_wall_thickness
@export var spawn_debug_pickups: bool = true
@export var spawn_debug_minion: bool = true

var _background_layer: CanvasLayer = null
var _background_rect: ColorRect = null
var _walls: Node2D = null
var _debug_content: Node2D = null


func _ready() -> void:
	_ensure_arena_nodes()
	_apply_arena()


func _set_arena_size(value: Vector2) -> void:
	arena_size = value
	_apply_arena()


func _set_arena_color(value: Color) -> void:
	arena_color = value
	_apply_arena()


func _set_wall_color(value: Color) -> void:
	wall_color = value
	_apply_arena()


func _set_wall_thickness(value: float) -> void:
	wall_thickness = value
	_apply_arena()


func _ensure_arena_nodes() -> void:
	_background_layer = get_node_or_null("Background") as CanvasLayer

	if _background_layer == null:
		_background_layer = CanvasLayer.new()
		_background_layer.name = "Background"
		_background_layer.layer = -10
		add_child(_background_layer)
		_background_layer.owner = owner if owner != null else self

	_background_rect = _background_layer.get_node_or_null("ColorRect") as ColorRect

	if _background_rect == null:
		_background_rect = ColorRect.new()
		_background_rect.name = "ColorRect"
		_background_layer.add_child(_background_rect)
		_background_rect.owner = owner if owner != null else self

	_walls = get_node_or_null("Walls") as Node2D

	if _walls == null:
		_walls = Node2D.new()
		_walls.name = "Walls"
		add_child(_walls)
		_walls.owner = owner if owner != null else self

	_ensure_wall("WallTop")
	_ensure_wall("WallBottom")
	_ensure_wall("WallLeft")
	_ensure_wall("WallRight")

	if not Engine.is_editor_hint():
		_ensure_debug_content()


func _ensure_wall(wall_name: String) -> Node2D:
	var wall := _walls.get_node_or_null(wall_name) as Node2D

	if wall != null:
		return wall

	wall = WALL_SCENE.instantiate() as Node2D
	wall.name = wall_name
	_walls.add_child(wall)
	wall.owner = owner if owner != null else self

	return wall


func _ensure_debug_content() -> void:
	_debug_content = get_node_or_null("DebugContent") as Node2D

	if _debug_content == null:
		_debug_content = Node2D.new()
		_debug_content.name = "DebugContent"
		add_child(_debug_content)

	if _debug_content.get_child_count() > 0:
		return

	if spawn_debug_minion:
		var minion := MINION_SCENE.instantiate() as Node2D
		minion.position = Vector2(300.0, 0.0)
		_debug_content.add_child(minion)

	if spawn_debug_pickups:
		_spawn_weapon_pickup(Vector2(0.0, -160.0), "the_final_offer")
		_spawn_weapon_pickup(Vector2(0.0, 160.0), "the_second_amendment")
		_spawn_ammo_pickup(Vector2(260.0, -80.0), "universal")
		_spawn_ammo_pickup(Vector2(260.0, 80.0), "shotgun")
		_spawn_ammo_pickup(Vector2(260.0, 200.0), "rifle")
		_spawn_ammo_pickup(Vector2(260.0, 320.0), "sidearm")


func _spawn_weapon_pickup(spawn_position: Vector2, weapon_id: String) -> void:
	var pickup := WEAPON_PICKUP_SCENE.instantiate() as Node2D
	pickup.position = spawn_position
	pickup.set("debug_weapon_id", weapon_id)
	pickup.set("create_weapon_on_ready", true)
	_debug_content.add_child(pickup)


func _spawn_ammo_pickup(spawn_position: Vector2, ammo_type: String) -> void:
	var pickup := AMMO_PICKUP_SCENE.instantiate() as Node2D
	pickup.position = spawn_position
	pickup.set("ammo_type", ammo_type)
	_debug_content.add_child(pickup)


func _apply_arena() -> void:
	if not is_inside_tree():
		return

	_ensure_arena_nodes()
	_apply_background()
	_apply_walls()


func _apply_background() -> void:
	if _background_rect == null:
		return

	_background_rect.color = arena_color
	_background_rect.anchor_left = 0.0
	_background_rect.anchor_top = 0.0
	_background_rect.anchor_right = 1.0
	_background_rect.anchor_bottom = 1.0
	_background_rect.offset_left = 0.0
	_background_rect.offset_top = 0.0
	_background_rect.offset_right = 0.0
	_background_rect.offset_bottom = 0.0


func _apply_walls() -> void:
	var half_size := arena_size * 0.5

	_configure_wall("WallTop", Vector2(0.0, -half_size.y), Vector2(arena_size.x, wall_thickness))
	_configure_wall("WallBottom", Vector2(0.0, half_size.y), Vector2(arena_size.x, wall_thickness))
	_configure_wall("WallLeft", Vector2(-half_size.x, 0.0), Vector2(wall_thickness, arena_size.y))
	_configure_wall("WallRight", Vector2(half_size.x, 0.0), Vector2(wall_thickness, arena_size.y))


func _configure_wall(wall_name: String, wall_position: Vector2, wall_size: Vector2) -> void:
	var wall := _ensure_wall(wall_name)

	wall.position = wall_position
	wall.set("wall_size", wall_size)
	wall.set("wall_color", wall_color)
