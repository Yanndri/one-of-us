extends Control

# The closing screen after Chapter 4: one reflection line that matches the ending, and Play Again.
# Edit the layout and look in scenes/ui/reflection_screen.tscn; RoundController only sets the text.

@export_range(0.0, 3.0, 0.1) var fade_duration: float = 1.5

@onready var message: RichTextLabel = %Message
@onready var play_again: Button = %PlayAgain


func _ready() -> void:
	hide()
	play_again.pressed.connect(func() -> void: get_tree().reload_current_scene())


func show_reflection(text: String) -> void:
	message.text = text
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, fade_duration)
