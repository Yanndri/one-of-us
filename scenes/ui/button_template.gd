extends Button

# Shared button for every menu: click and hover sounds, a small grow on hover,
# a squash when pressed, and an optional click-once lock.
# Set the text with Label Text; style and sounds live in button_template.tscn.

# Lock the button after one press (for Start, Try again...). Call unlock() to use it again.
@export var click_once: bool = false
@export var hover_scale: float = 1.08
@export var press_scale: float = 0.95
@export_range(0.01, 0.5, 0.01) var tween_duration: float = 0.1

@onready var label: RichTextLabel = $RichTextLabel
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var hover_sound: AudioStreamPlayer = $HoverSound

var _scale_tween: Tween


func _ready() -> void:
	# Grow and squash from the center, even if the size changes.
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = size / 2.0
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))
	button_down.connect(func() -> void: _scale_to(press_scale))
	button_up.connect(func() -> void: _scale_to(hover_scale if is_hovered() else 1.0))
	pressed.connect(_on_pressed)


func unlock() -> void:
	disabled = false
	_scale_to(1.0)


func _on_hover(hovering: bool) -> void:
	if disabled:
		return
	if hovering:
		hover_sound.play()
	_scale_to(hover_scale if hovering else 1.0)


func _on_pressed() -> void:
	click_sound.play()
	if click_once:
		disabled = true


func _scale_to(target: float) -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * target, tween_duration)
