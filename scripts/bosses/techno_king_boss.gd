extends TestBoss
class_name TechnoKingBoss

const PaperStateSpriteScript: Script = preload("res://scripts/visuals/paper_state_sprite.gd")
const TechnoKingAttackSlotScript: Script = preload("res://scripts/boss_attacks/techno_king_attack_slot.gd")
const PlatformTurretsAttackScript: Script = preload("res://scripts/boss_attacks/platform_turrets_attack.gd")
const CybertruckTestAttackScript: Script = preload("res://scripts/boss_attacks/cybertruck_test_attack.gd")
const HomingRocketsAttackScript: Script = preload("res://scripts/boss_attacks/homing_rockets_attack.gd")

const TEXTURE_PATHS: Dictionary = {
	&"phase_1_idle": "res://assets/characters/bosses/techno_king/paper/phase_1_idle.png",
	&"phase_1_metal_sphere": "res://assets/characters/bosses/techno_king/paper/phase_1_metal_sphere.png",
	&"phase_1_rocket_launch": "res://assets/characters/bosses/techno_king/paper/phase_1_rocket_launch.png",
	&"phase_1_support_call": "res://assets/characters/bosses/techno_king/paper/phase_1_support_call.png",
	&"phase_2_idle": "res://assets/characters/bosses/techno_king/paper/phase_2_idle.png",
	&"phase_2_dogecoin_pump_1": "res://assets/characters/bosses/techno_king/paper/dogecoin_pump/1.png",
	&"phase_2_dogecoin_pump_2": "res://assets/characters/bosses/techno_king/paper/dogecoin_pump/2.png",
	&"phase_2_dogecoin_pump_3": "res://assets/characters/bosses/techno_king/paper/dogecoin_pump/3.png",
	&"phase_2_dogecoin_pump_4": "res://assets/characters/bosses/techno_king/paper/dogecoin_pump/4.png",
	&"phase_2_dogecoin_pump_5": "res://assets/characters/bosses/techno_king/paper/dogecoin_pump/5.png",
	&"phase_2_dogecoin_pump_6": "res://assets/characters/bosses/techno_king/paper/dogecoin_pump/6.png",
	&"phase_3_sprint": "res://assets/characters/bosses/techno_king/paper/phase_3_sprint.png",
	&"phase_3_strike_call": "res://assets/characters/bosses/techno_king/paper/phase_3_strike_call.png",
	&"metal_sphere": "res://assets/projectiles/enemy/techno_king/metal_sphere/metal_sphere.png",
	&"tesla_coil_idle": "res://assets/interactables/techno_king/tesla_coil/tesla_coil_idle.png",
	&"tesla_coil_charged": "res://assets/interactables/techno_king/tesla_coil/tesla_coil_charged.png"
}

const DIRECTIONAL_TEXTURE_SETS: Dictionary = {
	&"combat_drone": "res://assets/enemies/techno_king/combat_drone",
	&"kamikaze_drone": "res://assets/enemies/techno_king/kamikaze_drone",
	&"missile": "res://assets/projectiles/enemy/techno_king/missile"
}

const ATTACK_BLUEPRINTS: Array[Dictionary] = [
	{"id": &"platform_turrets", "name": "Platform Turrets", "phase": 1, "assets": []},
	{"id": &"cybertruck_test", "name": "Cybertruck Test", "phase": 1, "assets": [&"phase_1_metal_sphere", &"metal_sphere"]},
	{"id": &"homing_rockets", "name": "Homing Rockets", "phase": 1, "assets": [&"phase_1_rocket_launch", &"missile"]},
	{"id": &"support_drones", "name": "Support Drones", "phase": 1, "assets": [&"phase_1_support_call", &"combat_drone"]},
	{"id": &"emergency_supplies", "name": "Emergency Supplies", "phase": 1, "assets": []},
	{"id": &"drone_swarm", "name": "Drone Swarm", "phase": 2, "assets": [&"combat_drone"]},
	{"id": &"kamikaze_drones", "name": "Kamikaze Drones", "phase": 2, "assets": [&"kamikaze_drone"]},
	{"id": &"pump_dogecoin", "name": "Pump Dogecoin", "phase": 2, "assets": [&"phase_2_dogecoin_pump_1"]},
	{"id": &"tesla_coil_network", "name": "Tesla Coil Network", "phase": 2, "assets": [&"tesla_coil_idle", &"tesla_coil_charged"]},
	{"id": &"orbital_bombardment", "name": "Orbital Bombardment", "phase": 3, "assets": [&"phase_3_strike_call", &"missile"]},
	{"id": &"kamikaze_rush", "name": "Kamikaze Rush", "phase": 3, "assets": [&"kamikaze_drone"]},
	{"id": &"vulnerable_command_link", "name": "Vulnerable Command Link", "phase": 3, "assets": [&"phase_3_strike_call"]}
]

