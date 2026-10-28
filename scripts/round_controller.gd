extends Node

# Runs one round: leader demonstration -> preparation -> player/NPC response.
# Each pass uses one clock; awaited dialogue separates the two passes.

const RhythmLevel = preload("res://scripts/rhythm_level.gd")

# Expand Level in the Inspector to edit the sequence and timing together.
@export var level: RhythmLevel = preload("res://levels/level_01.tres")

# Copy the level settings at startup so the round uses one consistent setup.
var pattern: Array[StringName] = []
var gesture_positions: Array[float] = []
var gesture_tick_widths: Array[float] = []
var pass_duration: float = 0.0
var bpm: float = 60.0
var start_delay: float = 2.0
var input_window: float = 0.15

@onready var leader_animation: AnimationPlayer = $"../Leader/AnimationPlayer"
@onready var player = $"../Player"
@onready var lane = $"../Control/RhythmLane"
@onready var dialogue = $"../Control/Dialogue"

var elapsed: float = 0.0
var current_beat: int = -1
var phase: StringName = &"leader"
# One result per beat: pending, correct, wrong, or missed.
var results: Array[String] = []
var extra_inputs: int = 0
var npc_animations: Array[AnimationPlayer] = []
var friend_animations: Array[AnimationPlayer] = []
var pointing_npc_animation: AnimationPlayer
# These persist across retries; attempt scores and lane marks still reset.
var pointing_npc_animations: Array[AnimationPlayer] = []
var _friend_defense_played: bool = false
var _reacted_this_attempt: bool = false


func _ready() -> void:
	# Find followers in Main. Friend follows the moves but never accuses the player.
	set_process(false)
	if level == null or level.gestures.is_empty():
		push_warning("Rhythm level needs at least one gesture.")
		return
	var steps: Array[Dictionary] = level.resolve_gestures()
	if steps.is_empty():
		push_warning("Each level gesture needs a RhythmGesture resource.")
		return
	for step in steps:
		var action: StringName = step.gesture
		if action not in [&"clap", &"peace", &"hands_up", &"rock", &"rest"]:
			push_warning("Unknown level gesture: " + str(action))
			return
		pattern.append(action)
		gesture_positions.append(step.progress)
		gesture_tick_widths.append(step.tick_thickness)
	bpm = level.bpm
	start_delay = level.start_delay
	input_window = level.input_window
	pass_duration = pattern.size() * 60.0 / bpm
	# Scoring always has exactly one result per configured beat.
	results.resize(pattern.size())
	results.fill("pending")
	for character in get_parent().get_children():
		if character.is_in_group("Enemy") or character.is_in_group("Friend"):
			var animation := character.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if animation != null:
				if character.is_in_group("Friend"):
					friend_animations.append(animation)
				else:
					npc_animations.append(animation)
	_play_pose(&"default")
	player.rhythm_action.connect(_on_rhythm_action)
	if not lane.is_node_ready():
		await lane.ready
	await lane.prepare_icons()
	player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
	player.reset_gesture_feedback()
	# Friend guides the player while Leader demonstrates the sequence.
	# The round clock stays stopped until Introduction's wait_time has passed.
	await dialogue.play_line(&"Introduction")
	set_process(true)


