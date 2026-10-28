extends Node

# Preloaded sounds can be reused anywhere through GlobalAudio.
const ERROR_MISTAKE: AudioStream = preload("res://assets/music/lesiakower-error-mistake-sound-effect-incorrect-answer-437420.mp3")
const CORRECT_BEAT: AudioStream = preload("res://assets/music/universfield-clear-bell-chime-487898.mp3")
const MISTAKE_SOUNDS: Array[AudioStream] = [ERROR_MISTAKE]


# Each sound gets its own player so simultaneous sounds do not cut each other off.
# Pass false as the second argument when you want the original pitch.
func playSound(sound_sfx: AudioStream, vary_pitch: bool = true, volume_db: float = 0.0) -> AudioStreamPlayer:
	if sound_sfx == null:
		return null
	var sound_player := AudioStreamPlayer.new()
	sound_player.stream = sound_sfx
	sound_player.volume_db = volume_db
	sound_player.pitch_scale = randomizePitch() if vary_pitch else 1.0
	add_child(sound_player)
	sound_player.finished.connect(sound_player.queue_free)
	sound_player.play()
	return sound_player


# Small pitch changes keep repeated effects varied without changing them too much.
func randomizePitch(min_pitch: float = 0.95, max_pitch: float = 1.05) -> float:
	var lower := maxf(0.01, minf(min_pitch, max_pitch))
	var upper := maxf(lower, maxf(min_pitch, max_pitch))
	return randf_range(lower, upper)


func playMistake() -> void:
	# Pick one effect per mistake rather than playing both on top of each other.
	playSound(MISTAKE_SOUNDS.pick_random())
