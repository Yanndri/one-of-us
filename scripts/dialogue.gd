extends PanelContainer

# Each pointer is named Speech + speaker, for example SpeechPlayer1.
# The duration in say() is the reading time after the text finishes typing.
@export_range(1.0, 120.0, 1.0) var characters_per_second: float = 40.0

# Edit these colors on Dialogue in the Inspector, or add another character group.
# NPCs currently belong to the Enemy group.
@export var group_colors: Dictionary[StringName, Color] = {
	&"Friend": Color("ffd34f"),
	&"Leader": Color("a45aef"),
	&"Enemy": Color("a45aef"),
	&"Player": Color("738fe9"),
}
@export var default_text_color: Color = Color("738fe9")

# Connect each speech pointer's speaker name to the actual character node.
# Paths are relative to this Dialogue node; these are editable for future speakers.
@export var speaker_nodes: Dictionary[StringName, NodePath] = {
	&"Friend1": NodePath("../../Friend"),
	&"Leader": NodePath("../../Leader"),
	&"Player1": NodePath("../../Player"),
	&"NPC1": NodePath("../../NPC1"),
	&"NPC2": NodePath("../../NPC2"),
	&"NPC3": NodePath("../../NPC3"),
	&"NPC4": NodePath("../../NPC4"),
}

@onready var speakers: Node2D = $Speakers
@onready var dialogue_text: RichTextLabel = $MarginContainer/DialogueText
@onready var messages = %Messages

var _time_remaining: float = 0.0
var _revealed_characters: float = 0.0


func _ready() -> void:
	stop_talking()


func play_line(line_name: StringName, reading_time_override: float = -1.0) -> void:
	# Read the entry from the Messages node's single dictionary.
	var line = messages.get_message(line_name)
	if line.is_empty():
		push_warning("Unknown dialogue line: " + str(line_name))
		return
	var duration: float = line.reading_time if reading_time_override < 0.0 else reading_time_override
	say(StringName(line.speaker), line.text, duration)
	# Use `await dialogue.play_line(...)` to wait before the caller continues.
	# Dialogue typing and rendering keep running while that caller is waiting.
	var wait_time := maxf(float(line.get("wait_time", 0.0)), 0.0)
	if wait_time > 0.0:
		await get_tree().create_timer(wait_time).timeout


func say(speaker: StringName, text: String, duration: float = 3.0) -> void:
	stop_talking()
	if text.is_empty() or duration <= 0.0:
		return
	var pointer := speakers.get_node_or_null("Speech" + str(speaker)) as CanvasItem
	if pointer == null:
		push_warning("No dialogue pointer for speaker: " + str(speaker))
		return
	dialogue_text.text = text
	dialogue_text.add_theme_color_override("default_color", _speaker_color(speaker))
	dialogue_text.visible_characters = 0
	pointer.show()
	_time_remaining = duration
	show()
	set_process(true)


func _speaker_color(speaker: StringName) -> Color:
	var character: Node = null
	if speaker_nodes.has(speaker):
		character = get_node_or_null(speaker_nodes[speaker])
	if character != null:
		for group in group_colors:
			if character.is_in_group(group):
				return group_colors[group]
	return default_text_color


func stop_talking() -> void:
	# Hide every pointer before switching speakers or ending a line.
	for pointer in speakers.get_children():
		if pointer is CanvasItem:
			pointer.hide()
	dialogue_text.text = ""
	dialogue_text.visible_characters = 0
	_revealed_characters = 0.0
	_time_remaining = 0.0
	hide()
	set_process(false)


func _process(delta: float) -> void:
	# Reveal the existing text rather than rebuilding the string every frame.
	var character_count := dialogue_text.get_total_character_count()
	if _revealed_characters < character_count:
		var typing_time := (character_count - _revealed_characters) / characters_per_second
		_revealed_characters = minf(_revealed_characters + delta * characters_per_second, character_count)
		dialogue_text.visible_characters = floori(_revealed_characters)
		# Only count down the reading time once the complete line is visible.
		delta = maxf(delta - typing_time, 0.0)
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		stop_talking()
