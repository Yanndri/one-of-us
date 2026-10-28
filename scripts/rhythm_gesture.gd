class_name RhythmGesture
extends Resource

# One editable entry in Level > Gestures.
@export_enum("clap", "peace", "hands_up", "rock", "rest") var gesture: String = "clap"
@export_range(1.0, 32.0, 0.5) var tick_thickness: float = 4.0
@export var randomize_position: bool = false
@export_range(0.0, 100.0, 0.1, "suffix:%") var position_percent: float = 50.0
