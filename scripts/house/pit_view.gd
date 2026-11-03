extends Node2D
## Outside the hole: the Martians' pit, the crab-like handling-machine at
## work ("a Briareus of a handling-machine"), and a fighting-machine standing
## on the far edge, styled after Alvim Corrêa.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var gone: bool = get_parent().martians_gone
	var ink := Color(0.06, 0.05, 0.04)
	# the handling-machine, many-armed, working
	var c := Vector2(1290, 470)
	if not gone:
		draw_circle(c + Vector2(6, 8), 34, Color(0, 0, 0, 0.35))
		for k in 6:
			var a := k * TAU / 6.0 + sin(_t * 1.5 + k) * 0.3
			var elbow := c + Vector2.from_angle(a) * 46.0
			var hand := elbow + Vector2.from_angle(a + 0.9 * sin(_t * 2.0 + k * 1.3)) * 40.0
			draw_line(c, elbow, ink, 6.0)
			draw_line(elbow, hand, ink, 4.0)
			draw_line(c, elbow, Color(0.45, 0.4, 0.35), 2.0)
			draw_circle(elbow, 4.0, Color(0.3, 0.27, 0.24))
			for f in 3:
				draw_line(hand, hand + Vector2.from_angle(a + (f - 1) * 0.5) * 10.0, ink, 2.0)
		draw_circle(c, 28, Color(0.32, 0.28, 0.24))
		draw_arc(c, 28, 0, TAU, 24, ink, 3.0)
		draw_circle(c + Vector2(-16, 0), 7, Color(0.5, 1.0, 0.6, 0.8 + 0.2 * sin(_t * 3.0)))
	# a fighting-machine standing on the far edge of the pit
	var m := Vector2(1480, 230)
	for k in 3:
		var a := PI * 0.3 + k * TAU / 3.0
		draw_line(m, m + Vector2.from_angle(a) * 70.0, ink, 3.0)
	draw_set_transform(m, 0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 34, ink)
	draw_circle(Vector2.ZERO, 31, Color(0.38, 0.33, 0.28) if not gone else Color(0.25, 0.22, 0.2))
	draw_circle(Vector2.ZERO, 14, Color(0.45, 0.4, 0.34))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_line(m, m + Vector2(0, -20), ink, 2.0)
	for side in [-1.0, 1.0]:
		draw_circle(m + Vector2(-26, side * 8), 5, Color(0.92, 0.9, 0.82) if not gone else Color(0.4, 0.38, 0.35))
		draw_circle(m + Vector2(-28, side * 8), 2.2, ink)
	for k in 10:
		var x := -26.0 + k * 6.0
		draw_line(m + Vector2(x, 14), m + Vector2(x + sin(_t + k) * 2.0, 44), Color(0.1, 0.08, 0.07, 0.8), 1.0)
	if gone:
		# the red weed has grown across the hole
		for k in 18:
			var p := Vector2(1062 + (k % 3) * 9, 445 + k * 4)
			draw_line(p, p + Vector2(18 + sin(k * 1.7) * 6, sin(k) * 10), Color(0.7, 0.12, 0.08), 3.0)