@export var paper_state_texture_paths: Dictionary = {
	&"phase_1_idle": TEXTURE_PATHS[&"phase_1_idle"],
	&"phase_1_metal_sphere": TEXTURE_PATHS[&"phase_1_metal_sphere"],
	&"phase_1_rocket_launch": TEXTURE_PATHS[&"phase_1_rocket_launch"],
	&"phase_1_support_call": TEXTURE_PATHS[&"phase_1_support_call"],
	&"phase_2_idle": TEXTURE_PATHS[&"phase_2_idle"],
	&"phase_3_sprint": TEXTURE_PATHS[&"phase_3_sprint"],
	&"phase_3_strike_call": TEXTURE_PATHS[&"phase_3_strike_call"]
}
@export var platform_flight_speed: float = 265.0
@export var platform_target_arrival_distance: float = 80.0
@export var platform_reposition_min_interval: float = 1.15
@export var platform_reposition_max_interval: float = 2.35
@export var platform_player_avoid_distance: float = 340.0
@export var platform_position_padding: Vector2 = Vector2(210.0, 190.0)
@export var platform_strafe_strength: float = 0.42
@export var platform_velocity_smoothing: float = 4.5
@export var special_attack_initial_interval: float = 3.0
@export var special_attack_interval: float = 10.0

var _paper_visual = PaperStateSpriteScript.new()
var _attack_slots: Dictionary = {}
var _special_attacks: Dictionary = {}
var _special_attack_ids: Array[StringName] = [&"cybertruck_test", &"homing_rockets"]
var _special_attack_timer: float = 0.0
var _last_special_attack_id: StringName = &""
var _platform_target_position: Vector2 = Vector2.ZERO
var _platform_reposition_left: float = 0.0
var _platform_strafe_side: float = 1.0
var _visual_override_state: StringName = &""


func _ready() -> void:
	boss_id = "techno_king"
	boss_name = "The Techno-King"
	boss_max_hp = 180.0
	debug_max_phase = 3
	phase_thresholds = {
		2: 0.50,
		3: 0.10
	}
	move_speed = 130.0
	phase_2_speed_multiplier = 1.15

	_paper_visual.setup(boss_sprite, paper_state_texture_paths)
	super()
	_replace_basic_attack_with_platform_turrets()
	_register_attack_slots()
	_special_attack_timer = special_attack_initial_interval
	_choose_new_platform_target()
	_update_paper_visual()


func _physics_process(delta: float) -> void:
	if _update_global_stun(delta):
		velocity = Vector2.ZERO
		move_and_slide()
		_update_paper_visual()
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if not is_fight_active():
		velocity = Vector2.ZERO
		move_and_slide()
		_update_paper_visual()
		return

	_update_special_attack_schedule(delta)
	_update_platform_flight(delta)
	_update_paper_visual()


func enter_phase(phase_number: int) -> void:
	super(phase_number)
	_update_paper_visual()


func get_techno_king_texture_path(texture_key: StringName) -> String:
	return TEXTURE_PATHS.get(texture_key, "")


func get_directional_texture_set_path(texture_set_key: StringName) -> String:
	return DIRECTIONAL_TEXTURE_SETS.get(texture_set_key, "")


