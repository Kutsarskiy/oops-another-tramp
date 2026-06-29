extends Label


var _player: Node = null


func _ready() -> void:
	text = "INVINCIBLE"
	visible = false
	set_process(OS.is_debug_build())


func _process(_delta: float) -> void:
	if not OS.is_debug_build():
		visible = false
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if _player == null:
		visible = false
		return

	if _player.has_method("is_debug_hurtbox_disabled"):
		visible = bool(_player.call("is_debug_hurtbox_disabled"))
	else:
		visible = bool(_player.get("_debug_hurtbox_disabled"))
