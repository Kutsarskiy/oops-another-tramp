extends Control

@onready var boss_name_label: Label = $MarginContainer/VBoxContainer/BossName
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/BossHP
@onready var mini_boss_bars: VBoxContainer = $MarginContainer/VBoxContainer/MiniBossBars
@onready var agent_a_row: HBoxContainer = $MarginContainer/VBoxContainer/MiniBossBars/AgentARow
@onready var agent_b_row: HBoxContainer = $MarginContainer/VBoxContainer/MiniBossBars/AgentBRow
@onready var agent_a_bar: ProgressBar = $MarginContainer/VBoxContainer/MiniBossBars/AgentARow/Bar
@onready var agent_b_bar: ProgressBar = $MarginContainer/VBoxContainer/MiniBossBars/AgentBRow/Bar
@onready var phase_label: Label = $MarginContainer/VBoxContainer/PhaseLabel

var _agent_bars: Dictionary = {}
var _mini_boss_bind_attempts: int = 0


func _ready() -> void:

	hide()
	_agent_bars = {
		"Agent A": agent_a_bar,
		"Agent B": agent_b_bar
	}
	_reset_mini_boss_bars()

	BossManager.boss_spawned.connect(_on_boss_spawned)
	BossManager.boss_phase_changed.connect(_on_phase_changed)
	BossManager.boss_defeated.connect(_on_boss_defeated)


func _on_boss_spawned(boss: BaseBoss) -> void:

	show()

	boss_name_label.text = boss.boss_name

	hp_bar.max_value = boss.max_hp
	hp_bar.value = boss.current_hp

	phase_label.text = "Phase " + str(boss.current_phase)
	_reset_mini_boss_bars()

	if boss.has_signal("boss_damaged"):
		boss.boss_damaged.connect(_on_boss_damaged)


func _on_boss_damaged(current_hp: float) -> void:

	hp_bar.value = current_hp


func _on_phase_changed(new_phase: int) -> void:

	phase_label.text = "Phase " + str(new_phase)

	if new_phase == 2:
		_mini_boss_bind_attempts = 0
		call_deferred("_bind_mini_bosses_with_retry")


func _on_boss_defeated(_boss) -> void:

	_reset_mini_boss_bars()
	hide()


func _bind_mini_bosses() -> void:
	_reset_mini_boss_bars()

	for node in get_tree().get_nodes_in_group("sleepy_joe_agent"):
		if not node.has_method("take_damage"):
			continue

		var agent_name := str(node.get("agent_name"))
		var bar: ProgressBar = _agent_bars.get(agent_name, null)

		if bar == null:
			continue

		bar.max_value = float(node.get("max_hp"))
		bar.value = float(node.get("current_hp"))
		_set_agent_row_visible(agent_name, true)
		mini_boss_bars.visible = true

		if node.has_signal("health_changed") and not node.health_changed.is_connected(_on_agent_health_changed):
			node.health_changed.connect(_on_agent_health_changed)
		if node.has_signal("agent_died") and not node.agent_died.is_connected(_on_agent_died):
			node.agent_died.connect(_on_agent_died)


func _bind_mini_bosses_with_retry() -> void:
	_bind_mini_bosses()

	if mini_boss_bars.visible:
		return

	_mini_boss_bind_attempts += 1

	if _mini_boss_bind_attempts >= 8:
		return

	var timer := get_tree().create_timer(0.05)
	timer.timeout.connect(_bind_mini_bosses_with_retry)


func _on_agent_health_changed(agent_name: String, current_hp: float, max_hp: float) -> void:
	var bar: ProgressBar = _agent_bars.get(agent_name, null)

	if bar == null:
		return

	bar.max_value = max_hp
	bar.value = current_hp
	_set_agent_row_visible(agent_name, current_hp > 0.0)
	mini_boss_bars.visible = agent_a_row.visible or agent_b_row.visible


func _on_agent_died(agent_name: String) -> void:
	var bar: ProgressBar = _agent_bars.get(agent_name, null)

	if bar != null:
		_set_agent_row_visible(agent_name, false)

	mini_boss_bars.visible = agent_a_row.visible or agent_b_row.visible


func _reset_mini_boss_bars() -> void:
	mini_boss_bars.visible = false

	agent_a_row.visible = false
	agent_b_row.visible = false

	for bar in [agent_a_bar, agent_b_bar]:
		bar.visible = false
		bar.max_value = 1.0
		bar.value = 0.0


func _set_agent_row_visible(agent_name: String, is_visible: bool) -> void:
	match agent_name:
		"Agent A":
			agent_a_row.visible = is_visible
			agent_a_bar.visible = is_visible
		"Agent B":
			agent_b_row.visible = is_visible
			agent_b_bar.visible = is_visible
