extends RichTextLabel

# The chapter title in the corner. announce() plays the title card: the label grows to the
# middle of the screen, swaps its text, holds, then goes back to where you placed it.
# It grows by font size rather than scale, so the letters stay sharp at every size.

@export var title_scale: float = 2.5
@export_range(0.1, 2.0, 0.05) var move_duration: float = 0.6
@export_range(0.0, 5.0, 0.1) var hold: float = 1.5

const FONT_SIZES: Array[StringName] = [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size", &"mono_font_size"]


func announce(new_text: String) -> void:
	var home_position := position
	var home_size := size
	var home_z := z_index
	var home_wrap := autowrap_mode
	var base_font_size := get_theme_font_size(&"normal_font_size")
	# Draw above the characters, and keep the title on one line while it's big.
	z_index = 100
	autowrap_mode = TextServer.AUTOWRAP_OFF
	var grow := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.tween_method(_set_title_card.bind(home_position, base_font_size), 0.0, 1.0, move_duration)
	await grow.finished
	text = new_text
	_set_title_card(1.0, home_position, base_font_size)
	await get_tree().create_timer(hold).timeout
	var back := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	back.tween_method(_set_title_card.bind(home_position, base_font_size), 1.0, 0.0, move_duration)
	await back.finished
	for font_size in FONT_SIZES:
		remove_theme_font_size_override(font_size)
	autowrap_mode = home_wrap
	position = home_position
	size = home_size
	z_index = home_z


func _set_title_card(t: float, home_position: Vector2, base_font_size: int) -> void:
	# t = 0 is the label's normal place and size; t = 1 is big and centered on the screen.
	var font_size := roundi(lerpf(base_font_size, base_font_size * title_scale, t))
	for font_name in FONT_SIZES:
		add_theme_font_size_override(font_name, font_size)
	reset_size()
	var centered := get_parent_area_size() / 2.0 - size / 2.0
	position = home_position.lerp(centered, t)
