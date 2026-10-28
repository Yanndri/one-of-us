extends SubViewport

# Renders a separate character on transparency to create the rhythm-lane icons.
# Images stay in memory only; this script does not save files.

@onready var animation_player: AnimationPlayer = $Leader/AnimationPlayer

var pose_textures: Dictionary = {}


func capture_poses(character: Node2D = null) -> Dictionary:
	if character != null:
		# Reuse the same viewport for the player's design, without gameplay/input.
		var previous := get_child(0)
		remove_child(previous)
		previous.queue_free()
		var preview := character.duplicate(Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION) as Node2D
		preview.set_script(null)
		for group in preview.get_groups():
			preview.remove_from_group(group)
		preview.transform = Transform2D.IDENTITY
		preview.position = Vector2(128, 128)
		add_child(preview)
		animation_player = preview.get_node("AnimationPlayer")
		# Replace the dictionary so the already captured leader icons stay intact.
		pose_textures = {}
		await get_tree().process_frame
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
	var captured_images: Dictionary = {}
	var shared_bounds := Rect2i()
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
		captured_images[action] = image
		shared_bounds = bounds if not shared_bounds.has_area() else shared_bounds.merge(bounds)
	# Every pose uses the same framing, so wider hands do not shrink the body.
	# Keeping the same crop origin also prevents the character from shifting.
	shared_bounds = shared_bounds.grow(4).intersection(Rect2i(Vector2i.ZERO, size))
	for action in captured_images:
		pose_textures[action] = ImageTexture.create_from_image(captured_images[action].get_region(shared_bounds))
	# The cached images are independent; no further viewport rendering is needed.
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	return pose_textures
