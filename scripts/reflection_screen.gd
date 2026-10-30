extends Control

# A full-screen message with one button: the reflection after an ending (Play Again),
# or Game Over (Try Again). Edit the layout and look in scenes/ui/reflection_screen.tscn;
# RoundController only sets the text and what the button does.

@export_range(0.0, 3.0, 0.1) var fade_duration: float = 1.5

@onready var message: RichTextLabel = %Message
@onready var play_again = %PlayAgain

# What the button does this time. By default it starts the whole game again.
var _on_pressed: Callable


func _ready() -> void:
	hide()
	play_again.pressed.connect(func() -> void:
		if _on_pressed.is_valid():
			_on_pressed.call()
		else:
			get_tree().reload_current_scene()
	)


func show_reflection(text: String, button_text: String = "Play again", on_pressed: Callable = Callable()) -> void:
	message.text = text
	play_again.get_node("RichTextLabel").text = button_text
	play_again.unlock()
	_on_pressed = on_pressed
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, fade_duration)
