extends Node

# Runs one round: leader demonstration -> preparation -> player/NPC response.
# Each pass uses one clock; awaited dialogue separates the two passes.

const RhythmLevel = preload("res://scripts/rhythm_level.gd")

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

@onready var chapter_label: RichTextLabel = $"../Control/ChapterLabel"
@onready var reflection_screen = $"../Control/ReflectionScreen"

# How far a seat moves away from the table per step (per accuser for the player).
@export var seat_slide_distance: float = 40.0
@export var seat_slide_duration: float = 0.6
# Draw each tick exactly as wide as its real timing window, so what players see is what counts.
# Turn off to use each gesture's Tick Thickness instead.
@export var ticks_match_timing_window: bool = true
# At the end of a chapter, everyone still pointing lowers their hand one at a time, this far apart.
@export_range(0.1, 2.0, 0.05) var hand_lower_interval: float = 0.6
# How long an NPC's pointing arm takes to swing onto a new target. 0 snaps instantly.
@export_range(0.0, 1.0, 0.05) var npc_pointing_tween_duration: float = 0.3

# Excluded characters fade to this tint (the alpha makes them see-through).
@export var excluded_color: Color = Color(0.55, 0.55, 0.55, 0.55)
@export_range(0.0, 3.0, 0.1) var excluded_fade_duration: float = 1.0

# One running pointing tween per NPC, so a new target cancels the old swing.
var _pointing_tweens: Dictionary = {}

@export_group("Chapter 1")
# Hand-made rounds, in order. Edit these .tres files to set gestures and positions yourself.
# Clear a slot (or make the list shorter) to let that round pick random gestures instead.
@export var chapter_one_levels: Array[RhythmLevel] = [
	preload("res://levels/ch1_round_1.tres"),
	preload("res://levels/ch1_round_2.tres"),
	preload("res://levels/ch1_round_3.tres"),
	#preload("res://levels/ch1_round_4.tres"),
]
# Gestures per random round, used only for empty slots above.
@export var chapter_one_rounds: Array[int] = [1, 1, 2, 2]
# Random gestures land in this part of the timeline, so the first half is for getting ready.
@export_range(0.0, 1.0, 0.05) var random_position_min: float = 0.55
@export_range(0.0, 1.0, 0.05) var random_position_max: float = 0.95
# Smallest gap between two gestures in one round, as a share of the timeline.
@export_range(0.05, 0.5, 0.05) var random_min_gap: float = 0.2
# One line per NPC that starts pointing at the odd one out, in order. Edit them in messages.gd.
@export var odd_join_lines: Array[StringName] = [&"OddJoin1", &"OddJoin2", &"OddJoin3"]
# Optional line before each Chapter 1 round starts (round 1 first). Leave a slot empty for silence.
@export var chapter_one_round_lines: Array[StringName] = [&"", &"Ch1Round2", &"Ch1Round3", &""]
# Optional line after each Chapter 1 round is cleared (round 1 first).
@export var chapter_one_cleared_lines: Array[StringName] = [&"", &"", &"Ch1Round3Cleared", &""]

@export_group("Chapter 2")
# Chapter 2 swaps in this level after a clean Chapter 1 round.
# Hand-made rounds, in order: one per vote against the odd one out. Clear a slot for random gestures.
@export var chapter_two_levels: Array[RhythmLevel] = [
	preload("res://levels/ch2_round_1.tres"),
	preload("res://levels/ch2_round_2.tres"),
	preload("res://levels/ch2_round_3.tres"),
]
# Gestures per random round, used only for empty slots above.
@export var chapter_two_rounds: Array[int] = [3, 3, 3]
# The NPC who can't keep up, and which beats (0-based) they come in late on.
@export var odd_one_out_path: NodePath = ^"../NPC3"
# Pick a random member of the Enemy group to be the odd one out each time Chapter 2 starts (ignores the path above).
@export var choose_from_enemy_group: bool = true
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
@export_group("Chapter 3")
# Friend can't keep up and does the wrong gestures.
# Rounds in order: Friend first messes up, the group turns on Friend, the help round.
# Clear a slot for random gestures.
@export var chapter_three_levels: Array[RhythmLevel] = [
	preload("res://levels/ch3_round_1.tres"),
	preload("res://levels/ch3_round_2.tres"),
	preload("res://levels/ch3_round_3.tres"),
]
# Gestures per random round, used only for empty slots above.
@export var chapter_three_rounds: Array[int] = [4, 4, 4]
@export_group("Chapter 4")
# Rounds in order: a normal round, the round where someone slips, and the final round together.
# Clear a slot for random gestures.
@export var chapter_four_levels: Array[RhythmLevel] = [
	preload("res://levels/ch4_round_1.tres"),
	preload("res://levels/ch4_round_2.tres"),
	preload("res://levels/ch4_round_3.tres"),
]
# Gestures per random round, used only for empty slots above.
@export var chapter_four_rounds: Array[int] = [4, 4, 4]
# Seconds the Leader takes to glide into Friend's seat in the ending where Friend is gone.
@export_range(0.1, 5.0, 0.1) var leader_glide_duration: float = 1.5
# What the player's body becomes when they turn into "one of us".
@export var player_conform_body: Texture2D = preload("res://assets/Kenney_Shapes/PNG/Default/purple_body_circle.png")
@export_group("")

