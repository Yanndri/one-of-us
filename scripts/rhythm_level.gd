extends Resource

# One entry per beat, in order. Repeats are allowed; rest means no input.
# Supported gestures: clap, peace, hands_up, rock, rest.
@export var gestures: Array[StringName] = [&"clap"]
@export_range(40.0, 200.0, 1.0) var bpm: float = 60.0
@export_range(0.0, 5.0, 0.1) var start_delay: float = 2.0
@export_range(0, 4, 1) var count_in_beats: int = 3
@export_range(0.05, 0.2, 0.01) var input_window: float = 0.15