func get_attack_blueprints() -> Array[Dictionary]:
	return ATTACK_BLUEPRINTS.duplicate(true)


func get_attack_slot(attack_id: StringName) -> BossAttack:
	return _attack_slots.get(attack_id, null)


func can_use_platform_turrets() -> bool:
	return is_fight_active() and current_phase == 1


func can_use_cybertruck_test() -> bool:
	return is_fight_active() and current_phase == 1 and _visual_override_state.is_empty()


func can_use_homing_rockets() -> bool:
	return is_fight_active() and current_phase == 1 and _visual_override_state.is_empty()


func set_techno_king_visual_override(state: StringName) -> void:
	_visual_override_state = state
	_update_paper_visual()


func clear_techno_king_visual_override(state: StringName = &"") -> void:
	if not state.is_empty() and _visual_override_state != state:
		return

	_visual_override_state = &""
	_update_paper_visual()


func _register_attack_slots() -> void:
	if attack_controller == null:
		return

	for blueprint in ATTACK_BLUEPRINTS:
		var slot = TechnoKingAttackSlotScript.new()
		var asset_keys: Array[StringName] = []

		for asset_key in blueprint.get("assets", []):
			asset_keys.append(asset_key)

		slot.configure(
			blueprint.get("id", &""),
			blueprint.get("name", "Techno King Attack"),
			blueprint.get("phase", 1),
			asset_keys
		)
		slot.initialize(self)
		_attack_slots[slot.attack_id] = slot


func _replace_basic_attack_with_platform_turrets() -> void:
	if attack_controller == null:
		return

	attack_controller.attacks.clear()

	var platform_turrets: BossAttack = PlatformTurretsAttackScript.new()
	platform_turrets.initialize(self)
	attack_controller.add_attack(platform_turrets)

	var cybertruck_test: BossAttack = CybertruckTestAttackScript.new()
	cybertruck_test.initialize(self)
	attack_controller.add_attack(cybertruck_test)
	_special_attacks[&"cybertruck_test"] = cybertruck_test

	var homing_rockets: BossAttack = HomingRocketsAttackScript.new()
	homing_rockets.initialize(self)
	attack_controller.add_attack(homing_rockets)
	_special_attacks[&"homing_rockets"] = homing_rockets


func _update_special_attack_schedule(delta: float) -> void:
	if current_phase != 1:
		return

	if _is_special_attack_busy():
		return

	_special_attack_timer = maxf(_special_attack_timer - delta, 0.0)

	if _special_attack_timer > 0.0:
		return

	if _try_start_random_special_attack():
		_special_attack_timer = special_attack_interval
	else:
		_special_attack_timer = 0.5


func _is_special_attack_busy() -> bool:
	if not _visual_override_state.is_empty():
		return true

	for attack in _special_attacks.values():
		if attack != null and attack.has_method("is_busy") and bool(attack.call("is_busy")):
			return true

	return false


func _try_start_random_special_attack() -> bool:
	var candidates := _special_attack_ids.duplicate()

	if candidates.size() > 1 and candidates.has(_last_special_attack_id):
		candidates.erase(_last_special_attack_id)

	candidates.shuffle()

	for attack_id in candidates:
		var attack = _special_attacks.get(attack_id, null)

		if attack == null or not attack.has_method("force_start"):
			continue

		if bool(attack.call("force_start")):
			_last_special_attack_id = attack_id
			return true

	return false


