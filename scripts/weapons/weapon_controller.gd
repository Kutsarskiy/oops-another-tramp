extends Node
class_name WeaponController

const WEAPON_PICKUP_SCRIPT: Script = preload("res://scripts/weapons/weapon_pickup.gd")

@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
@export var drop_distance: float = 90.0
@export var max_inventory_slots: int = 10
@export var locked_sidearm_slot_index: int = 0
@export var duplicate_refill_fraction: float = 0.5

var owned_weapons: Array = []
var current_weapon_index: int = 0

var _owner_player: Node = null
var _owner_player_2d: Node2D = null
var _initialized: bool = false

var _shot_cooldown_left: float = 0.0
var _reload_time_left: float = 0.0


func _ready() -> void:
	if bullet_scene == null:
		bullet_scene = load("res://scenes/bullet.tscn") as PackedScene

	if not _initialized:
		var parent_node: Node = get_parent()

		if parent_node != null:
			initialize(parent_node)


func initialize(player_node: Node) -> void:
	if _initialized:
		return

	_owner_player = player_node
	_owner_player_2d = player_node as Node2D

	if not _restore_from_run_snapshot():
		_create_test_loadout()

	_initialized = true
	_print_current_weapon()


func _physics_process(delta: float) -> void:
	if not _initialized:
		return

	_update_timers(delta)
	_handle_drop_input()
	_handle_reload_input()
	_handle_shoot_input()


func _unhandled_input(event: InputEvent) -> void:
	if not _initialized:
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if key_event.pressed and not key_event.echo:
			var slot_index: int = _get_weapon_slot_from_key(key_event.keycode)

			if slot_index >= 0:
				_try_select_weapon_slot(slot_index)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if not mouse_event.pressed:
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_previous_usable_weapon()
			get_viewport().set_input_as_handled()
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_next_usable_weapon()
			get_viewport().set_input_as_handled()
			return


func _create_test_loadout() -> void:
	if owned_weapons.size() > 0:
		return

	max_inventory_slots = maxi(max_inventory_slots, 10)
	locked_sidearm_slot_index = clampi(locked_sidearm_slot_index, 0, max_inventory_slots - 1)

	owned_weapons.resize(max_inventory_slots)

	var weapon_data_script: Script = load("res://scripts/weapons/weapon_data.gd")
	var weapon_instance_script: Script = load("res://scripts/weapons/weapon_instance.gd")

	var negotiator_data = weapon_data_script.call("create_the_negotiator")
	var negotiator_instance = weapon_instance_script.new(negotiator_data)

	owned_weapons[locked_sidearm_slot_index] = negotiator_instance
	current_weapon_index = locked_sidearm_slot_index


func _update_timers(delta: float) -> void:
	if _shot_cooldown_left > 0.0:
		_shot_cooldown_left = maxf(_shot_cooldown_left - delta, 0.0)

	if _reload_time_left > 0.0:
		_reload_time_left = maxf(_reload_time_left - delta, 0.0)

		if _reload_time_left <= 0.0:
			_finish_reload()


func _handle_drop_input() -> void:
	if not InputMap.has_action("drop_weapon"):
		return

	if Input.is_action_just_pressed("drop_weapon"):
		_try_drop_current_weapon()


func _handle_reload_input() -> void:
	if not InputMap.has_action("reload"):
		return

	if Input.is_action_just_pressed("reload"):
		_try_start_reload()


func _handle_shoot_input() -> void:
	if not InputMap.has_action("shoot"):
		return

	var weapon = _get_current_weapon()

	if weapon == null:
		return

	var wants_to_shoot: bool = false

	match weapon.data.trigger_mode:
		"automatic":
			wants_to_shoot = Input.is_action_pressed("shoot")
		"semi_auto":
			wants_to_shoot = Input.is_action_just_pressed("shoot")
		_:
			wants_to_shoot = Input.is_action_just_pressed("shoot")

	if wants_to_shoot:
		_try_shoot()


