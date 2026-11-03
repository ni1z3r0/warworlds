class_name BlackSmoke
extends Node2D
## Wells' black smoke: a heavy poison cloud that spreads, drifts, and sinks
## into low places. Deadlier to anyone hiding in a cellar.

const MAX_R := 135.0
const LIFE := 24.0

var t := 0.0
var blobs: Array[Vector3] = []
var drift := Vector2(6, 2)


func _ready() -> void:
	z_index = 25
	for i in 22:
		blobs.append(Vector3(randf() * TAU, sqrt(randf()), randf_range(0.5, 1.0)))


func radius() -> float:
	var grow := clampf(t / 4.0, 0.0, 1.0)
	var fade := clampf((LIFE - t) / 5.0, 0.0, 1.0)
	return MAX_R * grow * (0.6 + 0.4 * fade)


func alpha() -> float:
	return clampf((LIFE - t) / 5.0, 0.0, 1.0)


func _process(delta: float) -> void:
	t += delta
	position += drift * delta
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var r := radius()
	var a := alpha()
	draw_circle(Vector2.ZERO, r * 1.1, Color(0.02, 0.02, 0.02, 0.35 * a))
	for b in blobs:
		var ang := b.x + t * 0.15 * (b.z - 0.7)
		var p := Vector2(cos(ang), sin(ang)) * b.y * r * 0.75
		draw_circle(p, r * 0.32 * b.z, Color(0.03, 0.03, 0.035, 0.45 * a))
	draw_circle(Vector2.ZERO, r * 0.5, Color(0.01, 0.01, 0.01, 0.4 * a))