func _process(delta: float) -> void:
	# Transition dialogue runs once in _start_response(), outside this frame loop.
	if phase != &"leader" and phase != &"response":
		return
	elapsed += delta
	if phase == &"leader":
		var sequence_time := elapsed - start_delay
		if sequence_time < 0.0:
			return
		lane.show_leader(sequence_time / pass_duration)
		# Trigger each gesture when the marker reaches its configured percentage.
		while current_beat + 1 < pattern.size() and sequence_time >= gesture_positions[current_beat + 1] * pass_duration:
			current_beat += 1
			var action: StringName = pattern[current_beat]
			lane.plot_step(current_beat, gesture_positions[current_beat], action, gesture_tick_widths[current_beat])
			_play_pose(&"default" if action == &"rest" else action)
		# A gesture at 100% still needs time to be demonstrated after the marker stops.
		var last_animation := leader_animation.get_animation("default" if pattern.back() == &"rest" else String(pattern.back()))
		var last_pose_duration := 0.0 if pattern.back() == &"rest" else last_animation.length
		var leader_end := maxf(pass_duration, gesture_positions.back() * pass_duration + last_pose_duration)
		if sequence_time < leader_end:
			return
		_play_pose(&"default")
		player.perform_rhythm_action(&"rest")
		phase = &"preparation"
		set_process(false)
		_start_response()
		return

	# Start a fresh clock after the awaited dialogue, independent of its duration.
	var response_time := elapsed
	lane.show_player(response_time / pass_duration)
	for index in pattern.size():
		# Judge unanswered beats only after their entire input window has closed.
		var due_time := gesture_positions[index] * pass_duration
		if response_time > due_time + _timing_window(index) and results[index] == "pending":
			results[index] = "correct" if pattern[index] == &"rest" else "missed"
			lane.show_result(index, results[index])
			player.show_gesture_feedback(results[index] == "correct")
			# Sound only for an unanswered beat after its input window closes.
			if results[index] == "missed":
				GlobalAudio.playMistake()

	# Followers use the same positions as the leader, including the lane endpoints.
	while current_beat + 1 < pattern.size() and response_time >= gesture_positions[current_beat + 1] * pass_duration:
		current_beat += 1
		var action: StringName = pattern[current_beat]
		_play_followers_pose(&"default" if action == &"rest" else action)
		if action == &"rest":
			player.perform_rhythm_action(&"rest")

	# Keep the final late-input window open even for a note placed at 100%.
	var response_end := maxf(pass_duration, gesture_positions.back() * pass_duration + _timing_window(pattern.size() - 1))
	if response_time > response_end:
		# Stop scoring, restore the normal face, then show the NPC reaction.
		phase = &"finished"
		player.rhythm_input_enabled = false
		player.free_gesturing_enabled = true
		player.perform_rhythm_action(&"rest")
		player.reset_gesture_feedback()
		_play_followers_pose(&"default")
		set_process(false)
		if extra_inputs > 0 or results.has("wrong") or results.has("missed"):
			_react_to_mistake()
			_play_failure_dialogue()
		else:
			dialogue.play_line(&"Success")
		return


func _start_response() -> void:
	# The message's wait_time controls preparation before the response starts.
	await dialogue.play_line(&"YourTurn")
	# No scoring or marker movement until all the waits have finished.
	elapsed = 0.0
	current_beat = -1
	phase = &"response"
	player.rhythm_input_enabled = true
	player.reset_gesture_feedback()
	_play_followers_pose(&"default")
	lane.show_player(0.0)
	set_process(true)


func _timing_window(index: int) -> float:
	# Keep timing windows separate when custom positions are close together.
	var window := minf(input_window, (60.0 / bpm) * 0.45)
	if index > 0:
		window = minf(window, (gesture_positions[index] - gesture_positions[index - 1]) * pass_duration * 0.45)
	if index + 1 < pattern.size():
		window = minf(window, (gesture_positions[index + 1] - gesture_positions[index]) * pass_duration * 0.45)
	return window


func _on_rhythm_action(action: StringName) -> void:
	# Match the press to the nearest plotted step, then check timing and action.
	if phase != &"response":
		return
	var response_time := elapsed
	# Only accepted gestures emit this signal; show even wrong or offbeat actions.
	lane.plot_player_step(response_time / pass_duration, action)
	# Find the nearest configured position instead of assuming evenly spaced beats.
	var beat := 0
	for index in range(1, pattern.size()):
		if absf(response_time - gesture_positions[index] * pass_duration) < absf(response_time - gesture_positions[beat] * pass_duration):
			beat = index
	var offset := response_time - gesture_positions[beat] * pass_duration
	if absf(offset) > _timing_window(beat):
		extra_inputs += 1
		player.show_gesture_feedback(false)
		return
	if results[beat] != "pending":
		# Extra presses cannot turn an incorrect beat into a correct one.
		results[beat] = "wrong"
	elif action == pattern[beat]:
		results[beat] = "correct"
		# Reward a matching gesture inside the beat's timing window.
		GlobalAudio.playSound(GlobalAudio.CORRECT_BEAT)
	else:
		results[beat] = "wrong"
	lane.show_result(beat, results[beat])
	player.show_gesture_feedback(results[beat] == "correct")


