extends Resource
class_name WeaponData

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var weapon_type: String = "Sidearm"
@export var rarity: String = "Common"

@export_enum("semi_auto", "automatic") var trigger_mode: String = "semi_auto"
@export var fire_rate: float = 5.0

@export var damage: int = 1
@export var bullet_speed: float = 700.0
@export var bullet_lifetime: float = 1.2
@export var bullet_count: int = 1
@export var spread_degrees: float = 0.0
@export var bullet_radius: float = 4.0
@export var bullet_color: Color = Color(1.0, 0.9, 0.2)

@export var magazine_size: int = 12
@export var reserve_ammo: int = 0
@export var infinite_reserve_ammo: bool = false
@export var reload_time: float = 0.8

@export var recoil_force: float = 40.0
@export var min_trump_scale: float = 0.2

@export var can_drop: bool = true
@export var can_sell: bool = true
@export var starter_weapon: bool = false
@export var price: int = 0


func can_be_used_by_scale(trump_scale: float) -> bool:
	return trump_scale + 0.001 >= min_trump_scale


static func _create_empty_weapon_data():
	var script: Script = load("res://scripts/weapons/weapon_data.gd")
	return script.new()


static func create_the_negotiator():
	var data = _create_empty_weapon_data()

	data.id = &"the_negotiator"
	data.display_name = "The Negotiator"
	data.description = "When diplomacy fails, keep negotiating."
	data.weapon_type = "Sidearm"
	data.rarity = "Starter"

	data.trigger_mode = "semi_auto"
	data.fire_rate = 5.0

	data.damage = 1
	data.bullet_speed = 700.0
	data.bullet_lifetime = 1.2
	data.bullet_count = 1
	data.spread_degrees = 0.0
	data.bullet_radius = 4.0
	data.bullet_color = Color(1.0, 0.9, 0.2)

	data.magazine_size = 12
	data.reserve_ammo = 0
	data.infinite_reserve_ammo = true
	data.reload_time = 0.8

	data.recoil_force = 40.0
	data.min_trump_scale = 0.2

	data.can_drop = false
	data.can_sell = false
	data.starter_weapon = true
	data.price = 0

	return data


static func create_the_final_offer():
	var data = _create_empty_weapon_data()

	data.id = &"the_final_offer"
	data.display_name = "The Final Offer"
	data.description = "Usually comes with eight pellets."
	data.weapon_type = "Shotgun"
	data.rarity = "Uncommon"

	data.trigger_mode = "semi_auto"
	data.fire_rate = 1.15

	data.damage = 1
	data.bullet_speed = 650.0
	data.bullet_lifetime = 0.75
	data.bullet_count = 8
	data.spread_degrees = 32.0
	data.bullet_radius = 3.5
	data.bullet_color = Color(1.0, 0.55, 0.2)

	data.magazine_size = 8
	data.reserve_ammo = 24
	data.infinite_reserve_ammo = false
	data.reload_time = 1.35

	data.recoil_force = 260.0
	data.min_trump_scale = 0.6

	data.can_drop = true
	data.can_sell = true
	data.starter_weapon = false
	data.price = 80

	return data


static func create_the_second_amendment():
	var data = _create_empty_weapon_data()

	data.id = &"the_second_amendment"
	data.display_name = "The Second Amendment"
	data.description = "A constitutional argument at 900 rounds per minute."
	data.weapon_type = "Rifle"
	data.rarity = "Rare"

	data.trigger_mode = "automatic"
	data.fire_rate = 15.0

	data.damage = 1
	data.bullet_speed = 850.0
	data.bullet_lifetime = 1.1
	data.bullet_count = 1
	data.spread_degrees = 5.0
	data.bullet_radius = 3.5
	data.bullet_color = Color(0.85, 0.9, 1.0)

	data.magazine_size = 30
	data.reserve_ammo = 90
	data.infinite_reserve_ammo = false
	data.reload_time = 1.45

	data.recoil_force = 65.0
	data.min_trump_scale = 0.6

	data.can_drop = true
	data.can_sell = true
	data.starter_weapon = false
	data.price = 120

	return data
