@tool
extends Node

# Stores each character's own textures and applies them in the editor and game.
# AnimationPlayer changes hand_pose; scoring changes face_expression.

@export var body_sprite: Texture2D:
	set(value):
		body_sprite = value
		_queue_refresh()
@export var face_sprite: Texture2D:
	set(value):
		face_sprite = value
		_queue_refresh()
# No automatic pointing-count selection yet. Level 2 also supplies mistake feedback.
@export var sadfacelevel1_sprite: Texture2D:
	set(value):
		sadfacelevel1_sprite = value
		_queue_refresh()
@export var sadfacelevel2_sprite: Texture2D:
	set(value):
		sadfacelevel2_sprite = value
		_queue_refresh()
@export var sadfacelevel3_sprite: Texture2D:
	set(value):
		sadfacelevel3_sprite = value
		_queue_refresh()
@export var sadfacelevel4_sprite: Texture2D:
	set(value):
		sadfacelevel4_sprite = value
		_queue_refresh()
@export var happyface_sprite: Texture2D:
	set(value):
		happyface_sprite = value
		_queue_refresh()
@export var angryface_sprite: Texture2D:
	set(value):
		angryface_sprite = value
		_queue_refresh()
@export var wavehand_sprite: Texture2D:
	set(value):
		wavehand_sprite = value
		_queue_refresh()
@export var pointhand_sprite: Texture2D:
	set(value):
		pointhand_sprite = value
		_queue_refresh()
@export var peacehand_sprite: Texture2D:
	set(value):
		peacehand_sprite = value
		_queue_refresh()
@export var rocknrollhand_sprite: Texture2D:
	set(value):
		rocknrollhand_sprite = value
		_queue_refresh()
@export var thumbsuphand_sprite: Texture2D:
	set(value):
		thumbsuphand_sprite = value
		_queue_refresh()
@export var fisthand_sprite: Texture2D:
	set(value):
		fisthand_sprite = value
		_queue_refresh()

@export_enum("wave", "point", "peace", "rock", "thumbs_up", "fist") var hand_pose: String = "wave":
	set(value):
		hand_pose = value
		# Property tracks also invoke this setter when previewed in the editor.
		if is_inside_tree():
			_apply_hand_texture()

@export_enum("default", "happy", "angry", "sad_level_2") var face_expression: String = "default":
	set(value):
		face_expression = value
		if is_inside_tree():
			_apply_face_texture()

# Coalesces Inspector edits into one refresh after all sibling nodes exist.
var _refresh_queued: bool = false


func _ready() -> void:
	_refresh_appearance()


func _queue_refresh() -> void:
	# Export setters can run before the node or its siblings enter the tree.
	if not is_inside_tree() or _refresh_queued:
		return
	_refresh_queued = true
	_refresh_appearance.call_deferred()


func _refresh_appearance() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	_apply_texture(^"../Body", body_sprite)
	_apply_face_texture()
	_apply_texture(^"../Pointing/PointHand", pointhand_sprite)
	_apply_hand_texture()


func set_hand_pose(pose: StringName) -> void:
	hand_pose = String(pose)


# Changes only the displayed expression; the normal face_sprite stays intact.
func set_face_expression(expression: StringName) -> void:
	face_expression = String(expression)


func _apply_face_texture() -> void:
	var texture := face_sprite
	match face_expression:
		"happy":
			if happyface_sprite != null:
				texture = happyface_sprite
		"angry":
			if angryface_sprite != null:
				texture = angryface_sprite
		"sad_level_2":
			if sadfacelevel2_sprite != null:
				texture = sadfacelevel2_sprite
	_apply_texture(^"../Face", texture)


# Both hands use the same pose texture, with their existing flips and rotations.
func _apply_hand_texture() -> void:
	var textures := {
		"wave": wavehand_sprite,
		"open": wavehand_sprite,
		"point": pointhand_sprite,
		"peace": peacehand_sprite,
		"rock": rocknrollhand_sprite,
		"thumbs_up": thumbsuphand_sprite,
		"fist": fisthand_sprite,
	}
	var texture: Texture2D = textures.get(hand_pose, wavehand_sprite)
	_apply_texture(^"../LeftArmPivot/LeftHand", texture)
	_apply_texture(^"../RightArmPivot/RightHand", texture)
	if hand_pose == "point":
		_apply_texture(^"../Pointing/PointHand", texture)


func _apply_texture(path: NodePath, texture: Texture2D) -> void:
	# Inspector setters may run while the scene is still being constructed.
	var sprite := get_node_or_null(path) as Sprite2D
	if sprite != null:
		sprite.texture = texture