func _update_platform_flight(delta: float) -> void:
	_platform_reposition_left = maxf(_platform_reposition_left - delta, 0.0)

	if _platform_target_position == Vector2.ZERO:
		_choose_new_platform_target()

	var to_target := _platform_target_position - global_position

	if to_target.length() <= platform_target_arrival_distance or _platform_reposition_left <= 0.0:
		_choose_new_platform_target()
		to_target = _platform_target_position - global_position

	var desired_velocity := Vector2.ZERO

	if to_target.length_squared() > 0.001:
		desired_velocity = to_target.normalized() * platform_flight_speed

	if player != null and is_instance_valid(player):
		var away_from_player := global_position - player.global_position
		var distance_to_player := away_from_player.length()

		if distance_to_player > 0.001 and distance_to_player < platform_player_avoid_distance:
			var avoid_factor := 1.0 - distance_to_player / platform_player_avoid_distance
			desired_velocity += away_from_player.normalized() * platform_flight_speed * avoid_factor

		var to_player := player.global_position - global_position

		if to_player.length_squared() > 0.001:
			desired_velocity += to_player.normalized().orthogonal() * platform_flight_speed * platform_strafe_strength * _platform_strafe_side

	desired_velocity = desired_velocity.limit_length(platform_flight_speed)
	velocity = velocity.lerp(desired_velocity, clampf(delta * platform_velocity_smoothing, 0.0, 1.0))
	move_and_slide()
	global_position = _clamp_to_platform_flight_rect(global_position)


func _choose_new_platform_target() -> void:
	var flight_rect := _get_platform_flight_rect()
	var best_position := flight_rect.get_center()
	var best_score := -INF

	for i in range(10):
		var candidate := Vector2(
			randf_range(flight_rect.position.x, flight_rect.end.x),
			randf_range(flight_rect.position.y, flight_rect.end.y)
		)
		var score := candidate.distance_to(global_position) * 0.45

		if player != null and is_instance_valid(player):
			var player_distance := candidate.distance_to(player.global_position)
			score += minf(player_distance, 760.0) * 0.75

			if player_distance < platform_player_avoid_distance:
				score -= (platform_player_avoid_distance - player_distance) * 2.2

		if score > best_score:
			best_score = score
			best_position = candidate

	_platform_target_position = best_position
	_platform_reposition_left = randf_range(platform_reposition_min_interval, platform_reposition_max_interval)
	_platform_strafe_side = -1.0 if randf() < 0.5 else 1.0


func _get_platform_flight_rect() -> Rect2:
	var center := _get_current_arena_center()
	var size := Vector2(1800.0, 1350.0)
	var game_root := get_tree().current_scene

	if game_root != null:
		var arena_container := game_root.get_node_or_null("ArenaContainer")

		if arena_container != null:
			for child in arena_container.get_children():
				if child is Node2D and child.get("arena_size") is Vector2:
					size = child.get("arena_size")
					break

	var usable_size := Vector2(
		maxf(size.x - platform_position_padding.x * 2.0, 200.0),
		maxf(size.y - platform_position_padding.y * 2.0, 200.0)
	)

	return Rect2(center - usable_size * 0.5, usable_size)


func _get_current_arena_center() -> Vector2:
	var game_root := get_tree().current_scene

	if game_root == null:
		return Vector2.ZERO

	var arena_container := game_root.get_node_or_null("ArenaContainer")

	if arena_container == null:
		return Vector2.ZERO

	for child in arena_container.get_children():
		if child is Node2D and child.get("arena_size") is Vector2:
			return (child as Node2D).global_position

	return Vector2.ZERO


func _clamp_to_platform_flight_rect(point: Vector2) -> Vector2:
	var flight_rect := _get_platform_flight_rect()

	return Vector2(
		clampf(point.x, flight_rect.position.x, flight_rect.end.x),
		clampf(point.y, flight_rect.position.y, flight_rect.end.y)
	)


func _update_paper_visual() -> void:
	if boss_sprite == null:
		return

	if not _visual_override_state.is_empty() and _paper_visual.has_state(_visual_override_state):
		_paper_visual.set_state(_visual_override_state)
	elif current_phase >= 3 and _paper_visual.has_state(&"phase_3_sprint"):
		_paper_visual.set_state(&"phase_3_sprint")
	elif current_phase >= 2 and _paper_visual.has_state(&"phase_2_idle"):
		_paper_visual.set_state(&"phase_2_idle")
	else:
		_paper_visual.set_state(&"phase_1_idle")

	if player != null and is_instance_valid(player):
		_paper_visual.face_target(global_position, player.global_position)
