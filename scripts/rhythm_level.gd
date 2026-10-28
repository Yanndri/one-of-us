extends Resource

const Gesture = preload("res://scripts/rhythm_gesture.gd")

# Expand each entry to set its gesture, tick width, and timeline position.
# The pass lasts gestures.size() beats; positions control where actions happen.
@export var gestures: Array[Gesture] = []
@export_range(5.0, 200.0, 1.0) var bpm: float = 60.0
@export_range(0.0, 5.0, 0.1) var start_delay: float = 2.0
@export_range(0.05, 0.2, 0.01) var input_window: float = 0.15


func resolve_gestures() -> Array[Dictionary]:
	# Resolve randomness once, then share these positions across both passes.
	var resolved: Array[Dictionary] = []
	for index in gestures.size():
		var entry := gestures[index]
		if entry == null:
			return []
		var progress := clampf(entry.position_percent / 100.0, 0.0, 1.0)
		if entry.randomize_position:
			# Vary within its beat slot, leaving space for adjacent gestures to finish.
			progress = (index + randf_range(0.4, 0.6)) / gestures.size()
		resolved.append({
			"gesture": StringName(entry.gesture),
			"progress": progress,
			"tick_thickness": entry.tick_thickness,
		})
	# Fixed positions may be entered in any order; playback follows the timeline.
	resolved.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.progress < b.progress)
	return resolved
