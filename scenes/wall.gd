@tool
extends StaticBody2D

@export var wall_size: Vector2 = Vector2(800, 80) : set = _set_wall_size
@export var wall_color: Color = Color(0.85, 0.75, 0.2, 1.0) : set = _set_wall_color

@onready var rect: ColorRect = $ColorRect
@onready var col: CollisionShape2D = $CollisionShape2D

func _ready():
	_apply()

func _set_wall_size(v: Vector2) -> void:
	wall_size = v
	_apply()

func _set_wall_color(v: Color) -> void:
	wall_color = v
	_apply()

func _apply() -> void:
	if not is_instance_valid(rect) or not is_instance_valid(col):
		return

	# Визуал
	rect.size = wall_size
	rect.position = -wall_size * 0.5
	rect.color = wall_color

	# Коллизия (в центр стены)
	var shape := col.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		col.shape = shape
	shape.size = wall_size
	col.position = Vector2.ZERO
