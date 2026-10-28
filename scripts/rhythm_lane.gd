extends Control

# Displays the round clock. Step positions stay fixed while the markers move.
# This script shows results; RoundController is responsible for judging input.

@onready var leader_marker: Control = $LeaderMarker
@onready var player_marker: Control = $PlayerMark
@onready var step_plots: Control = $StepPlots
@onready var player_plots: Control = $PlayerPlots
@onready var background: Control = $Background
@onready var leader_step_template: Control = $LeaderStepTemplate
@onready var player_step_template: Control = $PlayerStepTemplate

var leader_progress: float = 0.0
var player_progress: float = 0.0
var pose_textures: Dictionary = {}
var player_pose_textures: Dictionary = {}


func _ready() -> void:
	# Visible samples in the editor; runtime marks duplicate these designs.
	leader_step_template.hide()
	player_step_template.hide()
	resized.connect(_layout_marks)
	player_marker.hide()
	_layout_marks()


func show_leader(progress: float) -> void:
	leader_progress = clampf(progress, 0.0, 1.0)
	_layout_marks()


func prepare_icons() -> void:
	# The offscreen character is rendered once per pose, then its images are reused.
	pose_textures = await $EmoteCapture.capture_poses()
	player_pose_textures = await $EmoteCapture.capture_poses(get_node("../../Player"))


func show_player(progress: float) -> void:
	leader_marker.hide()
	player_marker.show()
	player_progress = clampf(progress, 0.0, 1.0)
	_layout_marks()


func plot_step(index: int, progress: float, action: StringName) -> void:
	# The template supplies the design; code only supplies timing and content.
	if step_plots.has_node("Step%d" % index):
		return
	var step := leader_step_template.duplicate() as Control
	step.name = "Step%d" % index
	step.set_meta("progress", progress)
	step_plots.add_child(step)
	step.show()
	step.get_node("Emote").texture = pose_textures.get(action)
	step.get_node("Action").text = str(action).replace("_", " ").to_upper()
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


func plot_player_step(progress: float, action: StringName) -> void:
	# Copy the editable player design at the actual input timing.
	var step := player_step_template.duplicate() as Control
	step.name = "Gesture%d" % player_plots.get_child_count()
	step.set_meta("progress", clampf(progress, 0.0, 1.0))
	step.set_meta("action", action)
	player_plots.add_child(step)
	step.show()
	step.get_node("Emote").texture = player_pose_textures.get(action)
	_layout_marks()


func _layout_marks() -> void:
	# Normalized progress (0 to 1) lets resizing keep notes and markers aligned.
	if not is_node_ready():
		return
	var travel := maxf(size.x - leader_marker.size.x, 0.0)
	leader_marker.position.x = travel * leader_progress
	player_marker.position.x = travel * player_progress
	for step in step_plots.get_children():
		step.position.x = travel * float(step.get_meta("progress")) + leader_marker.size.x * 0.5
	for step in player_plots.get_children():
		# Match the moving marker's x position and the background's vertical center.
		step.position = Vector2(
			travel * float(step.get_meta("progress")) + leader_marker.size.x * 0.5,
			background.position.y + background.size.y * 0.5
		)
