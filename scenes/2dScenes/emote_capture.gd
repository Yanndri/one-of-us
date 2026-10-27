extends SubViewport

# Renders a separate leader on transparency to create the rhythm-lane icons.
# Images stay in memory only; this script does not save files.

@onready var animation_player: AnimationPlayer = $Leader/AnimationPlayer

var pose_textures: Dictionary = {}


func capture_poses() -> Dictionary:
	if not pose_textures.is_empty():
		return pose_textures
	# Capture recognizable moments, not the neutral first frame of each gesture.
	var poses := {
		&"clap": {"animation": &"clap", "time": 0.2},
		&"hands_up": {"animation": &"hands_up", "time": 0.25},
		&"peace": {"animation": &"peace", "time": 0.34},
		&"rock": {"animation": &"rock", "time": 0.3},
		&"rest": {"animation": &"default", "time": 0.0},
	}
	for action in poses:
		animation_player.play("RESET")
		animation_player.advance(0.0)
		animation_player.play(poses[action]["animation"])
		animation_player.seek(poses[action]["time"], true)
		animation_player.pause()
		render_target_update_mode = SubViewport.UPDATE_ONCE
		# Read the image only after the GPU has rendered the requested pose.
		await RenderingServer.frame_post_draw
		var image := get_texture().get_image()
		if image == null or image.is_empty():
			push_warning("Could not capture emote: " + str(action))
			continue
		var bounds := image.get_used_rect()
		if not bounds.has_area():
			push_warning("Emote capture was blank: " + str(action))
			continue
		bounds = bounds.grow(4).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		pose_textures[action] = ImageTexture.create_from_image(image.get_region(bounds))
	# The cached images are independent; no further viewport rendering is needed.
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	return pose_textures