const RANDOM_GESTURES: Array[StringName] = [&"clap", &"peace", &"hands_up", &"rock"]

var chapter: int = 1
var chapter_one_round: int = 0
# True once every NPC who can accuse is pointing at the player.
var _singled_out: bool = false
# Chapter 2 votes against the odd one out. Votes only go up: an NPC can turn to point at the
# player for a while, but their vote against the odd one out still counts.
var odd_votes: int = 0
# Who cast each of the odd one out's votes, in order, so each vote icon can use the voter's own hand.
var odd_voters: Array[Node2D] = []
# Chapter 3: 0 = Friend first messes up, 1 = group turns on Friend, 2 = the help round.
var chapter_three_round: int = 0
# In the help round Friend copies the player: every beat the player lands, Friend lands too.
var _help_round: bool = false
# Chapter 4: 0 = normal round, 1 = someone slips, 2 = final round together.
var chapter_four_round: int = 0
# The final round: a slip just means trying again together.
var _final_round: bool = false
# Friend's node, kept even if Friend is excluded and leaves the Friend list.
var _friend: Node2D
# True once anyone has pointed at the player, so lines can refer back to how that felt.
var _player_was_pointed_at: bool = false
var odd_one_out: Node2D
# Chapter 3 can read this: true if the player pointed at the odd one out.
var gave_in_to_pressure: bool = false
# Characters the whole group voted out. They stay far from the table, sad, and stop taking part.
var excluded: Array[Node2D] = []

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
	for character in get_parent().get_children():
		if character.is_in_group("Enemy") or character.is_in_group("Friend"):
			var animation := character.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if animation != null:
				if character.is_in_group("Friend"):
					friend_animations.append(animation)
				else:
					npc_animations.append(animation)
	_seats[player] = player.global_position
	# The Leader can be pointed at too, so their vote icons need updating as well.
	_seats[leader_animation.get_parent()] = leader_animation.get_parent().global_position
	for animation in npc_animations + friend_animations:
		var character := animation.get_parent() as Node2D
		_seats[character] = character.global_position
	odd_one_out = get_node_or_null(odd_one_out_path) as Node2D
	if not friend_animations.is_empty():
		_friend = friend_animations[0].get_parent() as Node2D
	_load_chapter_one_round(0)
	_play_pose(&"default")
	player.rhythm_action.connect(_on_rhythm_action)
	player.pointed_at.connect(func(_target: Node2D) -> void: _update_vote_icons())
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


func _load_random_round(count: int) -> void:
	# New random gestures and positions, all after random_position_min so the player can prepare.
	var previous_pattern := pattern.duplicate()
	var previous_positions := gesture_positions.duplicate()
	var choices := RANDOM_GESTURES.duplicate()
	choices.shuffle()
	if count == 1 and previous_pattern.size() == 1:
		# A one-gesture round always changes gesture from the round before.
		choices.erase(previous_pattern[0])
	pattern.clear()
	gesture_positions.clear()
	gesture_tick_widths.clear()
	var earliest := random_position_min
	for index in count:
		pattern.append(choices[index % choices.size()])
		# Leave room for the gestures still to come.
		var latest := random_position_max - random_min_gap * (count - 1 - index)
		var position := randf_range(earliest, latest)
		if count == 1 and previous_positions.size() == 1:
			# Move a single gesture to a clearly different spot on the timeline.
			for attempt in 10:
				if absf(position - previous_positions[0]) >= random_min_gap * 0.5:
					break
				position = randf_range(earliest, latest)
		gesture_positions.append(position)
		gesture_tick_widths.append(24.0)
		earliest = position + random_min_gap
	pass_duration = pattern.size() * 60.0 / bpm
	results.resize(pattern.size())
	results.fill("pending")


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
			lane.plot_step(current_beat, gesture_positions[current_beat], action, _tick_width(current_beat))
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
				if _help_round:
					_play_friend_pose(_wrong_gesture(pattern[index]))

	# Followers use the same positions as the leader, including the lane endpoints.
	while current_beat + 1 < pattern.size() and response_time >= gesture_positions[current_beat + 1] * pass_duration:
		current_beat += 1
		var action: StringName = pattern[current_beat]
		_play_followers_pose(&"default" if action == &"rest" else action)
		if (chapter == 2 or (chapter == 4 and chapter_four_round == 1)) and (odd_one_out_late_on_every_beat or current_beat in odd_one_out_late_beats):
			_play_late_pose(&"default" if action == &"rest" else action)
		if chapter == 3:
			_play_friend_beat(current_beat)
		if action == &"rest":
			player.perform_rhythm_action(&"rest")

	# Keep the final late-input window open even for a note placed at 100%.
	var response_end := maxf(pass_duration, gesture_positions.back() * pass_duration + _timing_window(pattern.size() - 1))
	if response_time > response_end:
		# Stop scoring, restore the normal face, then show the NPC reaction.
		phase = &"finished"
		_update_vote_icons()
		player.rhythm_input_enabled = false
		player.free_gesturing_enabled = true
		player.perform_rhythm_action(&"rest")
		player.reset_gesture_feedback()
		_play_followers_pose(&"default")
		set_process(false)
		var failed := extra_inputs > 0 or results.has("wrong") or results.has("missed")
		if failed and _help_round:
			# A slip while helping just means trying again together, with no new accuser.
			_retry_help_round()
		elif failed and _final_round:
			_retry_final_round()
		elif failed:
			_react_to_mistake()
			_play_failure_dialogue()
		else:
			_forgive_one_accuser()
			if chapter == 1:
				_clear_chapter_one_round()
			elif chapter == 2:
				_clear_chapter_two_round()
			elif chapter == 3:
				_clear_chapter_three_round()
			else:
				_clear_chapter_four_round()
		return