func _react_to_mistake() -> void:
	# React only after everyone has completed the response sequence.
	# Each new accuser also increases the player's resting sadness.
	if phase != &"finished" or _reacted_this_attempt:
		return
	_reacted_this_attempt = true
	# Add exactly one new accuser per failed attempt, excluding Friend.
	for animation in npc_animations:
		if not pointing_npc_animations.has(animation):
			pointing_npc_animation = animation
			pointing_npc_animations.append(animation)
			player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
			break
	if pointing_npc_animation == null:
		# Everyone is already pointing. Keep the group and reuse the last speaker.
		if not pointing_npc_animations.is_empty():
			pointing_npc_animation = pointing_npc_animations.back()
		return
	_point_npc_at_player(pointing_npc_animation)


func _point_npc_at_player(animation: AnimationPlayer) -> void:
	# Reapply the pointing pose after an accuser finishes following gestures.
	var npc := animation.get_parent() as Node2D
	var pointing := npc.get_node("Pointing") as Node2D
	var hand := pointing.get_node("PointHand") as Sprite2D
	_play_character_pose(animation, &"pointing")
	pointing.position = Vector2.ZERO
	hand.position = Vector2(76.0, 0.0)
	hand.rotation = PI / 4.0
	pointing.rotation = npc.to_local(player.global_position).angle()


func _play_failure_dialogue() -> void:
	# Keep the accusation and defense in order, using the pointing NPC's identity.
	if is_instance_valid(pointing_npc_animation):
		var speaker: StringName = dialogue.get_speaker_for_character(pointing_npc_animation.get_parent())
		if speaker != &"":
			await dialogue.play_line(&"NPCAccusation", -1.0, speaker)
			await dialogue.wait_until_finished()
	# Friend defends the newcomer on the first failure only, not every retry.
	if not _friend_defense_played:
		_friend_defense_played = true
		await dialogue.play_line(&"FriendDefense")
		await dialogue.wait_until_finished()
	await dialogue.play_line(&"TryAgain")
	await dialogue.wait_until_finished()
	_restart_level()


func _restart_level() -> void:
	# Keep this level's resolved pattern/positions so retrying practices the same moves.
	# Clear attempt state; keep the accumulated NPC pointing and first-defense flag.
	dialogue.stop_talking()
	elapsed = 0.0
	current_beat = -1
	extra_inputs = 0
	results.fill("pending")
	pointing_npc_animation = null
	_reacted_this_attempt = false
	player.rhythm_input_enabled = false
	player.free_gesturing_enabled = false
	player.perform_rhythm_action(&"rest")
	player.reset_gesture_feedback()
	_play_pose(&"default")
	_play_followers_pose(&"default")
	for selection in get_tree().get_nodes_in_group(&"character_selection"):
		if selection.get_viewport() == get_viewport():
			selection.set_selected(false)
	lane.reset_round()
	phase = &"leader"
	set_process(true)


func _play_pose(animation: StringName) -> void:
	_play_character_pose(leader_animation, animation)


func _play_followers_pose(animation: StringName) -> void:
	# Everyone follows during the response; remembered accusers point afterward.
	for npc_animation in npc_animations:
		if phase != &"response" and pointing_npc_animations.has(npc_animation):
			_point_npc_at_player(npc_animation)
			continue
		_play_character_pose(npc_animation, animation)
	# Friend uses the same timing and their own color-matched gesture textures.
	for friend_animation in friend_animations:
		_play_character_pose(friend_animation, animation)


func _play_character_pose(animation_player: AnimationPlayer, animation: StringName) -> void:
	animation_player.stop()
	# Clear flips and hand offsets left by the previous gesture.
	animation_player.play("RESET")
	animation_player.advance(0.0)
	animation_player.stop()
	animation_player.play(animation)
	animation_player.advance(0.0)
