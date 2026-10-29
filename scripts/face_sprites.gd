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
# Player pressure uses these levels; level 2 also supplies brief mistake feedback.
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
@export var smileface_sprite: Texture2D:
	set(value):
		smileface_sprite = value
		_queue_refresh()
@export var happyface_sprite: Texture2D:
	set(value):
		happyface_sprite = value
		_queue_refresh()
@export var angryface_sprite: Texture2D:
	set(value):
		angryface_sprite = value
		_queue_refresh()
@export var smugface_sprite: Texture2D:
	set(value):
		smugface_sprite = value
		_queue_refresh()
@export var smugface2_sprite: Texture2D:
	set(value):
		smugface2_sprite = value
		_queue_refresh()
@export var smugface3_sprite: Texture2D:
	set(value):
		smugface3_sprite = value
		_queue_refresh()
@export var evilface_sprite: Texture2D:
	set(value):
		evilface_sprite = value
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

@export_group("Ally")
# The look this character switches to when they become the player's ally.
# Leave a slot empty to keep that texture as it is.
@export var ally_body_sprite: Texture2D
# Default (resting) face once they're an ally, so they stop looking hostile.
@export var ally_face_sprite: Texture2D
@export var ally_wavehand_sprite: Texture2D
@export var ally_pointhand_sprite: Texture2D
@export var ally_peacehand_sprite: Texture2D
@export var ally_rocknrollhand_sprite: Texture2D
@export var ally_thumbsuphand_sprite: Texture2D
@export var ally_fisthand_sprite: Texture2D
@export_group("")

var is_ally: bool = false

@export_enum("wave", "point", "peace", "rock", "thumbs_up", "fist") var hand_pose: String = "wave":
	set(value):
		hand_pose = value
		# Property tracks also invoke this setter when previewed in the editor.
		if is_inside_tree():
			_apply_hand_texture()

@export_enum("default", "happy", "angry", "smile", "sad_level_1", "sad_level_2", "sad_level_3", "sad_level_4", "smug", "smug_2", "smug_3", "evil") var face_expression: String = "default":
	set(value):
		face_expression = value
		if is_inside_tree():
			_apply_face_texture()

# Coalesces Inspector edits into one refresh after all sibling nodes exist.
var _refresh_queued: bool = false
# The face used by "default" can change without replacing the normal face asset.
var default_face_expression: StringName = &"default"


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


func set_default_face_expression(expression: StringName) -> void:
	# Active happy/shocked/dialogue expressions remain visible until they reset.
	default_face_expression = expression
	if is_inside_tree():
		_apply_face_texture()


func _apply_face_texture() -> void:
	# Every assigned face alternative is available to both dialogue and the editor.
	var textures := {
		"default": face_sprite,
		"happy": happyface_sprite,
		"angry": angryface_sprite,
		"smile": smileface_sprite,
		"sad_level_1": sadfacelevel1_sprite,
		"sad_level_2": sadfacelevel2_sprite,
		"sad_level_3": sadfacelevel3_sprite,
		"sad_level_4": sadfacelevel4_sprite,
		"smug": smugface_sprite,
		"smug_2": smugface2_sprite,
		"smug_3": smugface3_sprite,
		"evil": evilface_sprite,
	}
	var expression := String(default_face_expression) if face_expression == "default" else face_expression
	var texture: Texture2D = textures.get(expression)
	# Unassigned alternatives and unknown names keep the normal face visible.
	if texture == null:
		texture = face_sprite
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


func become_ally() -> void:
	# Swap to the Ally textures set in the Inspector, so the color shows whose side they're on.
	if is_ally:
		return
	is_ally = true
	if ally_body_sprite != null:
		body_sprite = ally_body_sprite
	if ally_face_sprite != null:
		face_sprite = ally_face_sprite
	if ally_wavehand_sprite != null:
		wavehand_sprite = ally_wavehand_sprite
	if ally_pointhand_sprite != null:
		pointhand_sprite = ally_pointhand_sprite
	if ally_peacehand_sprite != null:
		peacehand_sprite = ally_peacehand_sprite
	if ally_rocknrollhand_sprite != null:
		rocknrollhand_sprite = ally_rocknrollhand_sprite
	if ally_thumbsuphand_sprite != null:
		thumbsuphand_sprite = ally_thumbsuphand_sprite
	if ally_fisthand_sprite != null:
		fisthand_sprite = ally_fisthand_sprite
