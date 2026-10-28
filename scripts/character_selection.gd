extends Node

# Shared child of BodyTemplate, so Player, Leader, Friend, and NPC inherit it.
# This is only selection feedback; it does not accuse or change round results.
@export var outline_color: Color = Color.WHITE
@export_range(1.0, 6.0, 0.5) var outline_width: float = 2.0

const OUTLINE = preload("res://shaders/selection_outline.gdshader")
const SELECTION_GROUP: StringName = &"character_selection"

var selected: bool = false
var _sprites: Array[Sprite2D] = []
var _original_materials: Array[Material] = []
var _outline_material: ShaderMaterial


func _ready() -> void:
	add_to_group(SELECTION_GROUP)
	set_process(false)
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE
	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("outline_width", outline_width)
	for path in ["Body", "LeftArmPivot/LeftHand", "RightArmPivot/RightHand", "Pointing/PointHand"]:
		var sprite := get_parent().get_node_or_null(path) as Sprite2D
		if sprite != null:
			_sprites.append(sprite)
			_original_materials.append(sprite.material)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"point") or not event is InputEventMouseButton:
		return
	if not _can_select():
		return
	if hit_character(event.position):
		# Keep selection local to this viewport; offscreen icon previews are separate.
		for other in get_tree().get_nodes_in_group(SELECTION_GROUP):
			if other != self and other.get_viewport() == get_viewport():
				other.set_selected(false)
		set_selected(true)
	else:
		set_selected(false)
	# Leave the click available for the player's existing pointing tween.


func set_selected(value: bool) -> void:
	selected = value
	for index in _sprites.size():
		_sprites[index].material = _outline_material if selected else _original_materials[index]
	set_process(selected)


func _process(_delta: float) -> void:
	# Drop the highlight if a gesture or response phase disables mouse pointing.
	if not _can_select():
		set_selected(false)


func _can_select() -> bool:
	# The player can point at other characters, never at themselves.
	if get_parent().is_in_group(&"Player"):
		return false
	for player in get_tree().get_nodes_in_group(&"Player"):
		if player.get_viewport() == get_viewport():
			return not player.rhythm_input_enabled and not player._gesture_locked
	return true


func hit_character(viewport_position: Vector2) -> bool:
	for sprite in _sprites:
		if not sprite.is_visible_in_tree() or sprite.texture == null:
			continue
		var local_point := sprite.get_global_transform_with_canvas().affine_inverse() * viewport_position
		# Test the visible pixels, rather than the transparent corners of the sprite.
		if sprite.get_rect().has_point(local_point) and sprite.is_pixel_opaque(local_point):
			return true
	return false
