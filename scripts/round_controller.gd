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
@onready var table = $"../Control/RoundTable"

@onready var chapter_label: RichTextLabel = $"../Control/RichTextLabel"

# How far a seat moves away from the table per step (per accuser for the player).
@export var seat_slide_distance: float = 40.0
@export var seat_slide_duration: float = 0.6

@export_group("Chapter 2")
# Chapter 2 swaps in this level after a clean Chapter 1 round.
@export var chapter_two_level: RhythmLevel = preload("res://levels/level_02.tres")
# The NPC who can't keep up, and which beats (0-based) they come in late on.
@export var odd_one_out_path: NodePath = ^"../NPC3"
@export var odd_one_out_late_on_every_beat: bool = true
# Only used when the option above is off.
@export var odd_one_out_late_beats: Array[int] = [1, 3]
@export_range(0.1, 1.0, 0.05) var odd_one_out_lateness: float = 0.5
# Seconds between each pressure line while the player refuses to point.
@export_range(1.0, 20.0, 0.5) var pressure_interval: float = 6.0
# Seconds the "point at this guy" tutorial waits for a first click before the pressure starts anyway.
@export_range(1.0, 60.0, 1.0) var point_tutorial_time: float = 20.0
# One line per NPC that turns on the player, in order. Edit them in messages.gd.
@export var pressure_lines: Array[StringName] = [&"Pressure1", &"Pressure2", &"Pressure3"]
@export_group("")

var chapter: int = 1
var odd_one_out: Node2D
# Chapter 3 can read this: true if the player pointed at the odd one out.
var gave_in_to_pressure: bool = false

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
# NPCs pointing at the odd one out rather than the player.
var odd_accuser_animations: Array[AnimationPlayer] = []
# Each character's starting position, so slides can always return them.
var _seats: Dictionary = {}


func _ready() -> void:
	# Find followers in Main. Friend follows the moves but never accuses the player.
	set_process(false)
	if not _load_level(level):
		return
	for character in get_parent().get_children():
		if character.is_in_group("Enemy") or character.is_in_group("Friend"):
			var animation := character.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if animation != null:
				if character.is_in_group("Friend"):
					friend_animations.append(animation)
				else:
					npc_animations.append(animation)
	_seats[player] = player.global_position
	for animation in npc_animations + friend_animations:
		var character := animation.get_parent() as Node2D
		_seats[character] = character.global_position
	odd_one_out = get_node_or_null(odd_one_out_path) as Node2D
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


func _load_level(new_level: RhythmLevel) -> bool:
	# Copy a level's settings so the round uses one consistent setup until the next chapter.
	if new_level == null or new_level.gestures.is_empty():
		push_warning("Rhythm level needs at least one gesture.")
		return false
	var steps: Array[Dictionary] = new_level.resolve_gestures()
	if steps.is_empty():
		push_warning("Each level gesture needs a RhythmGesture resource.")
		return false
	pattern.clear()
	gesture_positions.clear()
	gesture_tick_widths.clear()
	for step in steps:
		var action: StringName = step.gesture
		if action not in [&"clap", &"peace", &"hands_up", &"rock", &"rest"]:
			push_warning("Unknown level gesture: " + str(action))
			return false
		pattern.append(action)
		gesture_positions.append(step.progress)
		gesture_tick_widths.append(step.tick_thickness)
	bpm = new_level.bpm
	start_delay = new_level.start_delay
	input_window = new_level.input_window
	pass_duration = pattern.size() * 60.0 / bpm
	# Scoring always has exactly one result per configured beat.
	results.resize(pattern.size())
	results.fill("pending")
	return true


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
		if chapter == 2 and (odd_one_out_late_on_every_beat or current_beat in odd_one_out_late_beats):
			_play_late_pose(&"default" if action == &"rest" else action)
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
			_forgive_one_accuser()
			if chapter == 1:
				_finish_chapter_one()
			else:
				_run_peer_pressure()
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
		# Presses outside every timing window are ignored; only the windows are judged.
		return
	if results[beat] == "correct":
		# A beat that already landed stays correct, whatever is pressed after it.
		return
	if action == pattern[beat]:
		# A wrong press can still be fixed by a correct one inside the same window.
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
		# The odd one out is struggling too, so they never accuse the player.
		if chapter == 2 and animation.get_parent() == odd_one_out:
			continue
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
	_slide_player_seat(pointing_npc_animations.size())


