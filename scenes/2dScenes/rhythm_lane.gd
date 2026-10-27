extends Control

# Displays the round clock. Step positions stay fixed while the markers move.
# This script shows results; RoundController is responsible for judging input.

@onready var leader_marker: Control = $LeaderMarker
@onready var player_marker: Control = $PlayerMark
@onready var step_plots: Control = $StepPlots

var leader_progress: float = 0.0
var player_progress: float = 0.0
var pose_textures: Dictionary = {}


func _ready() -> void:
	resized.connect(_layout_marks)
	player_marker.hide()
	_layout_marks()


func show_leader(progress: float) -> void:
	leader_progress = clampf(progress, 0.0, 1.0)
	_layout_marks()


func prepare_icons() -> void:
	# The offscreen character is rendered once per pose, then its images are reused.
	pose_textures = await $EmoteCapture.capture_poses()


func show_player(progress: float) -> void:
	leader_marker.hide()
	player_marker.show()
	player_progress = clampf(progress, 0.0, 1.0)
	_layout_marks()


func plot_step(index: int, progress: float, action: StringName) -> void:
	# Called when the leader performs a step; never reveal future steps early.
	if step_plots.has_node("Step%d" % index):
		return
	var step := Control.new()
	step.name = "Step%d" % index
	step.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step.set_meta("progress", progress)
	step_plots.add_child(step)
	if pose_textures.has(action):
		var icon := TextureRect.new()
		icon.name = "Emote"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(-28, -42)
		icon.size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.texture = pose_textures[action]
		step.add_child(icon)
	var tick := ColorRect.new()
	tick.name = "Tick"
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.position = Vector2(-2, 18)
	tick.size = Vector2(4, 32)
	tick.color = Color(0.38, 0.0, 0.65)
	step.add_child(tick)
	var label := Label.new()
	label.name = "Action"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(-40, 50)
	label.size = Vector2(80, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	match action:
		&"clap":
			label.text = "CLAP"
		&"hands_up":
			label.text = "HANDS UP"
		&"peace":
			label.text = "PEACE"
		&"rock":
			label.text = "ROCK"
		&"rest":
			label.text = "REST"
	step.add_child(label)
	_layout_marks()


func show_result(index: int, result: String) -> void:
	# Update the existing tick and label without moving their timing position.
	var step := step_plots.get_node_or_null("Step%d" % index)
	if step == null:
		return
	var color := Color(0.3, 0.85, 0.45) if result == "correct" else Color(1.0, 0.35, 0.3)
	step.get_node("Tick").color = color
	step.get_node("Action").modulate = color
	step.get_node("Action").text = step.get_node("Action").text.trim_suffix(" ✓").trim_suffix(" ×")
	step.get_node("Action").text += " ✓" if result == "correct" else " ×"


func _layout_marks() -> void:
	# Normalized progress (0 to 1) lets resizing keep notes and markers aligned.
	if not is_node_ready():
		return
	var travel := maxf(size.x - leader_marker.size.x, 0.0)
	leader_marker.position.x = travel * leader_progress
	player_marker.position.x = travel * player_progress
	for step in step_plots.get_children():
		step.position.x = travel * float(step.get_meta("progress")) + leader_marker.size.x * 0.5