func _start_response() -> void:
	# The message's wait_time controls preparation before the response starts.
	await dialogue.play_line(&"YourTurn")
	# No scoring or marker movement until all the waits have finished.
	elapsed = 0.0
	current_beat = -1
	phase = &"response"
	_update_vote_icons()
	player.rhythm_input_enabled = true
	player.reset_gesture_feedback()
	_play_followers_pose(&"default")
	lane.show_player(0.0)
	set_process(true)
	if _help_round and not odd_accuser_animations.is_empty():
		dialogue.play_line(&"C3Heckle", -1.0, dialogue.get_speaker_for_character(odd_accuser_animations[0].get_parent()))


func _tick_width(index: int) -> float:
	if not ticks_match_timing_window:
		return gesture_tick_widths[index]
	# The window runs from early to late, so it spans twice the timing window on the lane.
	return maxf(2.0 * _timing_window(index) / pass_duration * lane.travel_width(), 2.0)


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
	if _help_round:
		# Friend follows the player's lead, right or wrong.
		_play_friend_pose(action if results[beat] == "correct" else _wrong_gesture(pattern[beat]))


func _react_to_mistake() -> void:
	# React only after everyone has completed the response sequence.
	# Each new accuser also increases the player's resting sadness.
	if phase != &"finished" or _reacted_this_attempt:
		return
	_reacted_this_attempt = true
	# Add exactly one new accuser per failed attempt, excluding Friend and the odd one out.
	# NPCs who aren't pointing at anyone turn first; after that, NPCs turn away from the odd one out.
	for animation in npc_animations:
		if (chapter >= 2 and animation.get_parent() == odd_one_out) or pointing_npc_animations.has(animation) or odd_accuser_animations.has(animation):
			continue
		pointing_npc_animation = animation
		break
	if pointing_npc_animation == null:
		for index in range(odd_accuser_animations.size() - 1, -1, -1):
			if not friend_animations.has(odd_accuser_animations[index]):
				# They turn to the player, but their vote against the odd one out stays.
				pointing_npc_animation = odd_accuser_animations[index]
				odd_accuser_animations.remove_at(index)
				break
	if pointing_npc_animation == null:
		# Everyone is already pointing. Keep the group and reuse the last speaker.
		if not pointing_npc_animations.is_empty():
			pointing_npc_animation = pointing_npc_animations.back()
		return
	pointing_npc_animations.append(pointing_npc_animation)
	_player_was_pointed_at = true
	player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
	_point_npc_at_player(pointing_npc_animation)
	_slide_player_seat(pointing_npc_animations.size())
	# Singled out: every NPC who can accuse is now pointing at the player.
	var odd_is_npc := chapter >= 2 and npc_animations.any(func(animation): return animation.get_parent() == odd_one_out)
	_singled_out = pointing_npc_animations.size() >= npc_animations.size() - (1 if odd_is_npc else 0)


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
	# Every vote change moves a seat, so this is where the vote icons stay in sync.
	_update_vote_icons()
	# Move a character `steps` slides away from the table; 0 returns them to their seat.
	var seat: Vector2 = _seats[character]
	var away: Vector2 = (seat - table.get_global_rect().get_center()).normalized()
	var tween := create_tween()
	tween.tween_property(character, "global_position", seat + away * seat_slide_distance * steps, seat_slide_duration)
	# Keep accusers aimed at whoever they point at once everyone stops moving.
	tween.tween_callback(_reaim_accusers)
	return tween


func _update_vote_icons() -> void:
	# The player's votes are the NPCs pointing at them; the odd one out's are their remembered votes.
	# Votes hide while everyone is gesturing, and on anyone nobody is pointing at right now.
	var gesturing := phase == &"leader" or phase == &"preparation" or phase == &"response"
	for character in _seats:
		var icons: Node = character.get_node_or_null("VoteIcons")
		if icons == null:
			continue
		# Each icon uses the voter's own pointing hand, so its color shows who voted.
		var voters: Array[Node2D] = []
		if gesturing:
			pass
		elif character == player:
			for animation in pointing_npc_animations:
				voters.append(animation.get_parent() as Node2D)
		elif character == odd_one_out and chapter >= 2 and not odd_accuser_animations.is_empty():
			voters = odd_voters.duplicate()
		# Whoever the player is pointing at right now also gets the player's hand.
		if not gesturing and character != player and _player_target() == character and not voters.has(player):
			voters.append(player)
		var textures: Array[Texture2D] = []
		for voter in voters:
			textures.append(voter.get_node("FaceSprites").pointhand_sprite)
		icons.show_votes(textures)


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
	# An NPC already pointing swings from where their arm is; otherwise from the pose's rest angle.
	var was_pointing := pointing.visible
	var previous_rotation := pointing.rotation
	_play_character_pose(animation, &"pointing")
	pointing.position = Vector2.ZERO
	hand.position = Vector2(76.0, 0.0)
	hand.rotation = PI / 4.0
	if was_pointing:
		pointing.rotation = previous_rotation
	var target_angle := npc.to_local(target.global_position).angle()
	# Take the shortest way round, like the player's pointing tween.
	var end_angle := pointing.rotation + wrapf(target_angle - pointing.rotation, -PI, PI)
	if _pointing_tweens.has(npc) and _pointing_tweens[npc].is_valid():
		_pointing_tweens[npc].kill()
	if npc_pointing_tween_duration <= 0.0:
		pointing.rotation = end_angle
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pointing, "rotation", end_angle, npc_pointing_tween_duration)
	_pointing_tweens[npc] = tween


