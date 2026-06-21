extends Node
class_name BossDatabase


static func get_boss_data(boss_id: String) -> Dictionary:
	var bosses := {
		"test_boss": {
			"display_name": "Test Boss",
			"scene": preload("res://scenes/bosses/test_boss.tscn"),
			"circle_id": 0
		},
		"sleepy_joe": {
			"display_name": "Sleepy Joe",
			"scene": preload("res://scenes/bosses/sleepy_joe.tscn"),
			"circle_id": 1
		},
		"techno_king": {
			"display_name": "The Techno-King",
			"scene": preload("res://scenes/bosses/techno_king.tscn"),
			"circle_id": 2
		},
		"madam_firewall": {
			"display_name": "Madam Firewall",
			"scene": preload("res://scenes/bosses/madam_firewall.tscn"),
			"circle_id": 3
		},
		"xi_jinping": {
			"display_name": "Xi Jinping, The Supreme Auditor",
			"scene": preload("res://scenes/bosses/xi_jinping.tscn"),
			"circle_id": 4
		},
		"boris_johnson": {
			"display_name": "Boris Johnson, The Minister of Chaos",
			"scene": preload("res://scenes/bosses/boris_johnson.tscn"),
			"circle_id": 5
		},
		"mark_zuckerberg": {
			"display_name": "Mark Zuckerberg",
			"scene": preload("res://scenes/bosses/mark_zuckerberg.tscn"),
			"circle_id": 6
		},
		"general_rocket": {
			"display_name": "Kim Jong Un, General Rocket",
			"scene": preload("res://scenes/bosses/general_rocket.tscn"),
			"circle_id": 7
		},
		"vladimir_putin": {
			"display_name": "Vladimir Putin",
			"scene": preload("res://scenes/bosses/vladimir_putin.tscn"),
			"circle_id": 8
		},
		"jd_vance": {
			"display_name": "JD Vance",
			"scene": preload("res://scenes/bosses/jd_vance.tscn"),
			"circle_id": 9
		},
		"prime_tramp": {
			"display_name": "Prime Tramp",
			"scene": preload("res://scenes/bosses/prime_tramp.tscn"),
			"circle_id": 10
		}
	}

	return bosses.get(boss_id, {})


static func get_boss_scene(boss_id: String) -> PackedScene:
	var data := get_boss_data(boss_id)

	if data.is_empty():
		return null

	return data.get("scene", null)


static func get_boss_display_name(boss_id: String) -> String:
	var data := get_boss_data(boss_id)

	if data.is_empty():
		return boss_id

	return data.get("display_name", boss_id)


static func has_boss(boss_id: String) -> bool:
	return not get_boss_data(boss_id).is_empty()


static func get_known_boss_ids() -> Array[String]:
	return [
		"sleepy_joe",
		"techno_king",
		"madam_firewall",
		"xi_jinping",
		"boris_johnson",
		"mark_zuckerberg",
		"general_rocket",
		"vladimir_putin",
		"jd_vance",
		"prime_tramp"
	]
