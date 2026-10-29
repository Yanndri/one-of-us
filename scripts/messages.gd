extends Node

# All messages live in this one dictionary, listed in round order.
# Edit text, speaker, reading_time, and optional wait_time here.
# wait_time pauses an awaiting caller, starting when the line is shown.
# Optional face: default, happy, angry, sad_level_2.
# face_time is seconds from line start; omit it to keep the face until the line ends.
# Text can use BBCode: bold, italic, [color=red]red[/color], [wave]wave[/wave], [shake]shake[/shake].

#await dialogue.play_line(&"NPCAccusation", -1.0, speaker)
var messages: Dictionary = {
	# Friend introduces the leader's demonstration.
	&"Introduction": {
		"text": "[u]Watch[/u] him first. Then we'll [u]copy[/u] his moves together.",
		"speaker": &"Friend1",
		"reading_time": 4.0,
		"wait_time": 4.0,
	},
	&"YourTurn": {
		"text": "[wave amp=30 freq=5]Your turn![/wave]",
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
		"text": "Hey, you're [color=#ff5555][shake rate=20 level=6]messing up[/shake][/color]!",
		"speaker": &"NPC1",
		"reading_time": 2.0,
		"wait_time": 3.5,
		"face": &"angry",
		"face_time": 3.0,
	},
	&"FriendDefense": {
		"text": "Hey, he's new! Don't [u]shame[/u] him!",
		"speaker": &"Friend1",
		"reading_time": 3.0,
		"wait_time": 3.5,
		"face": &"angry",
		"face_time": 3.2,
	},
	&"TryAgain": {
		"text": "It's okay. Watch the [u]timing[/u] - we'll try again.",
		"speaker": &"Friend1",
		"reading_time": 3.0,
		"wait_time": 3.5,
	},

	# Chapter 1 round lines. RoundController picks which round each one plays on.
	&"Ch1Round2": {
		"text": "[shake rate=25 level=8]Faster![/shake]",
		"speaker": &"Leader",
		"reading_time": 1.5,
		"wait_time": 1.5,
	},
	&"Ch1Round3": {
		"text": "Let's make this more [u]difficult[/u].",
		"speaker": &"Leader",
		"reading_time": 2.5,
		"wait_time": 2.5,
		"face": &"smug",
		"face_time": 2.5,
	},
	&"Ch1Round3Cleared": {
		"text": "Wow, you're doing [wave amp=30 freq=5]good[/wave]!",
		"speaker": &"Friend1",
		"reading_time": 2.5,
		"wait_time": 2.5,
		"face": &"happy",
		"face_time": 2.5,
	},

	# Chapter 1: after each cleared round, one more NPC points at the odd one out.
	# Gameplay replaces the speaker with the NPC who starts pointing.
	&"OddJoin1": {
		"text": "Ugh. They [color=#ff5555][shake rate=20 level=6]messed up[/shake][/color].",
		"speaker": &"NPC1",
		"reading_time": 2.5,
		"wait_time": 2.5,
		"face": &"smug",
		"face_time": 2.5,
	},
	&"OddJoin2": {
		"text": "Every [u]single[/u] time.",
		"speaker": &"NPC2",
		"reading_time": 2.5,
		"wait_time": 2.5,
		"face": &"smug",
		"face_time": 2.5,
	},
	&"OddJoin3": {
		"text": "...Yeah. I noticed they're [color=#ff5555][shake rate=20 level=6]messing up[/shake][/color]!",
		"speaker": &"NPC4",
		"reading_time": 2.5,
		"wait_time": 2.5,
	},
	# Everyone who can accuse is pointing at the player.
	&"GameOver": {
		"text": "That's it. You're [color=#ff5555]not one of us[/color].",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.5,
		"face": &"smug",
		"face_time": 3.0,
	},

	# --- Chapter 2: The Odd One Out ---
	&"ChapterTwoIntro": {
		"text": "Alright, good. All of you are [u]great followers[/u]. Let's keep going.",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.0,
	},
	# Gameplay replaces NPC1 with whichever NPC speaks first.
	&"OddAccusation": {
		"text": "Did you see that? They're [color=#ff5555][shake rate=20 level=6]always behind[/shake][/color].",
		"speaker": &"NPC1",
		"reading_time": 2.5,
		"wait_time": 3.0,
		"face": &"smug",
		"face_time": 3.0,
	},
	# An NPC teaches pointing; the game waits until the player clicks anyone.
	# Gameplay replaces the speaker with a pointing NPC. reading_time keeps the hint up.
	&"PointTutorial": {
		"text": "Hey, new kid! Point at this [color=#ff5555][shake rate=20 level=6]loser[/shake][/color] by [pulse freq=2.0 color=#ffffff40]left clicking[/pulse] on them.",
		"speaker": &"NPC2",
		"reading_time": 60.0,
		"face": &"smug",
		"face_time": 2.5,
	},
	&"PointThemOut": {
		"text": "Hey! You're pointing at the [u]wrong person[/u]!",
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
		"text": "[u]Everyone's[/u] doing it.",
		"speaker": &"NPC2",
		"reading_time": 2.0,
		"face": &"angry",
		"face_time": 2.0,
	},
	&"Pressure3": {
		"text": "...Unless you're also a [color=#ff5555][shake rate=20 level=6]loser[/shake][/color]?",
		"speaker": &"NPC4",
		"reading_time": 2.5,
		"face": &"smug_2",
		"face_time": 2.5,
	},
	# The player pointed at the odd one out.
	&"GaveInLeader": {
		"text": "Good. Now you're [u]one of us[/u].",
		"speaker": &"Leader",
		"reading_time": 2.5,
		"wait_time": 3.0,
		"face": &"smug",
		"face_time": 2.5,
	},
	&"GaveInFriend": {
		"text": "...I don't know how to feel about this.",
		"speaker": &"Friend1",
		"reading_time": 4.0,
		"wait_time": 4.5,
		"face": &"sad_level_2",
	},
	# Used instead when nobody ever pointed at the player.
	&"GaveInFriendNeverPointedAt": {
		"text": "...Imagine if that was [u]you[/u].",
		"speaker": &"Friend1",
		"reading_time": 4.0,
		"wait_time": 4.5,
		"face": &"sad_level_2",
	},
	# The player never pointed.
	# The player speaks up first, then Friend follows their lead.
	&"HeldOutPlayer": {
		"text": "I'm [u]not[/u] pointing at them.",
		"speaker": &"Player1",
		"reading_time": 2.5,
		"wait_time": 3.0,
	},
	&"HeldOutFriend": {
		"text": "Then I [u]won't[/u] either.",
		"speaker": &"Friend1",
		"reading_time": 4.0,
		"wait_time": 4.5,
		"face": &"sad_level_1",
		"face_time": 3.0,
	},
	&"HeldOutHook": {
		"text": "Didn't point, huh? You're [u]not one of us[/u], [color=#ff5555][shake rate=20 level=6]loser[/shake][/color]!",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.5,
	},

	# --- Chapter 3: Follow My Lead ---
	&"ChapterThreeIntro": {
		"text": "Again. And this time, nobody falls behind.",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.0,
	},
	# Round 1: Friend messes up, but nobody points yet.
	&"C3Worried": {
		"text": "...I can't keep up.",
		"speaker": &"Friend1",
		"reading_time": 2.5,
		"wait_time": 3.0,
		"face": &"sad_level_1",
	},
	&"C3FollowMyLead": {
		"text": "It's okay. Just [u]follow my lead[/u].",
		"speaker": &"Player1",
		"reading_time": 3.0,
		"wait_time": 3.0,
	},
	&"C3FriendAgrees": {
		"text": "...Okay. I'll follow you.",
		"speaker": &"Friend1",
		"reading_time": 2.5,
		"wait_time": 2.5,
	},
	# Help round: the group heckles while the player leads. Gameplay picks the speaker.
	&"C3Heckle": {
		"text": "[color=#ff5555][shake rate=20 level=6]Give up on them.[/shake][/color]",
		"speaker": &"NPC1",
		"reading_time": 2.0,
		"face": &"smug",
		"face_time": 2.0,
	},
	&"C3Again": {
		"text": "Again. I'm with you.",
		"speaker": &"Friend1",
		"reading_time": 2.5,
		"wait_time": 3.0,
	},
	# Help round failed and everyone has voted: the group wants the player to point at Friend.
	&"C3PointAtFriend": {
		"text": "Your friend can't keep up. [color=#ff5555][shake rate=20 level=6]Point at them.[/shake][/color]",
		"speaker": &"Leader",
		"reading_time": 10.0,
		"wait_time": 10.0,
		"face": &"smug",
		"face_time": 8.0,
	},
	# The player held out and everyone is pointing at them: they ask for one last try.
	&"C3OneMoreChance": {
		"text": "Give them [u]one more chance[/u].",
		"speaker": &"Player1",
		"reading_time": 2.5,
		"wait_time": 3.0,
	},
	&"C3LastChance": {
		"text": "[color=#ff5555][shake rate=20 level=6]One.[/shake][/color] More.",
		"speaker": &"Leader",
		"reading_time": 2.0,
		"wait_time": 2.5,
		"face": &"angry",
		"face_time": 2.0,
	},
	# The last chance failed too: Game Over.
	&"C3SingledOutForFriend": {
		"text": "You stood by them... and now [color=#ff5555][shake rate=20 level=6]you're[/shake][/color] the one outside.",
		"speaker": &"Leader",
		"reading_time": 3.5,
		"wait_time": 4.0,
		"face": &"smug",
		"face_time": 3.5,
	},
	# The player held out: another help round.
	&"C3StillWithMe": {
		"text": "...You're [u]still with me[/u]?",
		"speaker": &"Friend1",
		"reading_time": 2.5,
		"wait_time": 3.0,
	},
	# The player pointed at Friend.
	&"C3GaveInLeader": {
		"text": "See? That wasn't so hard.",
		"speaker": &"Leader",
		"reading_time": 2.5,
		"wait_time": 3.0,
		"face": &"smug",
		"face_time": 2.5,
	},
	&"C3FriendBetrayed": {
		"text": "...I thought you were [u]with me[/u].",
		"speaker": &"Friend1",
		"reading_time": 3.5,
		"wait_time": 4.0,
		"face": &"sad_level_3",
	},
	# Help round cleared.
	&"C3Thanks": {
		"text": "...I did it. Thanks for [u]not leaving me behind[/u].",
		"speaker": &"Friend1",
		"reading_time": 3.0,
		"wait_time": 3.5,
		"face": &"happy",
		"face_time": 3.0,
	},
	&"C3GroupSoftens": {
		"text": "...Huh. They kept up.",
		"speaker": &"NPC1",
		"reading_time": 2.5,
		"wait_time": 3.0,
	},
	&"C3LeaderReconsiders": {
		"text": "Fine. Everyone, [wave amp=30 freq=5]together[/wave].",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.5,
	},

	# --- Chapter 4: One of Us ---
	&"ChapterFourIntro": {
		"text": "Last one. Let's finish this together.",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.0,
	},
	# Path A: Friend is with you.
	&"C4Remember": {
		"text": "...Remember when [u]I[/u] couldn't keep up?",
		"speaker": &"Friend1",
		"reading_time": 3.0,
		"wait_time": 3.5,
	},
	&"C4LeaderFollowMyLead": {
		"text": "...It's okay. Just [u]follow my lead[/u].",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.5,
	},
	&"C4Together": {
		"text": "Everyone. [wave amp=30 freq=5]Together.[/wave]",
		"speaker": &"Leader",
		"reading_time": 2.5,
		"wait_time": 2.5,
	},
	&"C4Again": {
		"text": "Again. Nobody gets left behind.",
		"speaker": &"Leader",
		"reading_time": 2.5,
		"wait_time": 3.0,
	},
	&"C4EndingTogether": {
		"text": "See? There's room for [wave amp=30 freq=5]everyone[/wave].",
		"speaker": &"Friend1",
		"reading_time": 3.0,
		"wait_time": 3.5,
		"face": &"happy",
		"face_time": 3.0,
	},
	# Path B: Friend is gone.
	&"C4YouKnow": {
		"text": "You know what to do.",
		"speaker": &"Leader",
		"reading_time": 2.5,
		"wait_time": 1.0,
		"face": &"smug",
		"face_time": 2.5,
	},
	&"C4OneOfUsNow": {
		"text": "See? You're [color=#a45aef]one of us[/color] now.",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.5,
		"face": &"smug",
		"face_time": 3.0,
	},
	&"C4NotOneOfUs": {
		"text": "Then you're [color=#ff5555][shake rate=20 level=6]not one of us[/shake][/color].",
		"speaker": &"Leader",
		"reading_time": 3.0,
		"wait_time": 3.5,
		"face": &"angry",
		"face_time": 3.0,
	},
	# Reflection screen text, one per ending. Only "text" is used.
	&"ReflectionTogether": {
		"text": "One person who stays changes what the group does next.",
		"speaker": &"Leader",
		"reading_time": 1.0,
	},
	&"ReflectionOneOfUs": {
		"text": "Belonging shouldn't cost you who you are.",
		"speaker": &"Leader",
		"reading_time": 1.0,
	},
	&"ReflectionAlone": {
		"text": "Standing up is harder alone. It's never too late to stand with someone.",
		"speaker": &"Leader",
		"reading_time": 1.0,
	},
}


func get_message(line_name: StringName) -> Dictionary:
	return messages.get(line_name, {})