func _play_late_pose(animation: StringName) -> void:
	# The odd one out holds still on the beat, then catches up a moment too late.
	if odd_one_out == null:
		return
	var odd_animation := odd_one_out.get_node("AnimationPlayer") as AnimationPlayer
	_play_character_pose(odd_animation, &"default")
	await get_tree().create_timer(odd_one_out_lateness).timeout
	if phase == &"response":
		_play_character_pose(odd_animation, animation)


func _clear_chapter_one_round() -> void:
	await _play_optional_line(chapter_one_cleared_lines, chapter_one_round)
	chapter_one_round += 1
	if chapter_one_round >= _chapter_one_round_count():
		_finish_chapter_one()
		return
	_load_chapter_one_round(chapter_one_round)
	await _play_optional_line(chapter_one_round_lines, chapter_one_round)
	_restart_level()


func _play_optional_line(lines: Array[StringName], index: int) -> void:
	if index < lines.size() and lines[index] != &"":
		await dialogue.play_line(lines[index])
		await dialogue.wait_until_finished()


func _chapter_one_round_count() -> int:
	return maxi(chapter_one_levels.size(), chapter_one_rounds.size())


func _load_chapter_one_round(index: int) -> void:
	_load_round(chapter_one_levels, chapter_one_rounds, index)


func _load_round(levels: Array[RhythmLevel], random_sizes: Array[int], index: int) -> bool:
	# A level in the chapter's list sets the round by hand; an empty slot picks random gestures.
	if index < levels.size() and levels[index] != null:
		if _load_level(levels[index]):
			return true
	# A random round keeps the tempo, start delay and input window of the round before it.
	# A chapter's first round borrows them from the chapter's first hand-made round, if there is one.
	if index == 0:
		for chapter_level in levels:
			if chapter_level != null:
				bpm = chapter_level.bpm
				start_delay = chapter_level.start_delay
				input_window = chapter_level.input_window
				break
	var count := random_sizes[index] if index < random_sizes.size() else 1
	_load_random_round(count)
	return true


func _clear_chapter_two_round() -> void:
	# The odd one out kept messing up, so one more NPC starts pointing at them.
	# Once only Friend and the player are left, the group pressures the player.
	await _add_odd_accuser()
	if odd_votes >= npc_animations.size() - 1:
		_run_peer_pressure()
		return
	# The next round: one per vote so far.
	_load_round(chapter_two_levels, chapter_two_rounds, odd_votes)
	_restart_level()


func _add_odd_accuser(with_line: bool = true) -> void:
	# One more vote against the odd one out. Then as many NPCs point at them as there are votes,
	# so NPCs who turned to the player come back (several can come back at once).
	if odd_one_out == null:
		return
	odd_votes = mini(odd_votes + 1, _odd_vote_pool())
	var joiner: AnimationPlayer = null
	while odd_accuser_animations.size() < odd_votes:
		var next: AnimationPlayer = null
		# Prefer an NPC who isn't pointing at anyone, then one who is pointing at the player.
		for animation in npc_animations:
			if animation.get_parent() == odd_one_out or pointing_npc_animations.has(animation) or odd_accuser_animations.has(animation):
				continue
			next = animation
			break
		if next == null and not pointing_npc_animations.is_empty():
			next = pointing_npc_animations.pop_back()
		if next == null:
			break
		odd_accuser_animations.append(next)
		if joiner == null:
			joiner = next
	# Remember who cast the new vote: the first current accuser who hasn't voted yet.
	for animation in odd_accuser_animations:
		if odd_voters.size() >= odd_votes:
			break
		var voter := animation.get_parent() as Node2D
		if not odd_voters.has(voter):
			odd_voters.append(voter)
	player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
	_slide_player_seat(pointing_npc_animations.size())
	_reaim_accusers()
	_slide_seat(odd_one_out, odd_votes)
	odd_one_out.get_node("FaceSprites").set_default_face_expression(&"sad_level_1" if odd_votes < 2 else &"sad_level_2")
	var line_index := mini(odd_votes - 1, odd_join_lines.size() - 1)
	if with_line and line_index >= 0 and joiner != null:
		await dialogue.play_line(odd_join_lines[line_index], -1.0, dialogue.get_speaker_for_character(joiner.get_parent()))
		await dialogue.wait_until_finished()


func _odd_vote_pool() -> int:
	# Everyone who can vote against the odd one out: every NPC except the odd one out themselves.
	var odd_is_npc := npc_animations.any(func(animation): return animation.get_parent() == odd_one_out)
	return npc_animations.size() - (1 if odd_is_npc else 0)


