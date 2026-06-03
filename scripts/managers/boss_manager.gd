extends Node

enum BossState {
	IDLE,
	SPAWNING,
	ACTIVE,
	PHASE_TRANSITION,
	DEFEATED
}

signal encounter_started
signal encounter_completed

signal boss_spawned(boss)
signal boss_phase_changed(phase)
signal boss_defeated(boss)

var boss_state: BossState = BossState.IDLE

var encounter: BossEncounter = BossEncounter.new()


func start_encounter() -> void:

	encounter = BossEncounter.new()

	boss_state = BossState.ACTIVE

	encounter_started.emit()

	RunManager.set_run_state(
		RunManager.RunState.BOSS_FIGHT
	)


func register_main_boss(boss: BaseBoss) -> void:

	encounter.add_main_boss(boss)

	boss.phase_changed.connect(_on_phase_changed)

	boss.boss_defeated.connect(
		func():
			_on_main_boss_defeated(boss)
	)

	boss_spawned.emit(boss)


func register_mini_boss(boss: BaseBoss) -> void:

	encounter.add_mini_boss(boss)

	boss.phase_changed.connect(_on_phase_changed)

	boss.boss_defeated.connect(
		func():
			_on_mini_boss_defeated(boss)
	)


func register_boss_object(obj) -> void:

	encounter.add_boss_object(obj)


func _on_phase_changed(new_phase: int) -> void:

	boss_state = BossState.PHASE_TRANSITION

	boss_phase_changed.emit(new_phase)

	boss_state = BossState.ACTIVE


func _on_main_boss_defeated(boss: BaseBoss) -> void:

	encounter.remove_main_boss(boss)

	boss_defeated.emit(boss)

	if encounter.is_completed():

		boss_state = BossState.DEFEATED

		RunManager.set_run_state(
			RunManager.RunState.BOSS_DEFEATED
		)

		encounter_completed.emit()


func _on_mini_boss_defeated(boss: BaseBoss) -> void:

	encounter.remove_mini_boss(boss)

	boss_defeated.emit(boss)
	
