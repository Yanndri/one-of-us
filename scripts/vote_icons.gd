extends Node2D

# Pointing hands around a character's head, one per vote against them.
# Place VoteIcon1st, VoteIcon2nd, VoteIcon3rd... in the scene however you like; each vote fills the next one.
# The highest-numbered icon is the last fixed spot: votes beyond it line up in a row with it,
# centered on where it sits. Add or remove numbered icons freely; nothing else needs to change.
# Each icon takes the voter's own pointing-hand texture, so its color shows who voted.

# Gap between the last icon and the extra icons that line up with it.
@export var spacing: float = 24.0

# Your numbered icons in vote order (1st, 2nd, 3rd...).
var _placed_icons: Array[Sprite2D] = []
# Copies of the last placed icon, for votes beyond it.
var _extra_icons: Array[Sprite2D] = []
var _last_position: Vector2


func _ready() -> void:
	for child in get_children():
		if child is Sprite2D and child.name.begins_with("VoteIcon") and child.name.to_int() > 0:
			_placed_icons.append(child)
	# "VoteIcon12th".to_int() is 12, so this sorts by the number in the name.
	_placed_icons.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.name.to_int() < b.name.to_int())
	if not _placed_icons.is_empty():
		_last_position = _placed_icons.back().position
	# Nobody has votes until RoundController says so.
	show_votes([])


func show_votes(voter_textures: Array[Texture2D]) -> void:
	if _placed_icons.is_empty():
		return
	var count := voter_textures.size()
	var last := _placed_icons.back() as Sprite2D
	for index in _placed_icons.size():
		_placed_icons[index].visible = index < count
	# The last placed icon and every extra share one row, centered on the last icon's spot.
	var row_size := maxi(count - (_placed_icons.size() - 1), 1)
	while _extra_icons.size() < row_size - 1:
		var icon := last.duplicate() as Sprite2D
		add_child(icon)
		_extra_icons.append(icon)
	var start_x := _last_position.x - spacing * (row_size - 1) * 0.5
	last.position.x = start_x
	for index in _extra_icons.size():
		_extra_icons[index].visible = index < row_size - 1
		_extra_icons[index].position = Vector2(start_x + spacing * (index + 1), _last_position.y)
	# Vote order: your numbered icons, then the extras.
	var ordered: Array[Sprite2D] = _placed_icons.duplicate()
	ordered.append_array(_extra_icons)
	for index in mini(count, ordered.size()):
		if voter_textures[index] != null:
			ordered[index].texture = voter_textures[index]