func _lower_hands_one_by_one() -> void:
	# A chapter's conclusion: everyone still pointing lowers their hand, one at a time,
	# then the player and the odd one out slide back to their seats.
	var pointing: Array[AnimationPlayer] = []
	pointing.append_array(pointing_npc_animations)
	pointing.append_array(odd_accuser_animations)
	pointing_npc_animations.clear()
	odd_accuser_animations.clear()
	for animation in pointing:
		_play_character_pose(animation, &"default")
		await get_tree().create_timer(hand_lower_interval).timeout
	_clear_selections()
	player.perform_rhythm_action(&"rest")
	player.set_pointing_pressure(0, npc_animations.size())
	_slide_player_seat(0)
	for friend_animation in friend_animations:
		friend_animation.get_parent().get_node("FaceSprites").set_default_face_expression(&"default")
	if odd_one_out != null and not excluded.has(odd_one_out):
		odd_one_out.get_node("FaceSprites").set_default_face_expression(&"default")
		_slide_seat(odd_one_out, 0)
	odd_votes = 0
	odd_voters.clear()


func _exclude(character: Node2D) -> void:
	# Everyone voted: this character is out. They keep their distance and their sad face,
	# and no longer gesture, vote or point for the rest of the game.
	if excluded.has(character):
		return
	excluded.append(character)
	character.get_node("FaceSprites").set_default_face_expression(&"sad_level_3")
	# Grey them out so they fade into the background.
	create_tween().tween_property(character, "modulate", excluded_color, excluded_fade_duration)
	for animation in npc_animations.duplicate():
		if animation.get_parent() == character:
			npc_animations.erase(animation)
			odd_accuser_animations.erase(animation)
			pointing_npc_animations.erase(animation)
			_play_character_pose(animation, &"default")
	for animation in friend_animations.duplicate():
		if animation.get_parent() == character:
			friend_animations.erase(animation)
			_play_character_pose(animation, &"default")


func _game_over(line: StringName = &"GameOver") -> void:
	# The player has been singled out. Show it, then start the game again.
	phase = &"game_over"
	chapter_label.text = "[b]Game Over"
	await dialogue.play_line(line)
	await dialogue.wait_until_finished()
	get_tree().reload_current_scene()


func _finish_chapter_one() -> void:
	await dialogue.play_line(&"Success")
	await dialogue.wait_until_finished()
	_start_chapter_two()


func _start_chapter_two() -> void:
	if choose_from_enemy_group and not npc_animations.is_empty():
		odd_one_out = npc_animations.pick_random().get_parent() as Node2D
	if odd_one_out == null or not _load_round(chapter_two_levels, chapter_two_rounds, 0):
		push_warning("Chapter 2 needs a level and an odd one out NPC.")
		return
	# Chapter 1's conclusion: anyone still pointing at the player lowers their hand.
	var chapter_two_odd_one_out := odd_one_out
	odd_one_out = null
	await _lower_hands_one_by_one()
	odd_one_out = chapter_two_odd_one_out
	chapter = 2
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
	# Friend waits to see what the player does, and only points if the player does.
	odd_accuser_animations = group.duplicate()
	for animation in friend_animations:
		_play_character_pose(animation, &"default")
	_play_character_pose(odd_animation, &"default")
	odd_one_out.get_node("FaceSprites").set_default_face_expression(&"sad_level_2")
	_reaim_accusers()
	_slide_seat(odd_one_out, odd_accuser_animations.size())
	var first_speaker: StringName = dialogue.get_speaker_for_character(group[0].get_parent())
	await dialogue.play_line(&"OddAccusation", -1.0, first_speaker)
	await dialogue.wait_until_finished()
	# An NPC teaches pointing. The countdown only starts once the player has pointed at someone.
	var teacher: StringName = dialogue.get_speaker_for_character(group[1 % group.size()].get_parent())
	# Don't clear selections here: a player who points early, during the accusation line,
	# should still get a reaction instead of having their click silently erased.
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
	_start_chapter_three()


func _start_chapter_three() -> void:
	if friend_animations.is_empty() or not _load_round(chapter_three_levels, chapter_three_rounds, 0):
		push_warning("Chapter 3 needs a Friend and a level.")
		return
	# Chapter 2's conclusion: everyone still pointing lowers their hand.
	await _lower_hands_one_by_one()
	chapter = 3
	chapter_three_round = 0
	_help_round = false
	# This time the one who can't keep up is Friend.
	odd_one_out = friend_animations[0].get_parent() as Node2D
	odd_one_out.get_node("FaceSprites").set_default_face_expression(&"default")
	chapter_label.text = "Chapter [b]3 : [/b][i]Follow My Lead"
	await dialogue.play_line(&"ChapterThreeIntro")
	await dialogue.wait_until_finished()
	_restart_level()


func _play_friend_beat(beat: int) -> void:
	var action: StringName = pattern[beat]
	if not _help_round:
		# Friend can't keep up: every move comes out wrong.
		_play_friend_pose(_wrong_gesture(action))
	elif results[beat] == "correct":
		# The player already landed this beat early, so Friend has it too.
		_play_friend_pose(action)
	else:
		# Friend waits to see what the player does.
		_play_friend_pose(&"default")


func _play_friend_pose(animation: StringName) -> void:
	for friend_animation in friend_animations:
		_play_character_pose(friend_animation, animation)


