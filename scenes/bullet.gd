extends Area2D

@export var speed: float = 900.0
@export var lifetime: float = 1.2
@export var radius: float = 4.0
@export var color: Color = Color(1, 0.9, 0.2)

@export var damage: int = 1
@export var team: StringName = &"player" # "player" или "enemy"

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var _time_left: float


func _ready() -> void:
	_time_left = lifetime
	_apply_collision_radius()

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


func configure_projectile(
	new_damage: int,
	new_speed: float,
	new_lifetime: float,
	new_radius: float,
	new_color: Color
) -> void:
	damage = new_damage
	speed = new_speed
	lifetime = new_lifetime
	radius = new_radius
	color = new_color

	_apply_collision_radius()
	queue_redraw()


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


func _apply_collision_radius() -> void:
	if collision_shape == null:
		return

	var circle_shape := collision_shape.shape as CircleShape2D

	if circle_shape == null:
		return

	circle_shape.radius = radius


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(team):
		return

	if body.has_method("take_damage"):
		body.call("take_damage", damage)

	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(team):
		return

	queue_free()