func _forgive_one_accuser() -> void:
	# A clean round makes the latest accuser stop pointing, easing face and seat by one step.
	if pointing_npc_animations.is_empty():
		return
	var animation: AnimationPlayer = pointing_npc_animations.pop_back()
	_play_character_pose(animation, &"default")
	player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
	_slide_player_seat(pointing_npc_animations.size())


func _slide_player_seat(steps: int) -> void:
	_slide_seat(player, steps)


func _slide_seat(character: Node2D, steps: int) -> Tween:
	# Move a character `steps` slides away from the table; 0 returns them to their seat.
	var seat: Vector2 = _seats[character]
	var away: Vector2 = (seat - table.get_global_rect().get_center()).normalized()
	var tween := create_tween()
	tween.tween_property(character, "global_position", seat + away * seat_slide_distance * steps, seat_slide_duration)
	# Keep accusers aimed at whoever they point at once everyone stops moving.
	tween.tween_callback(_reaim_accusers)
	return tween


func _reaim_accusers() -> void:
	for animation in pointing_npc_animations:
		_point_npc_at_player(animation)
	for animation in odd_accuser_animations:
		_point_npc_at(animation, odd_one_out)


func _point_npc_at_player(animation: AnimationPlayer) -> void:
	_point_npc_at(animation, player)


func _point_npc_at(animation: AnimationPlayer, target: Node2D) -> void:
	# Reapply the pointing pose after an accuser finishes following gestures.
	var npc := animation.get_parent() as Node2D
	var pointing := npc.get_node("Pointing") as Node2D
	var hand := pointing.get_node("PointHand") as Sprite2D
	_play_character_pose(animation, &"pointing")
	pointing.position = Vector2.ZERO
	hand.position = Vector2(76.0, 0.0)
	hand.rotation = PI / 4.0
	pointing.rotation = npc.to_local(target.global_position).angle()


func _play_late_pose(animation: StringName) -> void:
	# The odd one out holds still on the beat, then catches up a moment too late.
	if odd_one_out == null:
		return
	var odd_animation := odd_one_out.get_node("AnimationPlayer") as AnimationPlayer
	_play_character_pose(odd_animation, &"default")
	await get_tree().create_timer(odd_one_out_lateness).timeout
	if phase == &"response":
		_play_character_pose(odd_animation, animation)


func _finish_chapter_one() -> void:
	await dialogue.play_line(&"Success")
	await dialogue.wait_until_finished()
	_start_chapter_two()


func _start_chapter_two() -> void:
	if odd_one_out == null or not _load_level(chapter_two_level):
		push_warning("Chapter 2 needs a level and an odd one out NPC.")
		return
	chapter = 2
	# A fresh chapter: nobody is pointing at the player any more.
	for animation in pointing_npc_animations:
		_play_character_pose(animation, &"default")
	pointing_npc_animations.clear()
	player.set_pointing_pressure(0, npc_animations.size())
	_slide_player_seat(0)
	chapter_label.text = "Chapter [b]2 : [/b][i]The Odd One Out"
	await dialogue.play_line(&"ChapterTwoIntro")
	await dialogue.wait_until_finished()
	_restart_level()


