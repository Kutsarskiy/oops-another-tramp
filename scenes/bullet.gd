extends Area2D

@export var speed: float = 680.0
@export var lifetime: float = 1.45
@export var radius: float = 9.0
@export var color: Color = Color(1.0, 0.72, 0.18)

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
	draw_circle(Vector2.ZERO, radius + 3.0, Color(color.r, color.g, color.b, 0.18))
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(-radius * 0.28, -radius * 0.28), radius * 0.32, Color(1.0, 0.95, 0.62, 0.85))


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

		# Слой 1 — стены.
		# Слой 5 — PlayerHurtbox.
		# Вражеские пули больше не бьют основной Player CollisionShape2D.
		collision_mask = (1 << 0) | (1 << 4)

		speed = 560.0
		radius = 10.0
		color = Color(1.0, 0.52, 0.16)
	else:
		team = &"player"

		# Слой 1 — стены.
		# Слой 4 — враги.
		collision_mask = (1 << 0) | (1 << 3)

		color = Color(1.0, 0.78, 0.20)

	_apply_collision_radius()
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

	var damage_target: Node = _get_damage_target_from_area(area)

	if damage_target != null:
		if damage_target.is_in_group(team):
			return

		if damage_target.has_method("take_damage"):
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
