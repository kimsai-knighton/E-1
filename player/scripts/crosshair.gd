extends Control

@export var dot_radius: float = 1.5
@export var main_color: Color = Color.WHITE

var is_hovering: bool = false:
	set(value):
		if is_hovering != value:
			is_hovering = value
			queue_redraw()

func _draw():
	if is_hovering:
		draw_circle(Vector2.ZERO, dot_radius+1, main_color)
	else:
		draw_circle(Vector2.ZERO, dot_radius, main_color)
		
