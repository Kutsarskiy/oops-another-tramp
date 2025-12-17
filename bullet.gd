extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 1.2
@export var radius: float = 4.0
@export var color: Color = Color(1, 0.9, 0.2)

var direction: Vector2 = Vector2.RIGHT
var _time_left: float

func _ready() -> void:
	_time_left = lifetime
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)

func _on_body_entered(_body: Node) -> void:
	queue_free()

func _on_area_entered(_area: Area2D) -> void:
	queue_free()
