extends Node

# All messages live in this one dictionary, listed in round order.
# Edit text, speaker, reading_time, and optional wait_time here.
# wait_time pauses an awaiting caller, starting when the line is shown.
# Optional face: default, happy, angry, sad_level_2.
# face_time is seconds from line start; omit it to keep the face until the line ends.

#await dialogue.play_line(&"NPCAccusation", -1.0, speaker)
var messages: Dictionary = {
	# Friend introduces the leader's demonstration.
	&"Introduction": {
		"text": "Watch him first. Then we'll copy his moves together.",
		"speaker": &"Friend1",
		"reading_time": 4.0,
		"wait_time": 4.0,
	},
	&"YourTurn": {
		"text": "Your turn!",
		"speaker": &"Leader",
		"reading_time": 1.2,
		"wait_time": 2.0,
	},
	# Only one of these outcomes plays after the response.
	&"Success": {
		"text": "See? You've got this.",
		"speaker": &"Friend1",
		"reading_time": 3.0,
		"face": &"happy",
		"face_time": 2.0,
	},
	# Failure exchange: the pointing NPC speaks, then Friend defends the player.
	# Gameplay replaces NPC1 with whichever NPC is actually pointing.
	&"NPCAccusation": {
		"text": "Hey you're messing up!",
		"speaker": &"NPC1",
		"reading_time": 2.0,
		"wait_time": 3.5,
		"face": &"angry",
		"face_time": 3.0,
	},
	&"FriendDefense": {
		"text": "Hey he's new don't shame him!",
		"speaker": &"Friend1",
		"reading_time": 3.0,
		"wait_time": 3.5,
		"face": &"angry",
		"face_time": 3.2,
	},
	&"TryAgain": {
		"text": "It's okay. Watch the timing - we'll try again.",
		"speaker": &"Friend1",
		"reading_time": 3.0,
		"wait_time": 3.5,
	},

	# --- Chapter 2: The Odd One Out ---
	&"ChapterTwoIntro": {
		"text": "New pattern. Keep up this time, everyone.",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.0,
	},
	# Gameplay replaces NPC1 with whichever NPC speaks first.
	&"OddAccusation": {
		"text": "Did you see that? They're always behind.",
		"speaker": &"NPC1",
		"reading_time": 2.5,
		"wait_time": 3.0,
		"face": &"smug",
		"face_time": 3.0,
	},
	# An NPC teaches pointing; the game waits until the player clicks anyone.
	# Gameplay replaces the speaker with a pointing NPC. reading_time keeps the hint up.
	&"PointTutorial": {
		"text": "Hey New kid! Point at this loser by left clicking on them.",
		"speaker": &"NPC2",
		"reading_time": 60.0,
		"face": &"smug",
		"face_time": 2.5,
	},
	&"PointThemOut": {
		"text": "Hey! You're pointing at the wrong person",
		"speaker": &"Leader",
		"reading_time": 5.5,
		"wait_time": 5.5,
	},
	# Pressure lines play one by one while the player refuses to point.
	# Gameplay replaces the speaker with the NPC who turns on the player.
	&"Pressure1": {
		"text": "Come on.",
		"speaker": &"NPC1",
		"reading_time": 2.0,
		"face": &"angry",
		"face_time": 2.0,
	},
	&"Pressure2": {
		"text": "Everyone's doing it.",
		"speaker": &"NPC2",
		"reading_time": 2.0,
		"face": &"angry",
		"face_time": 2.0,
	},
	&"Pressure3": {
		"text": "...Unless you're also a loser?",
		"speaker": &"NPC4",
		"reading_time": 2.5,
		"face": &"smug_2",
		"face_time": 2.5,
	},
	# The player pointed at the odd one out.
	&"GaveInLeader": {
		"text": "Good. Now you're one of us.",
		"speaker": &"Leader",
		"reading_time": 2.5,
		"wait_time": 3.0,
		"face": &"smug",
		"face_time": 2.5,
	},
	&"GaveInFriend": {
		"text": "...We just did what they did to you.",
		"speaker": &"Friend1",
		"reading_time": 4.0,
		"wait_time": 4.5,
		"face": &"sad_level_2",
	},
	# The player never pointed.
	&"HeldOutFriend": {
		"text": "...You're right. This isn't us.",
		"speaker": &"Friend1",
		"reading_time": 4.0,
		"wait_time": 4.5,
		"face": &"sad_level_1",
		"face_time": 3.0,
	},
	&"HeldOutHook": {
		"text": "Didn't point huh, you're not one of us loser!",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.5,
	},
}


func get_message(line_name: StringName) -> Dictionary:
	return messages.get(line_name, {})
