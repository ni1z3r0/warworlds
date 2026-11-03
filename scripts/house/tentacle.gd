class_name Tentacle
extends Node2D
## A handling-machine's tentacle searching the house: "like an elephant's
## trunk more than anything else... like a black worm swaying its blind head
## to and fro." It reaches in through the hole, follows the rooms to where it
## heard something, gropes about, and withdraws.

enum T { IN, SEARCH, OUT, DONE }

var map: HouseMap
var state: T = T.IN
var route := PackedVector2Array()   # from the hole to the target
var reach := 0.0                     # distance along the route
var tip := Vector2.ZERO
var search_t := 0.0
var holding: Node2D = null           # whatever it has gripped
var speed := 95.0
var _t := 0.0
var _route_len := 0.0


func start(m: HouseMap, target: Vector2) -> void:
	map = m
	route = map.path(map.hole + Vector2(20, 0), target, true)
	if route.is_empty():
		route = PackedVector2Array([map.hole, target])
	route.insert(0, map.hole + Vector2(60, 0))
	_route_len = 0.0
	for i in range(1, route.size()):
		_route_len += route[i - 1].distance_to(route[i])
	tip = route[0]
	z_index = 30


func point_at(d: float) -> Vector2:
	var acc := 0.0
	for i in range(1, route.size()):
		var seg := route[i - 1].distance_to(route[i])
		if acc + seg >= d:
			return route[i - 1].lerp(route[i], (d - acc) / maxf(seg, 0.001))
		acc += seg
	return route[route.size() - 1]


func _process(delta: float) -> void:
	_t += delta
	match state:
		T.IN:
			reach = minf(_route_len, reach + speed * delta)
			tip = point_at(reach)
			if reach >= _route_len:
				state = T.SEARCH
				search_t = 4.5
		T.SEARCH:
			search_t -= delta
			var end := route[route.size() - 1]
			tip = end + Vector2(sin(_t * 2.3) * 34.0, cos(_t * 1.7) * 26.0)
			if search_t <= 0.0:
				state = T.OUT
		T.OUT:
			reach = maxf(0.0, reach - speed * 1.6 * delta)
			tip = point_at(reach)
			if reach <= 0.0:
				state = T.DONE
	if holding and is_instance_valid(holding):
		holding.position = tip
	queue_redraw()


func _draw() -> void:
	var pts := PackedVector2Array()
	var n := int(reach / 12.0) + 2
	for k in n:
		var d := reach * k / float(n - 1)
		var p := point_at(d)
		var wob := sin(_t * 4.0 + k * 0.6) * 4.0 * (float(k) / n)
		pts.append(p + Vector2(0, wob))
	if state == T.SEARCH:
		pts.append(tip)
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(0.02, 0.02, 0.02), 13.0, true)
	draw_polyline(pts, Color(0.2, 0.18, 0.16), 9.0, true)
	for k in range(1, pts.size(), 2):
		draw_circle(pts[k], 5.0, Color(0.3, 0.27, 0.24))
	draw_circle(pts[pts.size() - 1], 8.0, Color(0.08, 0.07, 0.06))
	draw_circle(pts[pts.size() - 1] + Vector2(2, -2), 3.0, Color(0.5, 0.9, 0.55, 0.7))
