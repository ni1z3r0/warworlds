class_name Projectile
extends Node2D
## Artillery shell or Martian black-smoke canister in flight.

var from := Vector2.ZERO
var to := Vector2.ZERO
var kind := "shell"
var source: Node2D
var main: Node
var t := 0.0
var dur := 1.0


func _ready() -> void:
	z_index = 30
	dur = clampf(from.distance_to(to) / 650.0, 0.35, 1.2)


func _process(delta: float) -> void:
	t += delta / dur
	if t >= 1.0:
		main.on_projectile_land(self)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var ground := from.lerp(to, t)
	var h := sin(t * PI) * from.distance_to(to) * 0.22
	var p := ground - Vector2(0, h)
	draw_circle(ground, 3, Color(0, 0, 0, 0.4))
	if kind == "shell":
		var back := from.lerp(to, maxf(0.0, t - 0.06))
		var back_p := back - Vector2(0, sin(maxf(0.0, t - 0.06) * PI) * from.distance_to(to) * 0.22)
		draw_line(back_p, p, Color(1, 0.7, 0.3, 0.5), 2)
		draw_circle(p, 2.5, Color(1, 0.9, 0.6))
	else:
		draw_circle(p, 6, Color(0.05, 0.05, 0.05))
		draw_circle(p, 3, Color(0.3, 0.9, 0.4, 0.8))
		for k in 4:
			var tp := maxf(0.0, t - 0.03 * (k + 1))
			var q := from.lerp(to, tp) - Vector2(0, sin(tp * PI) * from.distance_to(to) * 0.22)
			draw_circle(q, 4 + k, Color(0.02, 0.02, 0.02, 0.4 - k * 0.08))