func _run_peer_pressure() -> void:
	# The player kept up, but the odd one out didn't. The group wants the player to point.
	phase = &"pressure"
	var odd_animation := odd_one_out.get_node("AnimationPlayer") as AnimationPlayer
	var group: Array[AnimationPlayer] = []
	for animation in npc_animations:
		if animation != odd_animation:
			group.append(animation)
	# Even Friend joins in, so the player has nobody to copy. Friend never turns on the player.
	odd_accuser_animations = group + friend_animations
	_play_character_pose(odd_animation, &"default")
	odd_one_out.get_node("FaceSprites").set_default_face_expression(&"sad_level_2")
	_reaim_accusers()
	_slide_seat(odd_one_out, 1)
	var first_speaker: StringName = dialogue.get_speaker_for_character(group[0].get_parent())
	await dialogue.play_line(&"OddAccusation", -1.0, first_speaker)
	await dialogue.wait_until_finished()
	# An NPC teaches pointing. The countdown only starts once the player has pointed at someone.
	var teacher: StringName = dialogue.get_speaker_for_character(group[1 % group.size()].get_parent())
	_clear_selections()
	dialogue.play_line(&"PointTutorial", -1.0, teacher)
	var first_target: Node = await _wait_for_any_click(point_tutorial_time)
	var gave_in := first_target == odd_one_out
	if not gave_in:
		# Keep the player's point and outline visible, so the click clearly registered.
		# If the time ran out with no click, skip straight to the pressure.
		if first_target != null:
			await dialogue.play_line(&"PointThemOut")
		# Each pause without pointing turns one more NPC from the odd one out to the player.
		for index in pressure_lines.size():
			if await _wait_for_accusation(pressure_interval):
				gave_in = true
				break
			var animation := group[index % group.size()]
			odd_accuser_animations.erase(animation)
			if not pointing_npc_animations.has(animation):
				pointing_npc_animations.append(animation)
			_point_npc_at_player(animation)
			player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
			_slide_player_seat(pointing_npc_animations.size())
			dialogue.play_line(pressure_lines[index], -1.0, dialogue.get_speaker_for_character(animation.get_parent()))
		if not gave_in:
			gave_in = await _wait_for_accusation(pressure_interval)
	gave_in_to_pressure = gave_in
	phase = &"chapter_end"
	player.free_gesturing_enabled = false
	dialogue.stop_talking()
	if gave_in:
		await _play_gave_in_ending(group)
	else:
		await _play_held_out_ending(group)
	chapter_label.text = "[i]To be continued..."


func _wait_for_accusation(seconds: float) -> bool:
	return await _wait_for_click(odd_one_out, seconds)


func _wait_for_any_click(seconds: float) -> Node:
	# Returns whichever character the player points at, or null if the time runs out.
	var time_left := seconds
	while time_left > 0.0:
		for selection in get_tree().get_nodes_in_group(&"character_selection"):
			if selection.selected and selection.get_viewport() == get_viewport():
				return selection.get_parent()
		await get_tree().process_frame
		time_left -= get_process_delta_time()
	return null


func _clear_selections() -> void:
	for selection in get_tree().get_nodes_in_group(&"character_selection"):
		if selection.get_viewport() == get_viewport():
			selection.set_selected(false)


func _wait_for_click(character: Node, seconds: float = -1.0) -> bool:
	# True as soon as the player clicks this character (the existing selection outline).
	# A negative time waits with no time limit.
	var selection := character.get_node("Selection")
	var time_left := seconds
	while seconds < 0.0 or time_left > 0.0:
		if selection.selected:
			return true
		await get_tree().process_frame
		time_left -= get_process_delta_time()
	return selection.selected


func _play_gave_in_ending(group: Array[AnimationPlayer]) -> void:
	# The group got what it wanted: everyone points at the odd one out, who slides further out.
	pointing_npc_animations.clear()
	odd_accuser_animations = group + friend_animations
	player.set_pointing_pressure(0, npc_animations.size())
	_slide_player_seat(0)
	_slide_seat(odd_one_out, 3)
	await dialogue.play_line(&"GaveInLeader")
	await dialogue.wait_until_finished()
	await dialogue.play_line(&"GaveInFriend")
	await dialogue.wait_until_finished()


func _play_held_out_ending(group: Array[AnimationPlayer]) -> void:
	# Friend sees the player refuse and lowers their hand. The group doesn't:
	# standing up costs the player, so the group splits its pointing between them and the odd one out.
	for animation in friend_animations:
		odd_accuser_animations.erase(animation)
		_play_character_pose(animation, &"default")
	await dialogue.play_line(&"HeldOutFriend")
	await dialogue.wait_until_finished()
	pointing_npc_animations.clear()
	odd_accuser_animations.clear()
	for index in group.size():
		if index % 2 == 0:
			pointing_npc_animations.append(group[index])
		else:
			odd_accuser_animations.append(group[index])
	_reaim_accusers()
	player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
	_slide_player_seat(pointing_npc_animations.size())
	await dialogue.play_line(&"HeldOutHook")
	await dialogue.wait_until_finished()


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
