extends Node

@export_range(40.0, 200.0, 1.0) var bpm: float = 60.0
@export_range(0.0, 5.0, 0.1) var start_delay: float = 2.0
@export_range(0, 4, 1) var count_in_beats: int = 2
@export_range(0.05, 0.2, 0.01) var input_window: float = 0.15

const PATTERN: Array[StringName] = [&"clap", &"peace", &"hands_up", &"rock"]

@onready var leader_animation: AnimationPlayer = $"../Leader/AnimationPlayer"
@onready var player = $"../Player"
@onready var lane = $"../Control/RhythmLane"
@onready var status_label: RichTextLabel = $"../Control/RoundTable/MarginContainer/RichTextLabel"

var elapsed: float = 0.0
var current_beat: int = -1
var phase: StringName = &"leader"
var results: Array[String] = ["pending", "pending", "pending", "pending"]
var extra_inputs: int = 0


func _ready() -> void:
	set_process(false)
	status_label.text = "Leader's turn"
	_play_pose(&"default")
	player.rhythm_action.connect(_on_rhythm_action)
	if not lane.is_node_ready():
		await lane.ready
	await lane.prepare_icons()
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
		status_label.text = "Your turn"

	var response_time := sequence_time - response_start
	lane.show_player(response_time / pass_duration)
	for index in PATTERN.size():
		var due_time := (index + 0.5) * beat_duration
		if response_time > due_time + _timing_window() and results[index] == "pending":
			results[index] = "correct" if PATTERN[index] == &"rest" else "missed"
			lane.show_result(index, results[index])

	if response_time >= pass_duration:
		phase = &"finished"
		player.rhythm_input_enabled = false
		player.perform_rhythm_action(&"rest")
		status_label.text = "Response complete"
		set_process(false)
		return

	var response_beat := floori(response_time / beat_duration - 0.5)
	if response_beat > current_beat:
		current_beat = response_beat
		if PATTERN[response_beat] == &"rest":
			player.perform_rhythm_action(&"rest")


func _timing_window() -> float:
	return minf(input_window, (60.0 / bpm) * 0.45)


func _on_rhythm_action(action: StringName) -> void:
	if phase != &"response":
		return
	var beat_duration := 60.0 / bpm
	var response_time := elapsed - start_delay - (PATTERN.size() + count_in_beats) * beat_duration
	var beat := roundi(response_time / beat_duration - 0.5)
	if beat < 0 or beat >= PATTERN.size():
		extra_inputs += 1
		return
	var offset := response_time - (beat + 0.5) * beat_duration
	if absf(offset) > _timing_window():
		extra_inputs += 1
		return
	if results[beat] != "pending":
		results[beat] = "wrong"
	elif action == PATTERN[beat]:
		results[beat] = "correct"
	else:
		results[beat] = "wrong"
	lane.show_result(beat, results[beat])


func _play_pose(animation: StringName) -> void:
	leader_animation.stop()
	# Clear flips and hand offsets left by the previous gesture.
	leader_animation.play("RESET")
	leader_animation.advance(0.0)
	leader_animation.stop()
	leader_animation.play(animation)
	leader_animation.advance(0.0)
