extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 1.2
@export var radius: float = 4.0
@export var color: Color = Color(1, 0.9, 0.2)

@export var damage: int = 1
@export var team: StringName = &"player" # "player" или "enemy"

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

func _on_body_entered(body: Node) -> void:
	# если вдруг столкнулось со "своими" — игнорим
	if body.is_in_group(team):
		return

	if body.has_method("take_damage"):
		body.call("take_damage", damage)

	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# обычно можно просто уничтожать при входе в чужие area
	if area.is_in_group(team):
		return
	queue_free()

func setup_bullet(is_enemy: bool) -> void:
	if is_enemy:
		team = &"enemy"
		collision_mask = (1 << 0) | (1 << 1) # стены(1) + игрок(2)
		color = Color(1, 0.3, 0.3)
	else:
		team = &"player"
		collision_mask = (1 << 0) | (1 << 3) # стены(1) + враги(4)
		color = Color(1, 0.9, 0.2)
	queue_redraw()
