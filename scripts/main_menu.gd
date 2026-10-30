extends Control

# The start menu on the table. Friend waves once each time START is hovered.
# RoundController waits for start_pressed, then hides the menu and starts the game.

signal start_pressed

# Friend's AnimationPlayer, for the wave.
@export var friend_animation_path: NodePath = ^"../../../Friend/AnimationPlayer"

@onready var main_menu: Control = $MainMenu
@onready var settings_panel: Control = $SettingsPanel
@onready var start_button: Button = $MainMenu/START
@onready var settings_button: Button = $MainMenu/SETTINGS
@onready var settings_back_button: Button = $SettingsPanel/BACK
@onready var credits_panel: Control = $CreditsPanel
@onready var credits_button: Button = $MainMenu/CREDITS
@onready var credits_back_button: Button = $CreditsPanel/BACK
@onready var friend_animation: AnimationPlayer = get_node_or_null(friend_animation_path)

var _waving: bool = false


func _ready() -> void:
	# Always open on the main buttons, whichever panel was left visible in the editor.
	main_menu.show()
	settings_panel.hide()
	credits_panel.hide()
	start_button.mouse_entered.connect(_wave_once)
	start_button.focus_entered.connect(_wave_once)
	start_button.pressed.connect(func() -> void:
		hide()
		start_pressed.emit()
	)
	settings_button.pressed.connect(_open_settings)
	settings_back_button.pressed.connect(_close_settings)
	credits_button.pressed.connect(_open_credits)
	credits_back_button.pressed.connect(_close_credits)
	# Each slider controls one audio bus, from 0 (muted) to 1 (full).
	for pair in [[%MasterSlider, &"Master"], [%MusicSlider, &"Music"], [%SFXSlider, &"SFX"]]:
		var slider: HSlider = pair[0]
		var bus: StringName = pair[1]
		slider.value = GlobalAudio.getBusVolume(bus)
		slider.value_changed.connect(func(value: float) -> void: GlobalAudio.setBusVolume(bus, value))


func _open_settings() -> void:
	main_menu.hide()
	settings_panel.show()
	settings_back_button.unlock()
	%MasterSlider.grab_focus()


func _close_settings() -> void:
	GlobalAudio.saveVolumes()
	settings_panel.hide()
	main_menu.show()
	settings_button.unlock()
	settings_button.grab_focus()


func _open_credits() -> void:
	main_menu.hide()
	credits_panel.show()
	credits_back_button.unlock()
	credits_back_button.grab_focus()


func _close_credits() -> void:
	credits_panel.hide()
	main_menu.show()
	credits_button.unlock()
	credits_button.grab_focus()


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