func _try_shoot() -> void:
	var weapon = _get_current_weapon()

	if weapon == null:
		return

	if _reload_time_left > 0.0:
		return

	if not _player_can_fire_weapon():
		return

	if not weapon.data.can_be_used_by_scale(_get_player_trump_scale()):
		_switch_to_first_usable_weapon()
		return

	if _shot_cooldown_left > 0.0:
		return

	if not weapon.has_ammo_in_magazine():
		_try_start_reload()
		return

	var shoot_direction: Vector2 = _get_shoot_direction()

	_spawn_weapon_projectiles(weapon, shoot_direction)
	_apply_player_recoil(shoot_direction, weapon.data.recoil_force)
	_notify_owner_weapon_fired(weapon)

	weapon.consume_one_round()
	_shot_cooldown_left = 1.0 / maxf(weapon.data.fire_rate, 0.01)

	if not weapon.has_ammo_in_magazine() and weapon.can_reload():
		_try_start_reload()


func _try_start_reload() -> void:
	var weapon = _get_current_weapon()

	if weapon == null:
		return

	if _reload_time_left > 0.0:
		return

	if not _player_can_reload_weapon():
		return

	if not weapon.can_reload():
		return

	_reload_time_left = maxf(weapon.data.reload_time, 0.01)

	print("Reloading:", weapon.data.display_name)


func _finish_reload() -> void:
	var weapon = _get_current_weapon()

	if weapon == null:
		return

	weapon.reload_to_full()

	print("Reloaded:", weapon.data.display_name, "Ammo:", weapon.get_ammo_text())


func _spawn_weapon_projectiles(weapon, shoot_direction: Vector2) -> void:
	var bullet_parent: Node = _get_bullet_spawn_parent()
	var bullet_count: int = maxi(weapon.data.bullet_count, 1)

	for i in range(bullet_count):
		var projectile_direction: Vector2 = _get_projectile_direction(
			shoot_direction,
			i,
			bullet_count,
			weapon.data.spread_degrees
		)

		var bullet := bullet_scene.instantiate() as Area2D

		if bullet == null:
			continue

		if bullet.has_method("setup_bullet"):
			bullet.call("setup_bullet", false)

		if bullet.has_method("configure_projectile"):
			bullet.call(
				"configure_projectile",
				weapon.data.damage,
				weapon.data.bullet_speed,
				weapon.data.bullet_lifetime,
				weapon.data.bullet_radius,
				weapon.data.bullet_color
			)

		bullet.global_position = _get_muzzle_position(projectile_direction)
		bullet.set("direction", projectile_direction)

		bullet_parent.add_child(bullet)


func pickup_weapon_instance(weapon_instance, pickup_position: Vector2 = Vector2.ZERO) -> bool:
	if weapon_instance == null:
		return false

	if weapon_instance.data == null:
		return false

	var duplicate_weapon = _find_weapon_by_id(weapon_instance.data.id)

	if duplicate_weapon != null:
		var added_ammo: int = duplicate_weapon.add_reserve_ammo_by_fraction(duplicate_refill_fraction)

		if added_ammo <= 0:
			_show_action_message("%s ammo is already full." % duplicate_weapon.data.display_name)
			return false

		_show_action_message("%s duplicate: +%s reserve ammo." % [
			duplicate_weapon.data.display_name,
			str(added_ammo)
		])

		if weapon_instance.data.can_be_used_by_scale(_get_player_trump_scale()):
			current_weapon_index = _find_weapon_index(duplicate_weapon)
			_cancel_reload_and_shot_delay()
			_print_current_weapon()

		return true

	var free_slot_index: int = _get_first_free_weapon_slot_index()

	if free_slot_index >= 0:
		_add_new_weapon_to_inventory_slot(weapon_instance, free_slot_index)
		return true

	return _replace_current_weapon_with_pickup(weapon_instance, pickup_position)