func _wrong_gesture(action: StringName) -> StringName:
	var choices := RANDOM_GESTURES.duplicate()
	choices.erase(action)
	return choices.pick_random()


func _clear_chapter_three_round() -> void:
	if chapter_three_round == 0:
		# Friend messed up, so one NPC votes against them, the same rule as Chapter 2.
		await _add_odd_accuser()
		await dialogue.play_line(&"C3Worried")
		await dialogue.wait_until_finished()
	elif chapter_three_round == 1:
		# Friend messed up again: another NPC votes, and the player steps in.
		await _add_odd_accuser()
		await dialogue.play_line(&"C3FollowMyLead")
		await dialogue.wait_until_finished()
		await dialogue.play_line(&"C3FriendAgrees")
		await dialogue.wait_until_finished()
		_help_round = true
	else:
		await _play_help_success()
		return
	chapter_three_round += 1
	_load_round(chapter_three_levels, chapter_three_rounds, chapter_three_round)
	_restart_level()


func _retry_help_round() -> void:
	player.free_gesturing_enabled = false
	# Friend copied the mistake, so it counts against them like any other mess-up.
	if odd_votes < _odd_vote_pool():
		await _add_odd_accuser()
	# Once everyone has voted, the group turns to the player: point at your friend.
	if odd_votes >= _odd_vote_pool():
		await _run_friend_pressure()
		return
	await dialogue.play_line(&"C3Again")
	await dialogue.wait_until_finished()
	_restart_level()


func _run_friend_pressure() -> void:
	# Chapter 2's pressure, aimed at Friend. Clicking Friend gives in; waiting it out holds out.
	phase = &"pressure"
	player.free_gesturing_enabled = true
	_clear_selections()
	_update_vote_icons()
	await dialogue.play_line(&"C3PointAtFriend")
	await dialogue.wait_until_finished()
	var gave_in := false
	for index in pressure_lines.size():
		if await _wait_for_accusation(pressure_interval):
			gave_in = true
			break
		# One more NPC turns from Friend to the player. Friend's votes stay.
		var turner: AnimationPlayer = null
		for animation in npc_animations:
			if not pointing_npc_animations.has(animation):
				turner = animation
				break
		if turner == null:
			continue
		odd_accuser_animations.erase(turner)
		pointing_npc_animations.append(turner)
		_point_npc_at_player(turner)
		player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
		_slide_player_seat(pointing_npc_animations.size())
		dialogue.play_line(pressure_lines[index], -1.0, dialogue.get_speaker_for_character(turner.get_parent()))
	if not gave_in:
		gave_in = await _wait_for_accusation(pressure_interval)
	dialogue.stop_talking()
	player.free_gesturing_enabled = false
	if gave_in:
		await _play_friend_excluded_ending()
		return
	# Held out. If everyone is now pointing at the player, the player is the one singled out.
	if pointing_npc_animations.size() >= npc_animations.size():
		await _game_over(&"C3SingledOutForFriend")
		return
	# Otherwise another help round. Whoever turned on the player keeps pointing at them.
	await dialogue.play_line(&"C3StillWithMe")
	await dialogue.wait_until_finished()
	_restart_level()


func _play_friend_excluded_ending() -> void:
	# The player pointed at Friend: everyone has voted, so Friend is out.
	phase = &"chapter_end"
	if not odd_voters.has(player):
		odd_voters.append(player)
	odd_votes = odd_voters.size()
	# The group has what it wanted, so nobody points at the player any more.
	for animation in pointing_npc_animations:
		odd_accuser_animations.append(animation)
	pointing_npc_animations.clear()
	player.set_pointing_pressure(0, npc_animations.size())
	player.face_sprites.set_default_face_expression(&"sad_level_2")
	_reaim_accusers()
	_slide_player_seat(0)
	_slide_seat(odd_one_out, odd_votes + 1)
	_exclude(odd_one_out)
	await dialogue.play_line(&"C3GaveInLeader")
	await dialogue.wait_until_finished()
	await dialogue.play_line(&"C3FriendBetrayed")
	await dialogue.wait_until_finished()
	_start_chapter_four()


func _play_help_success() -> void:
	# Friend kept up. One by one, the group lowers their hands, and Friend comes back to the table.
	_help_round = false
	phase = &"chapter_end"
	await dialogue.play_line(&"C3Thanks")
	await dialogue.wait_until_finished()
	await _lower_hands_one_by_one()
	await dialogue.play_line(&"C3GroupSoftens", -1.0, dialogue.get_speaker_for_character(npc_animations[0].get_parent()))
	await dialogue.wait_until_finished()
	await dialogue.play_line(&"C3LeaderReconsiders")
	await dialogue.wait_until_finished()
	_start_chapter_four()


func _start_chapter_four() -> void:
	await _lower_hands_one_by_one()
	chapter = 4
	chapter_four_round = 0
	_help_round = false
	_final_round = false
	odd_one_out = null
	_load_round(chapter_four_levels, chapter_four_rounds, 0)
	chapter_label.text = "Chapter [b]4 : [/b][i]One of Us"
	await dialogue.play_line(&"ChapterFourIntro")
	await dialogue.wait_until_finished()
	_restart_level()


func _friend_is_with_you() -> bool:
	return _friend != null and not excluded.has(_friend)


