class_name HousePerson
extends Node2D
## The Narrator or the Curate, seen from above.

var coat := Color(0.25, 0.25, 0.28)
var collar := false          # the curate's white collar
var label := ""
var facing := Vector2.LEFT
var moving := false
var down := false            # knocked down / lying still
var in_coal := false          # buried in the coal
var shout := 0.0             # >0 while shouting (draws sound rings)
var speech := ""
var speech_t := 0.0
var font: Font
var _t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	z_index = 10


func say(text: String, secs: float = 3.5) -> void:
	speech = text
	speech_t = secs


func _process(delta: float) -> void:
	_t += delta
	speech_t = maxf(0.0, speech_t - delta)
	shout = maxf(0.0, shout - delta)
	queue_redraw()


func _draw() -> void:
	if in_coal:
		var a := 0.4 + 0.3 * sin(_t * 2.0)
		draw_circle(Vector2(-3, 0), 1.6, Color(1, 0.95, 0.8, a))
		draw_circle(Vector2(3, 0), 1.6, Color(1, 0.95, 0.8, a))
		return
	draw_circle(Vector2(3, 4), 11, Color(0, 0, 0, 0.4))
	if down:
		draw_line(Vector2(-12, 2), Vector2(10, -2), coat, 10.0)
		draw_circle(Vector2(13, -3), 5.0, Color(0.85, 0.72, 0.6))
		return
	var bob := sin(_t * 12.0) * 1.2 if moving else 0.0
	draw_circle(Vector2(0, bob), 10.5, Color(0.95, 0.85, 0.6, 0.9))
	draw_circle(Vector2(0, bob), 9.0, coat)
	if collar:
		draw_arc(Vector2(0, bob) + facing * 2.0, 5.5, facing.angle() - 1.2, facing.angle() + 1.2, 10, Color(1, 1, 1), 2.5)
	var hair := Color(0.85, 0.75, 0.45) if collar else Color(0.15, 0.1, 0.08)
	draw_circle(Vector2(0, bob) + facing * 3.0, 5.2, Color(0.88, 0.74, 0.62))
	draw_arc(Vector2(0, bob) + facing * 3.0, 5.2, facing.angle() + 1.6, facing.angle() + 4.7, 10, hair, 3.0)
	if shout > 0.0:
		for k in 3:
			var r := 18.0 + fmod(_t * 60.0 + k * 20.0, 60.0)
			draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color(1, 0.5, 0.3, 0.6 * (1.0 - (r - 18.0) / 60.0)), 2.0)
	draw_string(font, Vector2(-60, -18), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(1, 0.92, 0.8, 0.7))
	if speech_t > 0.0:
		var a := minf(1.0, speech_t)
		var tw := font.get_string_size(speech, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var box := Rect2(Vector2(-tw * 0.5 - 8, -54), Vector2(tw + 16, 24))
		draw_rect(box, Color(0.95, 0.9, 0.78, 0.92 * a))
		draw_rect(box, Color(0.1, 0.07, 0.05, a), false, 1.5)
		draw_string(font, box.position + Vector2(8, 17), speech, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.07, 0.05, a))
