extends BaseBoss
class_name TestBoss

@export var move_speed: float = 100.0
@export var phase_2_speed_multiplier: float = 1.5
@export var contact_stop_distance: float = 118.0
@export var overlap_recovery_distance: float = 104.0
@export var overlap_recovery_speed_multiplier: float = 0.45

var player: Node2D = null

@onready var boss_sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var attack_controller: BossAttackController = $AttackController


func _ready() -> void:

	if boss_id == "base_boss" or boss_id.is_empty():
		boss_id = "test_boss"

	if boss_name == "Base Boss" or boss_name.is_empty():
		boss_name = "Test Boss"

	_ensure_placeholder_texture()

	super()

	player = get_tree().get_first_node_in_group("player")

	BossManager.register_main_boss(self)
	boss_started.connect(_on_boss_started)
	boss_defeated.connect(_on_boss_defeated)

	var shoot_attack := TestShootAttack.new()

	shoot_attack.initialize(self)

	attack_controller.add_attack(shoot_attack)
	attack_controller.set_active(false)


func _physics_process(_delta: float) -> void:
	if not is_fight_active():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if player == null:
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var direction := Vector2.ZERO

	if distance > 0.001:
		direction = to_player / distance

	if distance < overlap_recovery_distance:
		velocity = -direction * move_speed * overlap_recovery_speed_multiplier
	elif distance < contact_stop_distance:
		velocity = Vector2.ZERO
	else:
		velocity = direction * move_speed

	move_and_slide()


func enter_phase(phase_number: int) -> void:

	super(phase_number)

	match phase_number:

		2:
			move_speed *= phase_2_speed_multiplier

			print("TEST BOSS PHASE 2")


func _on_boss_started() -> void:
	attack_controller.set_active(true)


func _on_boss_defeated() -> void:
	attack_controller.set_active(false)


func _ensure_placeholder_texture() -> void:
	if boss_sprite == null:
		return

	if boss_sprite.texture != null and not (boss_sprite.texture is PlaceholderTexture2D):
		return

	var image := Image.create(160, 120, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var center := Vector2(80.0, 60.0)
	var outer_radius := Vector2(68.0, 48.0)
	var inner_radius := Vector2(58.0, 39.0)

	for y in range(120):
		for x in range(160):
			var offset := Vector2(float(x), float(y)) - center
			var outer_value := pow(offset.x / outer_radius.x, 2.0) + pow(offset.y / outer_radius.y, 2.0)
			var inner_value := pow(offset.x / inner_radius.x, 2.0) + pow(offset.y / inner_radius.y, 2.0)

			if inner_value <= 1.0:
				image.set_pixel(x, y, Color(0.47, 0.56, 0.70, 1.0))
			elif outer_value <= 1.0:
				image.set_pixel(x, y, Color(0.72, 0.76, 0.84, 1.0))

	image.fill_rect(Rect2i(54, 77, 52, 9), Color(0.15, 0.20, 0.30, 1.0))

	for eye_center in [Vector2i(58, 48), Vector2i(102, 48)]:
		for y in range(eye_center.y - 8, eye_center.y + 9):
			for x in range(eye_center.x - 8, eye_center.x + 9):
				var dist := Vector2(float(x - eye_center.x), float(y - eye_center.y)).length()

				if dist <= 8.0:
					image.set_pixel(x, y, Color.WHITE)

				if dist <= 4.0:
					image.set_pixel(x, y, Color(0.15, 0.20, 0.30, 1.0))

	boss_sprite.texture = ImageTexture.create_from_image(image)