func _add_new_weapon_to_inventory_slot(weapon_instance, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= max_inventory_slots:
		return

	owned_weapons[slot_index] = weapon_instance

	_show_action_message("Picked up %s." % weapon_instance.data.display_name)

	if weapon_instance.data.can_be_used_by_scale(_get_player_trump_scale()):
		current_weapon_index = slot_index
		_cancel_reload_and_shot_delay()
		_print_current_weapon()
	else:
		_show_action_message("Picked up %s, but it is too heavy for this Trump." % weapon_instance.data.display_name)


func _replace_current_weapon_with_pickup(weapon_instance, pickup_position: Vector2) -> bool:
	var current_weapon = _get_current_weapon()

	if current_weapon == null or current_weapon.data == null:
		_show_action_message("Inventory is full.")
		return false

	if not _can_current_weapon_be_replaced():
		_show_action_message("Cannot replace %s." % current_weapon.data.display_name)
		return false

	var dropped_weapon = current_weapon
	var dropped_name: String = dropped_weapon.data.display_name

	owned_weapons[current_weapon_index] = weapon_instance

	_cancel_reload_and_shot_delay()

	var drop_position := pickup_position

	if drop_position == Vector2.ZERO and _owner_player_2d != null:
		drop_position = _owner_player_2d.global_position

	_spawn_weapon_pickup_at(dropped_weapon, drop_position)

	if weapon_instance.data.can_be_used_by_scale(_get_player_trump_scale()):
		_print_current_weapon()
	else:
		_switch_to_first_usable_weapon()
		_show_action_message("Picked up %s, but it is too heavy for this Trump." % weapon_instance.data.display_name)

	_show_action_message("Replaced %s with %s." % [
		dropped_name,
		weapon_instance.data.display_name
	])

	return true


func pickup_ammo(ammo_type: String, refill_fraction: float, source_name: String = "Ammo") -> bool:
	var total_added: int = 0

	for weapon in owned_weapons:
		if weapon == null:
			continue

		if weapon.data == null:
			continue

		if weapon.data.infinite_reserve_ammo:
			continue

		if ammo_type != "universal" and weapon.data.ammo_type != ammo_type:
			continue

		var added_ammo: int = weapon.add_reserve_ammo_by_fraction(refill_fraction)

		if added_ammo > 0:
			total_added += added_ammo
			print("%s +%s reserve ammo -> %s" % [
				weapon.data.display_name,
				str(added_ammo),
				weapon.get_ammo_text()
			])

	if total_added <= 0:
		_show_action_message("%s: no compatible weapon needs ammo." % source_name)
		return false

	_show_action_message("Picked up %s. +%s ammo total." % [
		source_name,
		str(total_added)
	])

	return true


func get_pickup_hint_for_weapon(weapon_instance) -> String:
	if weapon_instance == null or weapon_instance.data == null:
		return ""

	var duplicate_weapon = _find_weapon_by_id(weapon_instance.data.id)

	if duplicate_weapon != null:
		var max_reserve: int = duplicate_weapon.get_max_reserve_ammo()

		if duplicate_weapon.data.infinite_reserve_ammo:
			return "[E] Pick up %s\nAlready owned. Infinite ammo weapon." % weapon_instance.data.display_name

		if max_reserve > 0 and duplicate_weapon.reserve_ammo >= max_reserve:
			return "[E] Pick up %s\nAlready owned. Reserve ammo is full." % weapon_instance.data.display_name

		return "[E] Pick up %s\nAlready owned: +50%% reserve ammo." % weapon_instance.data.display_name

	var free_slot_index: int = _get_first_free_weapon_slot_index()

	if free_slot_index >= 0:
		var description: String = weapon_instance.data.description

		if description.is_empty():
			return "[E] Pick up %s\nSlot %s." % [
				weapon_instance.data.display_name,
				_get_weapon_slot_label(free_slot_index)
			]

		return "[E] Pick up %s\n%s" % [
			weapon_instance.data.display_name,
			description
		]

	var current_weapon = _get_current_weapon()

	if current_weapon == null or current_weapon.data == null:
		return "Inventory full."

	if not _can_current_weapon_be_replaced():
		return "Inventory full.\nCannot replace %s." % current_weapon.data.display_name

	return "[E] Replace %s with %s\nInventory full." % [
		current_weapon.data.display_name,
		weapon_instance.data.display_name
	]


func _find_weapon_by_id(weapon_id: StringName):
	for weapon in owned_weapons:
		if weapon == null:
			continue

		if weapon.data == null:
			continue

		if weapon.data.id == weapon_id:
			return weapon

	return null


func _find_weapon_index(target_weapon) -> int:
	for i in range(owned_weapons.size()):
		if owned_weapons[i] == target_weapon:
			return i

	return -1


func _get_first_free_weapon_slot_index() -> int:
	for i in range(max_inventory_slots):
		if i == locked_sidearm_slot_index:
			continue

		if i >= owned_weapons.size():
			return -1

		if owned_weapons[i] == null:
			return i

	return -1


func _try_drop_current_weapon() -> void:
	var weapon = _get_current_weapon()

	if weapon == null:
		return

	if weapon.data == null:
		return

	if weapon.data.starter_weapon or not weapon.data.can_drop:
		_show_action_message("Cannot drop %s." % weapon.data.display_name)
		return

	var dropped_weapon = weapon
	var dropped_weapon_name: String = dropped_weapon.data.display_name

	owned_weapons[current_weapon_index] = null

	_cancel_reload_and_shot_delay()

	_spawn_weapon_pickup(dropped_weapon)

	_switch_to_first_usable_weapon()

	_show_action_message("Dropped %s." % dropped_weapon_name)


func _spawn_weapon_pickup(weapon_instance) -> void:
	_spawn_weapon_pickup_at(weapon_instance, _get_drop_position())


func _spawn_weapon_pickup_at(weapon_instance, spawn_position: Vector2) -> void:
	if weapon_instance == null:
		return

	var pickup_node := WEAPON_PICKUP_SCRIPT.new() as Area2D

	if pickup_node == null:
		return

	pickup_node.call("setup_weapon", weapon_instance)
	pickup_node.global_position = spawn_position

	var world_parent: Node = _get_world_parent()
	world_parent.add_child(pickup_node)


func _get_drop_position() -> Vector2:
	if _owner_player_2d == null:
		return Vector2.ZERO

	var direction: Vector2 = _owner_player_2d.get_global_mouse_position() - _owner_player_2d.global_position

	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT

	return _owner_player_2d.global_position + direction.normalized() * drop_distance


func _get_world_parent() -> Node:
	if _owner_player != null:
		var parent_node: Node = _owner_player.get_parent()

		if parent_node != null:
			return parent_node

	var current_scene: Node = get_tree().current_scene

	if current_scene != null:
		return current_scene

	return self


func _get_projectile_direction(
	base_direction: Vector2,
	projectile_index: int,
	projectile_count: int,
	spread_degrees: float
) -> Vector2:
	if projectile_count <= 1:
		if spread_degrees <= 0.0:
			return base_direction.normalized()

		var random_offset: float = deg_to_rad(randf_range(-spread_degrees * 0.5, spread_degrees * 0.5))
		return base_direction.rotated(random_offset).normalized()

	var spread_radians: float = deg_to_rad(spread_degrees)
	var t: float = float(projectile_index) / float(projectile_count - 1)
	var angle_offset: float = lerpf(-spread_radians * 0.5, spread_radians * 0.5, t)

	return base_direction.rotated(angle_offset).normalized()


func _get_shoot_direction() -> Vector2:
	if _owner_player_2d == null:
		return Vector2.RIGHT

	var shoot_vector: Vector2 = _owner_player_2d.get_global_mouse_position() - _owner_player_2d.global_position

	if shoot_vector.length_squared() < 0.0001:
		return Vector2.RIGHT

	return shoot_vector.normalized()


func _get_muzzle_position(shoot_direction: Vector2) -> Vector2:
	if _owner_player != null and _owner_player.has_method("get_weapon_muzzle_global_position"):
		var result: Variant = _owner_player.call("get_weapon_muzzle_global_position", shoot_direction)

		if result is Vector2:
			return result

	if _owner_player_2d != null:
		return _owner_player_2d.global_position

	return Vector2.ZERO


func _get_bullet_spawn_parent() -> Node:
	if _owner_player != null and _owner_player.has_method("get_bullet_spawn_parent"):
		var result: Variant = _owner_player.call("get_bullet_spawn_parent")

		if result is Node:
			return result

	var current_scene: Node = get_tree().current_scene

	if current_scene != null:
		return current_scene

	return self


func _player_can_fire_weapon() -> bool:
	if _owner_player != null and _owner_player.has_method("can_weapon_fire"):
		return bool(_owner_player.call("can_weapon_fire"))

	return true


func _player_can_reload_weapon() -> bool:
	if _owner_player != null and _owner_player.has_method("can_weapon_reload"):
		return bool(_owner_player.call("can_weapon_reload"))

	return true


func _get_player_trump_scale() -> float:
	if _owner_player != null and _owner_player.has_method("get_current_trump_scale"):
		return float(_owner_player.call("get_current_trump_scale"))

	return 1.0


func _apply_player_recoil(shoot_direction: Vector2, recoil_force: float) -> void:
	if _owner_player != null and _owner_player.has_method("apply_weapon_recoil"):
		_owner_player.call("apply_weapon_recoil", shoot_direction, recoil_force)


func _notify_owner_weapon_fired(weapon) -> void:
	if weapon == null or weapon.data == null:
		return

	if _owner_player != null and _owner_player.has_method("on_weapon_fired"):
		_owner_player.call("on_weapon_fired", weapon.data.id, weapon.data.recoil_force)


func on_trump_form_changed(new_trump_scale: float) -> void:
	var weapon = _get_current_weapon()

	if weapon == null:
		return

	if weapon.data.can_be_used_by_scale(new_trump_scale):
		return

	_switch_to_first_usable_weapon()


func _get_weapon_slot_from_key(keycode: Key) -> int:
	match keycode:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
		KEY_7:
			return 6
		KEY_8:
			return 7
		KEY_9:
			return 8
		KEY_0:
			return 9
		_:
			return -1


func _get_weapon_slot_label(slot_index: int) -> String:
	return str(slot_index + 1)


func _try_select_weapon_slot(slot_index: int) -> void:
	if slot_index < 0:
		return

	if slot_index >= max_inventory_slots:
		_show_action_message("Slot %s is unavailable." % _get_weapon_slot_label(slot_index))
		return

	if slot_index >= owned_weapons.size():
		_show_action_message("Slot %s is empty." % _get_weapon_slot_label(slot_index))
		return

	var weapon = owned_weapons[slot_index]

	if weapon == null:
		_show_action_message("Slot %s is empty." % _get_weapon_slot_label(slot_index))
		return

	if not weapon.data.can_be_used_by_scale(_get_player_trump_scale()):
		_show_action_message("%s is too heavy for this Trump." % weapon.data.display_name)
		return

	if current_weapon_index == slot_index:
		return

	current_weapon_index = slot_index
	_cancel_reload_and_shot_delay()

	_print_current_weapon()


func _select_next_usable_weapon() -> void:
	if _get_owned_weapon_count() <= 1:
		return

	var start_index: int = current_weapon_index
	var index: int = current_weapon_index

	for i in range(max_inventory_slots):
		index = (index + 1) % max_inventory_slots

		if _can_select_weapon_index(index):
			current_weapon_index = index
			_cancel_reload_and_shot_delay()
			_print_current_weapon()
			return

	current_weapon_index = start_index


func _select_previous_usable_weapon() -> void:
	if _get_owned_weapon_count() <= 1:
		return

	var start_index: int = current_weapon_index
	var index: int = current_weapon_index

	for i in range(max_inventory_slots):
		index -= 1

		if index < 0:
			index = max_inventory_slots - 1

		if _can_select_weapon_index(index):
			current_weapon_index = index
			_cancel_reload_and_shot_delay()
			_print_current_weapon()
			return

	current_weapon_index = start_index


func _can_select_weapon_index(index: int) -> bool:
	if index < 0 or index >= max_inventory_slots:
		return false

	if index >= owned_weapons.size():
		return false

	var weapon = owned_weapons[index]

	if weapon == null:
		return false

	return weapon.data.can_be_used_by_scale(_get_player_trump_scale())


func _switch_to_first_usable_weapon() -> void:
	var trump_scale: float = _get_player_trump_scale()

	for i in range(max_inventory_slots):
		if i >= owned_weapons.size():
			continue

		var weapon = owned_weapons[i]

		if weapon == null:
			continue

		if weapon.data.can_be_used_by_scale(trump_scale):
			current_weapon_index = i
			_cancel_reload_and_shot_delay()
			_print_current_weapon()
			return


func _can_current_weapon_be_replaced() -> bool:
	var weapon = _get_current_weapon()

	if weapon == null or weapon.data == null:
		return false

	if current_weapon_index == locked_sidearm_slot_index:
		return false

	if weapon.data.starter_weapon:
		return false

	if not weapon.data.can_drop:
		return false

	return true


func _cancel_reload_and_shot_delay() -> void:
	_reload_time_left = 0.0
	_shot_cooldown_left = 0.0


func _get_current_weapon():
	if owned_weapons.is_empty():
		return null

	if current_weapon_index < 0 or current_weapon_index >= max_inventory_slots:
		current_weapon_index = locked_sidearm_slot_index

	if current_weapon_index >= owned_weapons.size():
		_switch_to_first_usable_weapon()

	if current_weapon_index < 0 or current_weapon_index >= owned_weapons.size():
		return null

	var weapon = owned_weapons[current_weapon_index]

	if weapon == null:
		_switch_to_first_usable_weapon()

		if current_weapon_index < 0 or current_weapon_index >= owned_weapons.size():
			return null

		weapon = owned_weapons[current_weapon_index]

	return weapon


func _get_owned_weapon_count() -> int:
	var count: int = 0

	for weapon in owned_weapons:
		if weapon != null:
			count += 1

	return count


func get_current_weapon_name() -> String:
	var weapon = _get_current_weapon()

	if weapon == null:
		return "-"

	return weapon.data.display_name


func get_current_weapon_id() -> StringName:
	var weapon = _get_current_weapon()

	if weapon == null or weapon.data == null:
		return &""

	return weapon.data.id


func get_current_ammo_text() -> String:
	var weapon = _get_current_weapon()

	if weapon == null:
		return "-"

	return weapon.get_ammo_text()


func is_reloading() -> bool:
	return _reload_time_left > 0.0


func create_run_snapshot() -> Dictionary:
	return {
		"owned_weapons": owned_weapons.duplicate(),
		"current_weapon_index": current_weapon_index,
		"max_inventory_slots": max_inventory_slots,
		"locked_sidearm_slot_index": locked_sidearm_slot_index
	}


func restore_run_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return

	max_inventory_slots = maxi(int(snapshot.get("max_inventory_slots", max_inventory_slots)), 10)
	locked_sidearm_slot_index = clampi(
		int(snapshot.get("locked_sidearm_slot_index", locked_sidearm_slot_index)),
		0,
		max_inventory_slots - 1
	)
	current_weapon_index = int(snapshot.get("current_weapon_index", current_weapon_index))

	owned_weapons.clear()
	owned_weapons.assign(snapshot.get("owned_weapons", []))

	if owned_weapons.size() < max_inventory_slots:
		owned_weapons.resize(max_inventory_slots)

	current_weapon_index = clampi(current_weapon_index, 0, maxi(max_inventory_slots - 1, 0))
	_cancel_reload_and_shot_delay()


func _restore_from_run_snapshot() -> bool:
	if not RunManager.has_player_snapshot():
		return false

	var weapon_snapshot: Dictionary = RunManager.player_snapshot.get("weapon_controller", {})

	if weapon_snapshot.is_empty():
		return false

	restore_run_snapshot(weapon_snapshot)
	return true


func _show_action_message(message: String) -> void:
	print(message)

	var hud := get_tree().get_first_node_in_group("action_message_hud")

	if hud == null:
		return

	if hud.has_method("show_message"):
		hud.call("show_message", message)


func _print_current_weapon() -> void:
	var weapon = _get_current_weapon()

	if weapon == null:
		return

	print("Equipped weapon:", weapon.data.display_name)
	print("Description:", weapon.data.description)
	print("Ammo:", weapon.get_ammo_text())
