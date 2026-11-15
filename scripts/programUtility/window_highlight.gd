extends Node2D

@export var border_color := Color(0.2, 0.85, 1.0, 0.9)
@export var border_width := 3.0

func _ready() -> void:
	visible = false

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:

	var window_size := get_viewport_rect().size

	var rect := Rect2(
		Vector2.ZERO,
		window_size
	)

	draw_rect(
		rect,
		border_color,
		false,
		border_width
	)
