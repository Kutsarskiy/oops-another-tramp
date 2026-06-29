extends RefCounted
class_name CircleDatabase


static func get_test_room_scene() -> PackedScene:
	return preload("res://scenes/arenas/test_room.tscn")


static func get_circle_count() -> int:
	return 10


static func get_circle_data(circle_id: int) -> Dictionary:

	var circles := {
		1: {
			"name": "First Circle",
			"boss_id": "sleepy_joe",
			"arena_scene": preload("res://scenes/arenas/arena_01_sleepy_joe.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.31, 0.34, 0.33),
			"arena_size": Vector2(1400, 1400),
			"boss_spawn_position": Vector2(0, -345),
			"reward_spawn_position": Vector2(0, 180),
			"exit_spawn_position": Vector2(0, 560)
		},

		2: {
			"name": "Second Circle",
			"boss_id": "techno_king",
			"arena_scene": preload("res://scenes/arenas/arena_02_techno_king.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.20, 0.32, 0.40),
			"arena_size": Vector2(2320, 1840),
			"boss_spawn_position": Vector2(0, 0),
			"reward_spawn_position": Vector2(0, 160),
			"exit_spawn_position": Vector2(0, -760)
		},

		3: {
			"name": "Third Circle",
			"boss_id": "madam_firewall",
			"arena_scene": preload("res://scenes/arenas/arena_03_madam_firewall.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.45, 0.25, 0.34),
			"arena_size": Vector2(1960, 2320),
			"boss_spawn_position": Vector2(0, 0),
			"reward_spawn_position": Vector2(0, 160),
			"exit_spawn_position": Vector2(0, -760)
		},

		4: {
			"name": "Fourth Circle",
			"boss_id": "xi_jinping",
			"arena_scene": preload("res://scenes/arenas/arena_04_xi_jinping.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.45, 0.34, 0.25),
			"arena_size": Vector2(2440, 2040),
			"boss_spawn_position": Vector2(0, 0),
			"reward_spawn_position": Vector2(0, 160),
			"exit_spawn_position": Vector2(0, -760)
		},

		5: {
			"name": "Fifth Circle",
			"boss_id": "boris_johnson",
			"arena_scene": preload("res://scenes/arenas/arena_05_boris_johnson.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.32, 0.36, 0.50),
			"arena_size": Vector2(2600, 1740),
			"boss_spawn_position": Vector2(0, 0),
			"reward_spawn_position": Vector2(0, 160),
			"exit_spawn_position": Vector2(0, -760)
		},

		6: {
			"name": "Sixth Circle",
			"boss_id": "mark_zuckerberg",
			"arena_scene": preload("res://scenes/arenas/arena_06_mark_zuckerberg.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.22, 0.42, 0.46),
			"arena_size": Vector2(2240, 2240),
			"boss_spawn_position": Vector2(0, 0),
			"reward_spawn_position": Vector2(0, 160),
			"exit_spawn_position": Vector2(0, -760)
		},

		7: {
			"name": "Seventh Circle",
			"boss_id": "general_rocket",
			"arena_scene": preload("res://scenes/arenas/arena_07_general_rocket.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.38, 0.24, 0.24),
			"arena_size": Vector2(2040, 2040),
			"boss_spawn_position": Vector2(0, 0),
			"reward_spawn_position": Vector2(0, 160),
			"exit_spawn_position": Vector2(0, -760)
		},

		8: {
			"name": "Eighth Circle",
			"boss_id": "vladimir_putin",
			"arena_scene": preload("res://scenes/arenas/arena_08_vladimir_putin.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.25, 0.35, 0.45),
			"arena_size": Vector2(2360, 2360),
			"boss_spawn_position": Vector2(0, 0),
			"reward_spawn_position": Vector2(0, 160),
			"exit_spawn_position": Vector2(0, -760)
		},

		9: {
			"name": "Ninth Circle",
			"boss_id": "jd_vance",
			"arena_scene": preload("res://scenes/arenas/arena_09_jd_vance.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.40, 0.38, 0.26),
			"arena_size": Vector2(2160, 2480),
			"boss_spawn_position": Vector2(0, 0),
			"reward_spawn_position": Vector2(0, 160),
			"exit_spawn_position": Vector2(0, -760)
		},

		10: {
			"name": "Final Circle",
			"boss_id": "prime_tramp",
			"arena_scene": preload("res://scenes/arenas/arena_10_prime_tramp.tscn"),
			"boss_scene": null,
			"arena_color": Color(0.48, 0.20, 0.20),
			"arena_size": Vector2(2800, 2200),
			"boss_spawn_position": Vector2(0, 0),
			"reward_spawn_position": Vector2(0, 160),
			"exit_spawn_position": Vector2(0, -760)
		}
	}

	return circles.get(circle_id, {})
