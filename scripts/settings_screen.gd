extends Control

# Audio settings: one slider per bus. Volumes are saved by GlobalAudio and come back next time.
# Edit the layout in scenes/ui/settings_screen.tscn. Each slider goes from 0 (muted) to 1 (full).

signal closed

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var back_button: Button = %Back


func _ready() -> void:
	hide()
	for pair in [[master_slider, &"Master"], [music_slider, &"Music"], [sfx_slider, &"SFX"]]:
		var slider: HSlider = pair[0]
		var bus: StringName = pair[1]
		slider.value = GlobalAudio.getBusVolume(bus)
		slider.value_changed.connect(func(value: float) -> void: GlobalAudio.setBusVolume(bus, value))
	back_button.pressed.connect(func() -> void:
		GlobalAudio.saveVolumes()
		hide()
		closed.emit()
	)


func open() -> void:
	# Refresh in case volumes changed somewhere else.
	master_slider.set_value_no_signal(GlobalAudio.getBusVolume(&"Master"))
	music_slider.set_value_no_signal(GlobalAudio.getBusVolume(&"Music"))
	sfx_slider.set_value_no_signal(GlobalAudio.getBusVolume(&"SFX"))
	back_button.unlock()
	show()
	master_slider.grab_focus()
