extends BaseBoss

@export var move_speed: float = 100.0
@export var phase_2_speed_multiplier: float = 1.5

var player: Node2D = null

@onready var attack_controller: BossAttackController = $AttackController


func _ready() -> void:

	boss_id = "test_boss"
	boss_name = "Test Boss"

	super()

	player = get_tree().get_first_node_in_group("player")

	BossManager.register_main_boss(self)

	var shoot_attack := TestShootAttack.new()

	shoot_attack.initialize(self)

	attack_controller.add_attack(shoot_attack)


func _physics_process(_delta: float) -> void:

	if player == null:
		return

	var direction := global_position.direction_to(
		player.global_position
	)

	velocity = direction * move_speed

	move_and_slide()


func enter_phase(phase_number: int) -> void:

	super(phase_number)

	match phase_number:

		2:
			move_speed *= phase_2_speed_multiplier

			print("TEST BOSS PHASE 2")