func _clear_chapter_four_round() -> void:
	if chapter_four_round == 0:
		# Next round, someone at the table starts slipping.
		chapter_four_round = 1
		odd_one_out = npc_animations.pick_random().get_parent() as Node2D
		_load_round(chapter_four_levels, chapter_four_rounds, 1)
		_restart_level()
	elif chapter_four_round == 1:
		await _vote_against_struggler()
		if _friend_is_with_you():
			await _play_leader_learns()
		else:
			await _run_final_pressure()
	else:
		await _play_ending_together()


func _vote_against_struggler() -> void:
	# The group votes against whoever slipped, one by one, until only the Leader's vote is missing.
	while odd_votes < _odd_vote_pool():
		await _add_odd_accuser(odd_votes == 0)
		await get_tree().create_timer(hand_lower_interval).timeout
	# The Leader raises a hand to point too...
	_point_npc_at(leader_animation, odd_one_out)
	await get_tree().create_timer(1.0).timeout


func _play_leader_learns() -> void:
	# Path A: Friend is with you, and the Leader learns from the two of you.
	await dialogue.play_line(&"C4Remember")
	await dialogue.wait_until_finished()
	_play_character_pose(leader_animation, &"default")
	await dialogue.play_line(&"C4LeaderFollowMyLead")
	await dialogue.wait_until_finished()
	await _lower_hands_one_by_one()
	await _welcome_back_excluded()
	# The final round: the one who slipped follows the Leader, and everyone plays together.
	_final_round = true
	chapter_four_round = 2
	_load_round(chapter_four_levels, chapter_four_rounds, 2)
	await dialogue.play_line(&"C4Together")
	await dialogue.wait_until_finished()
	_restart_level()


func _welcome_back_excluded() -> void:
	# Everyone who was left out fades back in and returns to the table.
	for character in excluded:
		create_tween().tween_property(character, "modulate", Color.WHITE, excluded_fade_duration)
		_slide_seat(character, 0)
		character.get_node("FaceSprites").set_default_face_expression(&"default")
		var animation := character.get_node("AnimationPlayer") as AnimationPlayer
		if character == _friend:
			friend_animations.append(animation)
		else:
			npc_animations.append(animation)
		await get_tree().create_timer(hand_lower_interval).timeout
	excluded.clear()


func _retry_final_round() -> void:
	player.free_gesturing_enabled = false
	await dialogue.play_line(&"C4Again")
	await dialogue.wait_until_finished()
	_restart_level()


func _play_ending_together() -> void:
	# Ending A: everyone made it through together.
	_final_round = false
	phase = &"chapter_end"
	await dialogue.play_line(&"C4EndingTogether")
	await dialogue.wait_until_finished()
	_show_reflection(&"ReflectionTogether")


func _run_final_pressure() -> void:
	# Path B: Friend is gone. The Leader expects the player to finish the vote.
	phase = &"pressure"
	player.free_gesturing_enabled = true
	_clear_selections()
	_update_vote_icons()
	await dialogue.play_line(&"C4YouKnow")
	await dialogue.wait_until_finished()
	var gave_in := false
	for index in pressure_lines.size():
		if await _wait_for_accusation(pressure_interval):
			gave_in = true
			break
		var turner: AnimationPlayer = null
		for animation in npc_animations:
			if animation.get_parent() != odd_one_out and not pointing_npc_animations.has(animation):
				turner = animation
				break
		if turner == null:
			continue
		odd_accuser_animations.erase(turner)
		pointing_npc_animations.append(turner)
		_point_npc_at_player(turner)
		player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
		_slide_player_seat(pointing_npc_animations.size())
		dialogue.play_line(pressure_lines[index], -1.0, dialogue.get_speaker_for_character(turner.get_parent()))
	if not gave_in:
		gave_in = await _wait_for_accusation(pressure_interval)
	dialogue.stop_talking()
	player.free_gesturing_enabled = false
	phase = &"chapter_end"
	if gave_in:
		await _play_ending_one_of_us()
	else:
		await _play_ending_alone()


func _play_ending_one_of_us() -> void:
	# Ending B1: the player pointed. The Leader takes Friend's seat, and the player becomes one of them.
	for animation in pointing_npc_animations:
		odd_accuser_animations.append(animation)
	pointing_npc_animations.clear()
	if not odd_voters.has(player):
		odd_voters.append(player)
	odd_votes = odd_voters.size()
	player.set_pointing_pressure(0, npc_animations.size())
	_reaim_accusers()
	_slide_player_seat(0)
	_exclude(odd_one_out)
	_point_npc_at(leader_animation, odd_one_out)
	var leader := leader_animation.get_parent() as Node2D
	if _friend != null:
		var glide := create_tween()
		glide.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glide.tween_property(leader, "global_position", _seats[_friend], leader_glide_duration)
		await glide.finished
	await dialogue.play_line(&"C4OneOfUsNow")
	await dialogue.wait_until_finished()
	await _turn_player_into_one_of_them()
	player.point_at(odd_one_out.global_position)
	await get_tree().create_timer(1.5).timeout
	_show_reflection(&"ReflectionOneOfUs")


