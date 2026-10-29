extends Node2D

# A row of pointing hands above a character's head, one per vote against them.
# Edit the VoteIcon child in the scene (texture, scale, rotation, offset); every vote uses it.
# Gameplay calls show_votes(count); the row stays centered, so any number of votes fits.

@export var spacing: float = 24.0

@onready var icon_template: Sprite2D = $VoteIcon
@onready var _center_x: float = icon_template.position.x

var _icons: Array[Sprite2D] = []


func _ready() -> void:
	_icons.append(icon_template)
	# Nobody has votes until RoundController says so.
	show_votes(0)


func show_votes(count: int) -> void:
	count = maxi(count, 0)
	# Extra votes reuse copies of the VoteIcon you edited in the scene.
	while _icons.size() < count:
		var icon := icon_template.duplicate() as Sprite2D
		add_child(icon)
		_icons.append(icon)
	var start_x := _center_x - spacing * (count - 1) * 0.5
	for index in _icons.size():
		_icons[index].visible = index < count
		_icons[index].position.x = start_x + spacing * index
