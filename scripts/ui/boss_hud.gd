extends Control

@onready var boss_name_label: Label = $MarginContainer/VBoxContainer/BossName
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/BossHP
@onready var phase_label: Label = $MarginContainer/VBoxContainer/PhaseLabel


func _ready() -> void:

	hide()

	BossManager.boss_spawned.connect(_on_boss_spawned)
	BossManager.boss_phase_changed.connect(_on_phase_changed)
	BossManager.boss_defeated.connect(_on_boss_defeated)


func _on_boss_spawned(boss: BaseBoss) -> void:

	show()

	boss_name_label.text = boss.boss_name

	hp_bar.max_value = boss.max_hp
	hp_bar.value = boss.current_hp

	phase_label.text = "Phase " + str(boss.current_phase)

	if boss.has_signal("boss_damaged"):
		boss.boss_damaged.connect(_on_boss_damaged)


func _on_boss_damaged(current_hp: float) -> void:

	hp_bar.value = current_hp


func _on_phase_changed(new_phase: int) -> void:

	phase_label.text = "Phase " + str(new_phase)


func _on_boss_defeated(_boss) -> void:

	hide()
