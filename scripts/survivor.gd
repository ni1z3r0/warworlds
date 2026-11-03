class_name Survivor
extends Unit
## A named civilian. Cannot fight: runs, hides in cellars, and tries to get out.

var coat := Color(0.35, 0.28, 0.22)
var cellar_target := Vector2.INF


func hide_at(cellar: Vector2) -> void:
	cellar_target = cellar
	in_cellar = false
	super.order_move(cellar)
	if path.is_empty():
		_on_arrived()


func order_move(target: Vector2) -> void:
	if in_cellar:
		main.log_msg("%s climbs out of the cellar." % display_name)
	cellar_target = Vector2.INF
	in_cellar = false
	super.order_move(target)


func _on_arrived() -> void:
	if cellar_target != Vector2.INF and position.distance_to(cellar_target) < 16.0:
		position = cellar_target
		in_cellar = true
		main.log_msg("%s hides in a cellar." % display_name)
		main.tripod.saw_hide(self)
		alert = 0.0


func status_text() -> String:
	if escaped:
		return "ESCAPED"
	if not alive:
		return "LOST - " + cause
	if in_smoke:
		return "CHOKING IN THE SMOKE!"
	if in_cellar:
		return "Hiding in a cellar"
	if alert >= 0.5:
		return "SPOTTED!"
	if moving:
		return "Running"
	return "Waiting"


func _draw() -> void:
	if not alive:
		draw_line(Vector2(-6, -1), Vector2(6, 2), Color(0.12, 0.06, 0.05), 4)
		draw_circle(Vector2(7, 2), 2.5, Color(0.12, 0.06, 0.05))
		return
	if in_cellar:
		var a := 0.5 + 0.5 * sin(_t * 2.0)
		draw_circle(Vector2(-2.5, 0), 1.3, Color(1, 0.9, 0.6, 0.6 * a))
		draw_circle(Vector2(2.5, 0), 1.3, Color(1, 0.9, 0.6, 0.6 * a))
		if selected:
			draw_arc(Vector2.ZERO, 13, 0, TAU, 28, Color(1, 0.85, 0.45, 0.6), 1.0)
		draw_string(font, Vector2(-60, -14), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(0.95, 0.82, 0.7, 0.4))
		return
	var bob := sin(_t * 14.0) * 1.0 if moving else 0.0
	draw_circle(Vector2(3, 4), 9, Color(0, 0, 0, 0.5))
	draw_circle(Vector2(0, bob), 8.5, Color(1.0, 0.85, 0.6, 0.85))
	draw_circle(Vector2(0, bob), 7.0, coat)
	draw_arc(Vector2(0, bob), 7.0, PI * 0.6, PI * 1.4, 10, Color(1.0, 0.55, 0.2, 0.8), 2.0)
	draw_circle(Vector2(0, bob) + facing * 3.0, 3.8, Color(0.92, 0.76, 0.62))
	if in_smoke and int(_t * 3.0) % 2 == 0:
		draw_string(font, Vector2(8, 10), "*cough*", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.9, 0.9, 0.7))
	_draw_overlay()
