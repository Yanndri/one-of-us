extends Node

# All messages live in this one dictionary, listed in round order.
# Edit text, speaker, reading_time, and optional wait_time here.
# wait_time pauses an awaiting caller, starting when the line is shown.
var messages: Dictionary = {
	# Friend introduces the leader's demonstration.
	&"Introduction": {
		"text": "Watch the leader's gestures and their timing.",
		"speaker": &"Friend1",
		"reading_time": 4.0,
		"wait_time": 4.0,
	},
	# Countdown runs in order using each wait_time. 4 is only used with Count In Beats = 4.
	#&"Countdown4": {"text": "4...", "speaker": &"Leader", "reading_time": 1.0, "wait_time": 1.0},
	#&"Countdown3": {"text": "3...", "speaker": &"Leader", "reading_time": 1.0, "wait_time": 1.0},
	#&"Countdown2": {"text": "2...", "speaker": &"Leader", "reading_time": 1.0, "wait_time": 1.0},
	#&"Countdown1": {"text": "1...", "speaker": &"Leader", "reading_time": 1.0, "wait_time": 1.0},
	&"YourTurn": {
		"text": "Your turn!",
		"speaker": &"Leader",
		"reading_time": 4.2,
		"wait_time": 5.0,
	},
	# Only one of these outcomes plays after the response.
	&"Success": {
		"text": "You matched the sequence. Well done!",
		"speaker": &"Friend1",
		"reading_time": 3.0,
	},
	&"TryAgain": {
		"text": "Try matching the gestures to the beat.",
		"speaker": &"Friend1",
		"reading_time": 3.0,
	},
}


func get_message(line_name: StringName) -> Dictionary:
	return messages.get(line_name, {})