func _turn_player_into_one_of_them() -> void:
	# Fade to purple, then swap to the NPCs' body color, hands and face.
	var faces: Node = player.get_node("FaceSprites")
	var npc_faces: Node = npc_animations[0].get_parent().get_node("FaceSprites") if not npc_animations.is_empty() else null
	var fade := create_tween()
	fade.tween_property(player, "modulate", Color(0.75, 0.55, 1.0), 0.6)
	await fade.finished
	if player_conform_body != null:
		faces.body_sprite = player_conform_body
	if npc_faces != null:
		faces.face_sprite = npc_faces.face_sprite
		faces.wavehand_sprite = npc_faces.wavehand_sprite
		faces.pointhand_sprite = npc_faces.pointhand_sprite
		faces.peacehand_sprite = npc_faces.peacehand_sprite
		faces.rocknrollhand_sprite = npc_faces.rocknrollhand_sprite
		faces.thumbsuphand_sprite = npc_faces.thumbsuphand_sprite
		faces.fisthand_sprite = npc_faces.fisthand_sprite
	faces.set_default_face_expression(&"default")
	var back := create_tween()
	back.tween_property(player, "modulate", Color.WHITE, 0.6)
	await back.finished


func _play_ending_alone() -> void:
	# Ending B2: the player held out with nobody beside them, and the group turns on them.
	for animation in npc_animations:
		if animation.get_parent() == odd_one_out or pointing_npc_animations.has(animation):
			continue
		odd_accuser_animations.erase(animation)
		pointing_npc_animations.append(animation)
		_point_npc_at_player(animation)
		await get_tree().create_timer(hand_lower_interval).timeout
	_point_npc_at(leader_animation, player)
	player.set_pointing_pressure(pointing_npc_animations.size(), npc_animations.size())
	_slide_player_seat(pointing_npc_animations.size() + 2)
	create_tween().tween_property(player, "modulate", excluded_color, excluded_fade_duration)
	await dialogue.play_line(&"C4NotOneOfUs")
	await dialogue.wait_until_finished()
	_show_reflection(&"ReflectionAlone")


func _show_reflection(line_name: StringName) -> void:
	# The ReflectionScreen node lives in Main.tscn under Control, hidden until now.
	chapter_label.text = ""
	reflection_screen.show_reflection(String(dialogue.messages.get_message(line_name).get("text", "")))


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
	_update_vote_icons()


func _player_target() -> Node:
	# The player points at whoever has the selection outline.
	for selection in get_tree().get_nodes_in_group(&"character_selection"):
		if selection.selected and selection.get_viewport() == get_viewport():
			return selection.get_parent()
	return null


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
	# Friend follows the player's lead and points too. Neither of them feels good about it.
	pointing_npc_animations.clear()
	odd_accuser_animations = group + friend_animations
	player.set_pointing_pressure(0, npc_animations.size())
	player.face_sprites.set_default_face_expression(&"sad_level_2")
	for animation in friend_animations:
		animation.get_parent().get_node("FaceSprites").set_default_face_expression(&"sad_level_2")
	# The player's point, and Friend's after it, are votes too: everyone has voted now.
	for voter in [player] + friend_animations.map(func(animation): return animation.get_parent()):
		if not odd_voters.has(voter):
			odd_voters.append(voter)
	odd_votes = odd_voters.size()
	_reaim_accusers()
	_slide_player_seat(0)
	_slide_seat(odd_one_out, odd_accuser_animations.size() + 1)
	_exclude(odd_one_out)
	await dialogue.play_line(&"GaveInLeader")
	await dialogue.wait_until_finished()
	# Only remind the player of being pointed at if it actually happened to them.
	await dialogue.play_line(&"GaveInFriend" if _player_was_pointed_at else &"GaveInFriendNeverPointedAt")
	await dialogue.wait_until_finished()


func _play_held_out_ending(group: Array[AnimationPlayer]) -> void:
	# Friend sees the player refuse and lowers their hand. The group doesn't:
	# standing up costs the player, so the group splits its pointing between them and the odd one out.
	for animation in friend_animations:
		odd_accuser_animations.erase(animation)
		_play_character_pose(animation, &"default")
	# You stood up for them, so the odd one out is on your side now.
	odd_one_out.get_node("FaceSprites").become_ally()
	await dialogue.play_line(&"HeldOutPlayer")
	await dialogue.wait_until_finished()
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
	if _singled_out:
		await _game_over()
		return
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
	_update_vote_icons()
	set_process(true)


func _play_pose(animation: StringName) -> void:
	_play_character_pose(leader_animation, animation)


func _play_followers_pose(animation: StringName) -> void:
	# Everyone follows during the response; remembered accusers point afterward.
	for npc_animation in npc_animations:
		if phase != &"response" and pointing_npc_animations.has(npc_animation):
			_point_npc_at_player(npc_animation)
			continue
		if phase != &"response" and odd_accuser_animations.has(npc_animation):
			_point_npc_at(npc_animation, odd_one_out)
			continue
		_play_character_pose(npc_animation, animation)
	# Friend uses the same timing and their own color-matched gesture textures.
	for friend_animation in friend_animations:
		if phase != &"response" and odd_accuser_animations.has(friend_animation):
			continue
		_play_character_pose(friend_animation, animation)


func _play_character_pose(animation_player: AnimationPlayer, animation: StringName) -> void:
	animation_player.stop()
	# Clear flips and hand offsets left by the previous gesture.
	animation_player.play("RESET")
	animation_player.advance(0.0)
	animation_player.stop()
	animation_player.play(animation)
	animation_player.advance(0.0)
