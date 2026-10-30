extends Control

# The start menu on the table. Friend waves once each time START is hovered.
# RoundController waits for start_pressed, then hides the menu and starts the game.

signal start_pressed

# Friend's AnimationPlayer, for the wave.
@export var friend_animation_path: NodePath = ^"../../../Friend/AnimationPlayer"

@onready var start_button: Button = $VBoxContainer/START
@onready var friend_animation: AnimationPlayer = get_node_or_null(friend_animation_path)

var _waving: bool = false


func _ready() -> void:
	start_button.mouse_entered.connect(_wave_once)
	start_button.focus_entered.connect(_wave_once)
	start_button.pressed.connect(func() -> void:
		hide()
		start_pressed.emit()
	)


func _wave_once() -> void:
	# Staying on the button doesn't repeat the wave, and a wave never restarts while playing.
	if friend_animation == null or _waving or not visible:
		return
	_waving = true
	_play_pose(&"wave")
	await friend_animation.animation_finished
	_play_pose(&"default")
	_waving = false


func _play_pose(animation: StringName) -> void:
	# Clear hand offsets left by the previous pose, the same way RoundController does.
	friend_animation.stop()
	friend_animation.play("RESET")
	friend_animation.advance(0.0)
	friend_animation.stop()
	friend_animation.play(animation)
	friend_animation.advance(0.0)
