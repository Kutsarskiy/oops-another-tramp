extends RefCounted
class_name WeaponInstance

var data: WeaponData
var ammo_in_magazine: int = 0
var reserve_ammo: int = 0


func _init(weapon_data: WeaponData = null) -> void:
	data = weapon_data

	if data != null:
		ammo_in_magazine = data.magazine_size
		reserve_ammo = maxi(data.reserve_ammo, 0)


func has_ammo_in_magazine() -> bool:
	return ammo_in_magazine > 0


func is_magazine_full() -> bool:
	if data == null:
		return true

	return ammo_in_magazine >= data.magazine_size


func consume_one_round() -> void:
	ammo_in_magazine = maxi(ammo_in_magazine - 1, 0)


func can_reload() -> bool:
	if data == null:
		return false

	if data.magazine_size <= 0:
		return false

	if is_magazine_full():
		return false

	if data.infinite_reserve_ammo:
		return true

	return reserve_ammo > 0


func reload_to_full() -> void:
	if data == null:
		return

	if data.magazine_size <= 0:
		return

	var needed_ammo: int = data.magazine_size - ammo_in_magazine

	if needed_ammo <= 0:
		return

	if data.infinite_reserve_ammo:
		ammo_in_magazine = data.magazine_size
		return

	var loaded_ammo: int = mini(needed_ammo, reserve_ammo)
	ammo_in_magazine += loaded_ammo
	reserve_ammo -= loaded_ammo


func get_max_reserve_ammo() -> int:
	if data == null:
		return 0

	if data.max_reserve_ammo > 0:
		return data.max_reserve_ammo

	return maxi(data.reserve_ammo, 0)


func add_reserve_ammo(amount: int) -> int:
	if data == null:
		return 0

	if data.infinite_reserve_ammo:
		return 0

	var max_reserve: int = get_max_reserve_ammo()

	if max_reserve <= 0:
		return 0

	var safe_amount: int = maxi(amount, 0)

	if safe_amount <= 0:
		return 0

	var old_reserve: int = reserve_ammo
	reserve_ammo = mini(reserve_ammo + safe_amount, max_reserve)

	return reserve_ammo - old_reserve


func add_reserve_ammo_by_fraction(fraction: float) -> int:
	var max_reserve: int = get_max_reserve_ammo()

	if max_reserve <= 0:
		return 0

	var amount: int = int(ceil(float(max_reserve) * fraction))
	amount = maxi(amount, 1)

	return add_reserve_ammo(amount)


func get_ammo_text() -> String:
	if data == null:
		return "-"

	if data.infinite_reserve_ammo:
		return "%s / ∞" % str(ammo_in_magazine)

	return "%s / %s" % [str(ammo_in_magazine), str(reserve_ammo)]
