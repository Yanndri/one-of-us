extends ColorRect

# Tints the screen with a different color for each chapter, fading between them.
# Chapter Colors: 1st entry is Chapter 1, 2nd is Chapter 2, and so on.
# Missing entries keep the last color. Alpha controls how strong the tint is.

@export var chapter_colors: Array[Color] = [
	Color(0, 0, 0, 0.19),
	Color(0.25, 0.1, 0.4, 0.22),
	Color(0.1, 0.15, 0.35, 0.25),
	Color(0.35, 0.05, 0.1, 0.25),
]
@export_range(0.0, 5.0, 0.1) var fade_duration: float = 1.0


func _ready() -> void:
	if not chapter_colors.is_empty():
		color = chapter_colors[0]


func set_chapter(chapter: int) -> void:
	if chapter_colors.is_empty():
		return
	var target := chapter_colors[clampi(chapter - 1, 0, chapter_colors.size() - 1)]
	create_tween().tween_property(self, "color", target, fade_duration)
