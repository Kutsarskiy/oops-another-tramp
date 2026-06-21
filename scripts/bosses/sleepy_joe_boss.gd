extends "res://scripts/bosses/test_boss.gd"

const PaperStateSpriteScript: Script = preload("res://scripts/visuals/paper_state_sprite.gd")

@export var paper_state_texture_paths: Dictionary = {
	&"idle": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_right_idle.png",
	&"shoot": "res://assets/characters/bosses/sleepy_joe/paper/sleepy_joe_right_shoot.png"
}
@export var shoot_state_duration: float = 0.16

@onready var sleepy_sprite: Sprite2D = $Sprite2D

var _paper_visual = PaperStateSpriteScript.new()
var _shoot_state_left: float = 0.0


func _ready() -> void:
	boss_id = "sleepy_joe"
	boss_name = "Sleepy Joe"
	boss_max_hp = 140.0
	move_speed = 80.0

	_paper_visual.setup(sleepy_sprite, paper_state_texture_paths)
	super()
	_update_paper_visual()


func _physics_process(delta: float) -> void:
	_shoot_state_left = maxf(_shoot_state_left - delta, 0.0)
	_update_paper_visual()
	super(delta)


func on_attack_shot() -> void:
	_shoot_state_left = shoot_state_duration
	_update_paper_visual()


func _update_paper_visual() -> void:
	if sleepy_sprite == null:
		return

	if _shoot_state_left > 0.0 and _paper_visual.has_state(&"shoot"):
		_paper_visual.set_state(&"shoot")
	else:
		_paper_visual.set_state(&"idle")

	if player != null and is_instance_valid(player):
		_paper_visual.face_target(global_position, player.global_position)
