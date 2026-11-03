class_name Blast
extends Node2D
## One-shot explosion / heat-ray impact flash.

var color := Color(1, 0.6, 0.2)
var size := 40.0
var life := 0.6
var t := 0.0


func _ready() -> void:
	z_index = 35


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / life
	var a := 1.0 - k
	draw_circle(Vector2.ZERO, size * (0.3 + k), Color(color.r, color.g, color.b, 0.25 * a))
	draw_circle(Vector2.ZERO, size * 0.5 * (1.0 - k * 0.5), Color(1, 0.95, 0.8, 0.7 * a))
	draw_arc(Vector2.ZERO, size * (0.4 + k * 1.2), 0, TAU, 32, Color(color.r, color.g, color.b, 0.8 * a), 3)
