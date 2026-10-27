extends CharacterBody2D

signal rhythm_action(action: StringName)

var rhythm_input_enabled: bool = false

@export_range(0.01, 1.0, 0.01) var pointing_tween_duration: float = 0.2

var pointing_tween: Tween

@onready var pointing: Node2D = $Pointing
@onready var pointing_hand: Sprite2D = $Pointing/PointHand
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	# Aim around the body center, with the finger aligned to local +X.
	pointing.position = Vector2.ZERO
	pointing_hand.position = Vector2(76.0, 0.0)
	pointing_hand.rotation = PI / 4.0


func _unhandled_input(event: InputEvent) -> void:
	if rhythm_input_enabled:
		for action in [&"hands_up", &"peace", &"clap", &"rock"]:
			if event.is_action_pressed(action):
				perform_rhythm_action(action)
				rhythm_action.emit(action)
				get_viewport().set_input_as_handled()
				return
		return
	if event.is_action_pressed(&"point"):
		point_at(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func perform_rhythm_action(action: StringName) -> void:
	if pointing_tween and pointing_tween.is_valid():
		pointing_tween.kill()
	# Restore the open hands when changing from a pointing pose.
	animation_player.play("RESET")
	animation_player.advance(0.0)
	animation_player.stop()
	animation_player.play("default" if action == &"rest" else action)
	animation_player.advance(0.0)


func point_at(target: Vector2) -> void:
	if pointing.global_position.distance_squared_to(target) < 0.001:
		return
	animation_player.play("pointing")
	animation_player.advance(0.0)
	if pointing_tween and pointing_tween.is_valid():
		pointing_tween.kill()
	# Wrap the angle difference so the hand always takes the shortest turn.
	var target_angle := pointing.get_angle_to(target) + pointing.rotation
	var end_angle := pointing.rotation + wrapf(
		target_angle - pointing.rotation, -PI, PI
	)
	pointing_tween = create_tween()
	pointing_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pointing_tween.tween_property(
		pointing, "rotation", end_angle, pointing_tween_duration
	)
