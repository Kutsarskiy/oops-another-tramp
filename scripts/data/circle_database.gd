extends RefCounted
class_name CircleDatabase


static func get_circle_data(circle_id: int) -> Dictionary:

	var circles := {
		1: {
			"name": "First Circle",
			"boss_id": "sleepy_joe",
			"boss_scene": null
		},

		2: {
			"name": "Second Circle",
			"boss_id": "techno_king",
			"boss_scene": null
		},

		3: {
			"name": "Third Circle",
			"boss_id": "madam_firewall",
			"boss_scene": null
		},

		4: {
			"name": "Fourth Circle",
			"boss_id": "xi_jinping",
			"boss_scene": null
		},

		5: {
			"name": "Fifth Circle",
			"boss_id": "boris_johnson",
			"boss_scene": null
		}
	}

	return circles.get(circle_id, {})
