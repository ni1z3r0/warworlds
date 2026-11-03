class_name Unit
extends Node2D
## Base class for everything the player commands.

var world: World
var main: Node
var display_name := ""
var role := ""
var speed := 70.0
var selected := false
var alive := true
var escaped := false
var captured := false
var in_cellar := false
var hp := 1.0
var alert := 0.0          # how close the machine is to spotting this unit (0..1)
var in_smoke := false
var cause := ""
var path := PackedVector2Array()
var facing := Vector2.RIGHT
var moving := false
var font: Font
var _t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	z_index = 10


func order_move(target: Vector2) -> void:
	if not alive:
		return
	path = world.find_path(position, target)


func _process(delta: float) -> void:
	_t += delta
	if alive:
		_tick(delta)
		_follow_path(delta)
	queue_redraw()


func _tick(_delta: float) -> void:
	pass


func _follow_path(delta: float) -> void:
	moving = not path.is_empty()
	if path.is_empty():
		return
	var tgt: Vector2 = path[0]
	var d := tgt - position
	var step := speed * delta * _speed_mult()
	if d.length() <= step:
		position = tgt
		path.remove_at(0)
		if path.is_empty():
			_on_arrived()
	else:
		facing = d.normalized()
		position += facing * step


func _speed_mult() -> float:
	var m := 1.0
	if in_smoke:
		m *= 0.6
	if world.in_woods(position):
		m *= 0.8
	return m


func _on_arrived() -> void:
	pass


func can_be_seen() -> bool:
	return alive and not in_cellar and not escaped


func damage(amount: float, why: String) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		die(why)


func die(why: String) -> void:
	if not alive:
		return
	alive = false
	in_cellar = false
	cause = why
	path.clear()
	selected = false
	z_index = 2
	main.on_unit_died(self, why)


func status_text() -> String:
	return ""


func _draw_overlay() -> void:
	if not alive:
		return
	if selected:
		draw_arc(Vector2.ZERO, 13, 0, TAU, 28, Color(1, 0.85, 0.45, 0.95), 1.5)
	var col := Color(1, 0.92, 0.78, 0.95) if selected else Color(0.95, 0.82, 0.7, 0.55)
	draw_string(font, Vector2(-60, -17), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, col)
	if hp < 0.999:
		draw_rect(Rect2(-12, 12, 24, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-12, 12, 24 * maxf(hp, 0.0), 3), Color(0.9, 0.3, 0.2))
	if alert > 0.05 and not in_cellar:
		var c := Color(1, 0.85, 0.25).lerp(Color(1, 0.15, 0.1), alert)
		draw_arc(Vector2.ZERO, 17, -PI / 2, -PI / 2 + TAU * alert, 28, c, 2.0)
		draw_string(font, Vector2(14, -6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, c)
