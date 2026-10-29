extends PanelContainer

signal line_finished

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
var _face_sprites: Node
var _previous_face: StringName = &"default"
var _dialogue_face: StringName = &""
var _face_time_remaining: float = -1.0
# The talking babble, playing only while the line is typing out.
var _babble: AudioStreamPlayer


func _ready() -> void:
	# Lines in messages.gd can use BBCode, e.g. [color=red]red[/color], [shake]shake[/shake], [wave]wave[/wave].
	# The typewriter reveals only the visible letters, so tags never show while typing.
	dialogue_text.bbcode_enabled = true
	stop_talking()


func play_line(line_name: StringName, reading_time_override: float = -1.0, speaker_override: StringName = &"") -> void:
	# Read the entry from the Messages node's single dictionary.
	var line = messages.get_message(line_name)
	if line.is_empty():
		push_warning("Unknown dialogue line: " + str(line_name))
		return
	var duration: float = line.reading_time if reading_time_override < 0.0 else reading_time_override
	var speaker := StringName(line.speaker) if speaker_override == &"" else speaker_override
	say(speaker, line.text, duration)
	if visible:
		_apply_message_face(speaker, line)
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
	_start_babble()


func wait_until_finished() -> void:
	# Sequences can wait for typing and reading, beyond a shorter wait_time.
	if visible:
		await line_finished


func _speaker_color(speaker: StringName) -> Color:
	var character := _speaker_character(speaker)
	if character != null:
		for group in group_colors:
			if character.is_in_group(group):
				return group_colors[group]
	return default_text_color


func _speaker_character(speaker: StringName) -> Node:
	if speaker_nodes.has(speaker):
		return get_node_or_null(speaker_nodes[speaker])
	return null


func get_speaker_for_character(character: Node) -> StringName:
	# Resolve the actual pointing NPC to its configured dialogue pointer.
	for speaker in speaker_nodes:
		if _speaker_character(speaker) == character:
			return speaker
	return &""


func _apply_message_face(speaker: StringName, line: Dictionary) -> void:
	var expression := StringName(line.get("face", &""))
	var character := _speaker_character(speaker)
	if expression == &"" or character == null:
		return
	_face_sprites = character.get_node_or_null("FaceSprites")
	if _face_sprites == null:
		return
	_previous_face = StringName(_face_sprites.get("face_expression"))
	_dialogue_face = expression
	_face_time_remaining = float(line.get("face_time", -1.0))
	_face_sprites.call("set_face_expression", expression)


func _restore_message_face() -> void:
	# Do not overwrite a newer expression set by gameplay while this line was open.
	if is_instance_valid(_face_sprites) and StringName(_face_sprites.get("face_expression")) == _dialogue_face:
		_face_sprites.call("set_face_expression", _previous_face)
	_face_sprites = null
	_dialogue_face = &""
	_face_time_remaining = -1.0


func _start_babble() -> void:
	_stop_babble()
	_babble = GlobalAudio.playSound(GlobalAudio.TALKING, true, -20.0)
	# Loop it so longer lines keep babbling until the last letter appears.
	if _babble != null:
		var stream: AudioStream = _babble.stream
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true


func _stop_babble() -> void:
	if is_instance_valid(_babble):
		_babble.stop()
		_babble.queue_free()
	_babble = null


func stop_talking() -> void:
	var was_talking := visible
	_stop_babble()
	_restore_message_face()
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
	if was_talking:
		line_finished.emit()


func _process(delta: float) -> void:
	# Face duration uses real frame time, independent of typewriter/reading time.
	if _face_time_remaining > 0.0:
		_face_time_remaining -= delta
		if _face_time_remaining <= 0.0:
			_restore_message_face()
	# Reveal the existing text rather than rebuilding the string every frame.
	var character_count := dialogue_text.get_total_character_count()
	if _revealed_characters < character_count:
		var typing_time := (character_count - _revealed_characters) / characters_per_second
		_revealed_characters = minf(_revealed_characters + delta * characters_per_second, character_count)
		dialogue_text.visible_characters = floori(_revealed_characters)
		if _revealed_characters >= character_count:
			# The whole line is showing, so the speaker stops talking.
			_stop_babble()
		# Only count down the reading time once the complete line is visible.
		delta = maxf(delta - typing_time, 0.0)
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		stop_talking()
