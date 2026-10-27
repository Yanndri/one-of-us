extends Node

# Runs one round: leader demonstration -> preparation -> player/NPC response.
# One elapsed clock drives the lane, gestures, and input timing.

# BPM sets the speed; input_window is the allowed early/late error in seconds.
@export_range(40.0, 200.0, 1.0) var bpm: float = 60.0
@export_range(0.0, 5.0, 0.1) var start_delay: float = 2.0
@export_range(0, 4, 1) var count_in_beats: int = 2
@export_range(0.05, 0.2, 0.01) var input_window: float = 0.15

# Each entry is both an Input Map action and an animation name.
const PATTERN: Array[StringName] = [&"clap", &"peace", &"hands_up", &"rock"]

@onready var leader_animation: AnimationPlayer = $"../Leader/AnimationPlayer"
@onready var player = $"../Player"
@onready var lane = $"../Control/RhythmLane"
@onready var status_label: RichTextLabel = $"../Control/RoundTable/MarginContainer/RichTextLabel"

var elapsed: float = 0.0
var current_beat: int = -1
var phase: StringName = &"leader"
# One result per beat: pending, correct, wrong, or missed.
var results: Array[String] = ["pending", "pending", "pending", "pending"]
var extra_inputs: int = 0
var npc_animations: Array[AnimationPlayer] = []
var pointing_npc_animation: AnimationPlayer


func _ready() -> void:
	# Find the real NPCs in Main, excluding the offscreen capture character.
	set_process(false)
	for character in get_parent().get_children():
		if character.is_in_group("Enemy"):
			var animation := character.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if animation != null:
				npc_animations.append(animation)
	status_label.text = "Leader's turn"
	_play_pose(&"default")
	player.rhythm_action.connect(_on_rhythm_action)
	if not lane.is_node_ready():
		await lane.ready
	await lane.prepare_icons()
	player.reset_gesture_feedback()
	set_process(true)


func _process(delta: float) -> void:
	elapsed += delta
	var sequence_time := elapsed - start_delay
	if sequence_time < 0.0:
		return

	var beat_duration := 60.0 / bpm
	var pass_duration := PATTERN.size() * beat_duration
	if phase == &"leader":
		lane.show_leader(sequence_time / pass_duration)
		# Put each step at the middle of its beat, leaving a short lead-in.
		var leader_beat := mini(floori(sequence_time / beat_duration - 0.5), PATTERN.size() - 1)
		while current_beat < leader_beat:
			current_beat += 1
			var action: StringName = PATTERN[current_beat]
			lane.plot_step(current_beat, (current_beat + 0.5) / PATTERN.size(), action)
			_play_pose(&"default" if action == &"rest" else action)
		if sequence_time < pass_duration:
			return
		_play_pose(&"default")
		player.perform_rhythm_action(&"rest")
		phase = &"count_in"

	var response_start := (PATTERN.size() + count_in_beats) * beat_duration
	if sequence_time < response_start:
		status_label.text = "Get ready"
		return

	if phase == &"count_in":
		phase = &"response"
		current_beat = -1
		player.rhythm_input_enabled = true
		player.reset_gesture_feedback()
		_play_npc_pose(&"default")
		status_label.text = "Your turn"

	var response_time := sequence_time - response_start
	lane.show_player(response_time / pass_duration)
	for index in PATTERN.size():
		# Judge unanswered beats only after their entire input window has closed.
		var due_time := (index + 0.5) * beat_duration
		if response_time > due_time + _timing_window() and results[index] == "pending":
			results[index] = "correct" if PATTERN[index] == &"rest" else "missed"
			lane.show_result(index, results[index])
			player.show_gesture_feedback(results[index] == "correct")

	if response_time >= pass_duration:
		# Stop scoring, restore the normal face, then show the NPC reaction.
		phase = &"finished"
		player.rhythm_input_enabled = false
		player.free_gesturing_enabled = true
		player.perform_rhythm_action(&"rest")
		player.reset_gesture_feedback()
		_play_npc_pose(&"default")
		status_label.text = "Response complete"
		if extra_inputs > 0 or results.has("wrong") or results.has("missed"):
			_react_to_mistake()
		set_process(false)
		return

	var response_beat := floori(response_time / beat_duration - 0.5)
	while current_beat < response_beat:
		current_beat += 1
		var action: StringName = PATTERN[current_beat]
		_play_npc_pose(&"default" if action == &"rest" else action)
		if action == &"rest":
			player.perform_rhythm_action(&"rest")


func _timing_window() -> float:
	# Keep neighboring windows separate even if BPM is increased.
	return minf(input_window, (60.0 / bpm) * 0.45)


func _on_rhythm_action(action: StringName) -> void:
	# Match the press to the nearest plotted step, then check timing and action.
	if phase != &"response":
		return
	var beat_duration := 60.0 / bpm
	var response_time := elapsed - start_delay - (PATTERN.size() + count_in_beats) * beat_duration
	var beat := roundi(response_time / beat_duration - 0.5)
	if beat < 0 or beat >= PATTERN.size():
		extra_inputs += 1
		player.show_gesture_feedback(false)
		return
	var offset := response_time - (beat + 0.5) * beat_duration
	if absf(offset) > _timing_window():
		extra_inputs += 1
		player.show_gesture_feedback(false)
		return
	if results[beat] != "pending":
		# Extra presses cannot turn an incorrect beat into a correct one.
		results[beat] = "wrong"
	elif action == PATTERN[beat]:
		results[beat] = "correct"
	else:
		results[beat] = "wrong"
	lane.show_result(beat, results[beat])
	player.show_gesture_feedback(results[beat] == "correct")


func _react_to_mistake() -> void:
	# React only after everyone has completed the response sequence.
	# This does not read or change Sadfacelevels.
	if phase != &"finished" or is_instance_valid(pointing_npc_animation) or npc_animations.is_empty():
		return
	pointing_npc_animation = npc_animations[0]
	var npc := pointing_npc_animation.get_parent() as Node2D
	var pointing := npc.get_node("Pointing") as Node2D
	var hand := pointing.get_node("PointHand") as Sprite2D
	_play_character_pose(pointing_npc_animation, &"pointing")
	pointing.position = Vector2.ZERO
	hand.position = Vector2(76.0, 0.0)
	hand.rotation = PI / 4.0
	pointing.rotation = npc.to_local(player.global_position).angle()


func _play_pose(animation: StringName) -> void:
	_play_character_pose(leader_animation, animation)


func _play_npc_pose(animation: StringName) -> void:
	# A reacting NPC keeps pointing instead of being reset with the group.
	for npc_animation in npc_animations:
		if npc_animation == pointing_npc_animation:
			continue
		_play_character_pose(npc_animation, animation)


func _play_character_pose(animation_player: AnimationPlayer, animation: StringName) -> void:
	animation_player.stop()
	# Clear flips and hand offsets left by the previous gesture.
	animation_player.play("RESET")
	animation_player.advance(0.0)
	animation_player.stop()
	animation_player.play(animation)
	animation_player.advance(0.0)
