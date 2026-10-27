extends CharacterBody2D

# Shared I/J/K/L face-movement test. Appearance comes from the FaceSprites child.
# Player uses its own script instead of this test controller.

@export var face_move_distance: float = 10.0
@export var face_tween_duration: float = 0.15

@onready var face: Sprite2D = $Face
@onready var face_rest_position: Vector2 = face.position


var face_tween: Tween


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	var direction: Vector2
	match event.physical_keycode:
		KEY_J:
			direction = Vector2.LEFT
		KEY_K:
			direction = Vector2.DOWN
		KEY_L:
			direction = Vector2.RIGHT
		KEY_I:
			direction = Vector2.UP
		_:
			return

	if face_tween and face_tween.is_valid():
		face_tween.kill()
	face_tween = create_tween()
	face_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	face_tween.tween_property(
		face, "position", face_rest_position + direction * face_move_distance,
		face_tween_duration
	)
	get_viewport().set_input_as_handled()
