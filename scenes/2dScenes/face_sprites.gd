@tool
extends Node

@export var body_sprite: Texture2D:
	set(value):
		body_sprite = value
		_queue_refresh()
@export var face_sprite: Texture2D:
	set(value):
		face_sprite = value
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
	_apply_texture(^"../Face", face_sprite)
	_apply_texture(^"../Pointing/PointHand", pointhand_sprite)
	_apply_hand_texture()


func set_hand_pose(pose: StringName) -> void:
	hand_pose = String(pose)


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
	var sprite := get_node_or_null(path) as Sprite2D
	if sprite != null:
		sprite.texture = texture
