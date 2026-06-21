extends RefCounted
class_name PaperStateSprite

const DEFAULT_STATE: StringName = &"idle"

var _sprite: Sprite2D = null
var _textures: Dictionary = {}
var _current_state: StringName = DEFAULT_STATE


func setup(sprite: Sprite2D, state_texture_paths: Dictionary) -> void:
	_sprite = sprite
	_textures.clear()

	if _sprite != null:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for state in state_texture_paths.keys():
		var texture := _load_texture_or_null(str(state_texture_paths[state]))

		if texture != null:
			_textures[StringName(str(state))] = texture

	set_state(DEFAULT_STATE)


func set_state(state: StringName) -> void:
	if _sprite == null:
		return

	var texture := _get_texture_for_state(state)

	if texture == null:
		return

	_current_state = state if _textures.has(state) else DEFAULT_STATE
	_sprite.texture = texture


func face_target(owner_position: Vector2, target_position: Vector2) -> void:
	if _sprite == null:
		return

	_sprite.flip_h = target_position.x < owner_position.x


func face_direction(direction: Vector2) -> void:
	if _sprite == null:
		return

	if absf(direction.x) <= 0.001:
		return

	_sprite.flip_h = direction.x < 0.0


func get_current_state() -> StringName:
	return _current_state


func has_state(state: StringName) -> bool:
	return _textures.has(state)


func _get_texture_for_state(state: StringName) -> Texture2D:
	var texture: Texture2D = _textures.get(state, null)

	if texture != null:
		return texture

	return _textures.get(DEFAULT_STATE, null)


func _load_texture_or_null(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if ResourceLoader.exists(path):
		var resource := load(path)

		if resource is Texture2D:
			return resource as Texture2D

	var image := Image.new()
	var error := image.load(path)

	if error != OK:
		push_warning("Paper texture failed to load: %s" % path)
		return null

	return ImageTexture.create_from_image(image)
