extends CharacterBody2D

# Plays the player's gestures. RoundController decides whether they are correct.
# Only scored inputs emit this signal; free gestures after the round do not.
signal rhythm_action(action: StringName)

# Scored input is enabled only during the response. Free input starts afterward.
var rhythm_input_enabled: bool = false
var free_gesturing_enabled: bool = false

@export_range(0.01, 1.0, 0.01) var pointing_tween_duration: float = 0.2
@export_range(0.05, 1.0, 0.05) var mistake_face_duration: float = 0.3

var pointing_tween: Tween
var _mistake_face_tween: Tween
# Prevent a new gesture or mouse point from interrupting the current gesture.
var _gesture_locked: bool = false
var sadness_level: int = 0

@onready var pointing: Node2D = $Pointing
@onready var pointing_hand: Sprite2D = $Pointing/PointHand
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var face_sprites = $FaceSprites


func _ready() -> void:
	animation_player.animation_finished.connect(_on_gesture_finished)
	# Aim around the body center, with the finger aligned to local +X.
	pointing.position = Vector2.ZERO
	pointing_hand.position = Vector2(76.0, 0.0)
	pointing_hand.rotation = PI / 4.0


func _unhandled_input(event: InputEvent) -> void:
	# Input Map owns the keys. Key-repeat events are ignored by is_action_pressed.
	if rhythm_input_enabled or free_gesturing_enabled:
		for action in [&"hands_up", &"peace", &"clap", &"rock"]:
			if event.is_action_pressed(action):
				var accepted := perform_rhythm_action(action)
				if accepted and rhythm_input_enabled:
					rhythm_action.emit(action)
				get_viewport().set_input_as_handled()
				return
		if rhythm_input_enabled:
			return
	if event.is_action_pressed(&"point"):
		if event is InputEventMouseButton:
			_point_at_clicked_character(event.position)
		get_viewport().set_input_as_handled()


func _point_at_clicked_character(viewport_position: Vector2) -> void:
	if rhythm_input_enabled or _gesture_locked:
		return
	# Pick the target first, then update every outline from that one selection.
	# A click on empty space or self leaves the target empty and clears all outlines.
	var target_selection: Node = null
	for selection in get_tree().get_nodes_in_group(&"character_selection"):
		var character := selection.get_parent() as Node2D
		if character == self or selection.get_viewport() != get_viewport():
			continue
		if selection.hit_character(viewport_position):
			target_selection = selection
			break
	for selection in get_tree().get_nodes_in_group(&"character_selection"):
		if selection.get_viewport() == get_viewport():
			selection.set_selected(selection == target_selection)
	if target_selection != null:
		point_at(target_selection.get_parent().global_position)


func perform_rhythm_action(action: StringName) -> bool:
	# A round/phase reset can always return the player to rest.
	# Other inputs are ignored until the gesture's animation finishes.
	if action != &"rest" and _gesture_locked:
		return false
	_gesture_locked = action != &"rest"
	if pointing_tween and pointing_tween.is_valid():
		pointing_tween.kill()
	# Restore the open hands when changing from a pointing pose.
	animation_player.play("RESET")
	animation_player.advance(0.0)
	animation_player.stop()
	animation_player.play("default" if action == &"rest" else action)
	animation_player.advance(0.0)
	return true


func _on_gesture_finished(_animation: StringName) -> void:
	_gesture_locked = false


# More accusing NPCs make the player's resting face progressively sadder.
func set_pointing_pressure(pointing_count: int, total_npcs: int) -> void:
	sadness_level = 0
	if pointing_count > 0 and total_npcs > 0:
		sadness_level = clampi(ceili(float(pointing_count) / total_npcs * 4.0), 1, 4)
	var expression := &"default" if sadness_level == 0 else StringName("sad_level_%d" % sadness_level)
	face_sprites.set_default_face_expression(expression)


# A mistake briefly shows level 2 as a shocked reaction, then restores the resting face.
# New feedback cancels the old reset so it cannot erase a newer happy expression.
func show_gesture_feedback(correct: bool) -> void:
	reset_gesture_feedback()
	face_sprites.set_face_expression(&"happy" if correct else &"sad_level_2")
	if not correct:
		_mistake_face_tween = create_tween()
		_mistake_face_tween.tween_interval(mistake_face_duration)
		_mistake_face_tween.tween_callback(reset_gesture_feedback)


func reset_gesture_feedback() -> void:
	if _mistake_face_tween and _mistake_face_tween.is_valid():
		_mistake_face_tween.kill()
	_mistake_face_tween = null
	face_sprites.set_face_expression(&"default")


# Mouse pointing is separate from rhythm input and works after the response.
func point_at(target: Vector2) -> void:
	if _gesture_locked:
		return
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
