class_name HouseMap
extends Node2D
## The ruined house at Sheen (Book Two, chapters I-V), seen from above.
## The fifth cylinder has buried it: the kitchen is half-filled with garden
## mould, the floors are "covered with smashed crockery", and a triangular
## hole in the scullery wall looks straight into the Martians' pit.

const W := 1600
const H := 900
const CELL := 10
const COLS := 160   # W / CELL
const ROWS := 90    # H / CELL

## Solid walls and rubble.
var walls: Array[Rect2] = [
	Rect2(220, 140, 840, 18), Rect2(220, 792, 840, 18),                 # north, south
	Rect2(220, 140, 18, 670),                                          # west
	Rect2(1042, 140, 18, 300), Rect2(1042, 520, 18, 290),              # east, around the hole
	Rect2(420, 158, 18, 162), Rect2(682, 158, 18, 162),                # pantry sides
	Rect2(420, 302, 100, 18), Rect2(580, 302, 120, 18),                # pantry south (door 520-580)
	Rect2(700, 158, 342, 142),                                          # collapsed store room
	Rect2(820, 300, 18, 140), Rect2(820, 500, 18, 140),                # kitchen | scullery (door 440-500)
	Rect2(420, 320, 18, 80), Rect2(420, 470, 18, 170),                 # hall | kitchen (door 400-470)
	Rect2(238, 640, 182, 18), Rect2(480, 640, 362, 18),                # cellar north (door 420-480)
	Rect2(838, 640, 204, 18),                                          # scullery south
	Rect2(560, 658, 18, 134), Rect2(578, 658, 464, 134),               # cellar east, collapsed
	Rect2(250, 160, 150, 110),                                          # hall: earth banked in
	Rect2(440, 470, 110, 60),                                           # kitchen: mound of garden mould
]
## The rubble that plugs the hole until the pit is empty.
var hole_plug := Rect2(1042, 440, 18, 80)
var hole_open := false

var crockery: Array[Rect2] = [Rect2(470, 340, 150, 110), Rect2(620, 540, 170, 90), Rect2(860, 570, 110, 60), Rect2(300, 420, 100, 90)]
var pantry_shelf := Vector2(560, 190)
var coal_heap := Vector2(300, 735)
var peephole := Vector2(1022, 342)
var hole := Vector2(1051, 480)
var copper := Vector2(985, 600)
var chopper := Vector2(452, 352)
var escape_zone := Rect2(1080, 400, 120, 160)
## The green light from the pit falls through the hole in two pools: across
## the scullery, and in a narrow band through the door into the kitchen.
var light_polys: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(1046, 452), Vector2(1046, 508), Vector2(840, 580), Vector2(840, 395)]),
	PackedVector2Array([Vector2(840, 445), Vector2(840, 495), Vector2(640, 540), Vector2(640, 405)]),
]

var astar := AStarGrid2D.new()
var font: Font
var _rng := RandomNumberGenerator.new()
var _bits: Array[Dictionary] = []


func _ready() -> void:
	font = ThemeDB.fallback_font
	_rng.seed = 15
	for r in crockery:
		for k in 26:
			_bits.append({"p": r.position + Vector2(_rng.randf() * r.size.x, _rng.randf() * r.size.y),
				"a": _rng.randf() * TAU, "s": _rng.randf_range(3, 7)})
	_build_nav()


func open_hole() -> void:
	hole_open = true
	_build_nav()
	queue_redraw()


func solid(p: Vector2, r: float = 0.0) -> bool:
	for w in walls:
		if w.grow(r).has_point(p):
			return true
	if not hole_open and hole_plug.grow(r).has_point(p):
		return true
	return false


func in_light(p: Vector2) -> bool:
	for poly in light_polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func on_crockery(p: Vector2) -> bool:
	for r in crockery:
		if r.has_point(p):
			return true
	return false


## Move a circle by `delta`, sliding along walls.
func slide(p: Vector2, delta: Vector2, r: float) -> Vector2:
	var q := p + Vector2(delta.x, 0)
	if solid(q, r):
		q = p
	var q2 := q + Vector2(0, delta.y)
	if solid(q2, r):
		q2 = q
	return q2


func room_of(p: Vector2) -> String:
	if p.x > 1060:
		return "outside"
	if Rect2(838, 300, 204, 340).has_point(p):
		return "scullery"
	if Rect2(438, 158, 244, 144).has_point(p):
		return "pantry"
	if Rect2(238, 658, 322, 134).has_point(p):
		return "coal cellar"
	if Rect2(238, 158, 182, 482).has_point(p):
		return "hall"
	return "kitchen"


# ---------------------------------------------------------------- pathfinding

func _build_nav() -> void:
	astar.region = Rect2i(0, 0, COLS, ROWS)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for cx in range(COLS):
		for cy in range(ROWS):
			var p := Vector2(cx * CELL + CELL * 0.5, cy * CELL + CELL * 0.5)
			var outside_house := p.x > 1060 and not hole_open
			astar.set_point_solid(Vector2i(cx, cy), solid(p, 8.0) or outside_house or p.x < 230)
			# the Curate keeps to the dark: paths through the green light cost far more
			astar.set_point_weight_scale(Vector2i(cx, cy), 30.0 if in_light(p) else 1.0)


func path(from: Vector2, to: Vector2, through_hole := false) -> PackedVector2Array:
	var a := Vector2i(clampi(int(from.x / CELL), 0, COLS - 1), clampi(int(from.y / CELL), 0, ROWS - 1))
	var b := Vector2i(clampi(int(to.x / CELL), 0, COLS - 1), clampi(int(to.y / CELL), 0, ROWS - 1))
	var plugged := []
	if through_hole and not hole_open:
		# the tentacle can reach in through the rubble in the hole
		for cx in range(103, 108):   # x 1030-1070
			for cy in range(45, 52):   # y 450-512
				var c := Vector2i(cx, cy)
				if astar.is_point_solid(c):
					plugged.append(c)
					astar.set_point_solid(c, false)
	var out := PackedVector2Array()
	if astar.is_in_boundsv(a) and astar.is_in_boundsv(b):
		for p in astar.get_point_path(a, b, true):
			out.append(p + Vector2(CELL, CELL) * 0.5)
	for c in plugged:
		astar.set_point_solid(c, true)
	return out


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var paper := Color(0.42, 0.35, 0.26)
	var ink := Color(0.1, 0.07, 0.05)
	# outside: the pit, sloping away to the east
	draw_rect(Rect2(0, 0, W, H), Color(0.16, 0.12, 0.09))
	draw_rect(Rect2(1060, 0, 540, H), Color(0.3, 0.24, 0.16))
	for k in 6:
		draw_arc(Vector2(1480, 470), 120.0 + k * 70.0, PI * 0.55, PI * 1.45, 32, Color(0.2, 0.15, 0.1, 0.5), 3.0)
	draw_circle(Vector2(1480, 470), 110, Color(0.12, 0.09, 0.07))
	# floors
	draw_rect(Rect2(238, 158, 804, 634), paper)
	for y in range(170, 792, 22):
		draw_line(Vector2(238, y), Vector2(1042, y), Color(0.33, 0.27, 0.2), 1.0)
	draw_rect(Rect2(238, 658, 322, 134), Color(0.22, 0.18, 0.14))   # cellar flags
	# smashed crockery
	for b in _bits:
		var p: Vector2 = b.p
		var d: Vector2 = Vector2.from_angle(b.a) * b.s
		draw_colored_polygon(PackedVector2Array([p - d, p + d.orthogonal() * 0.6, p + d]), Color(0.86, 0.82, 0.72))
		draw_line(p - d, p + d, ink, 1.0)
	# furniture
	draw_rect(Rect2(450, 175, 220, 26), Color(0.3, 0.2, 0.12))       # pantry shelves
	for x in range(460, 660, 26):
		draw_rect(Rect2(x, 180, 16, 14), Color(0.7, 0.62, 0.45))
	draw_rect(Rect2(600, 380, 120, 70), Color(0.3, 0.2, 0.12))       # kitchen table
	draw_rect(Rect2(600, 380, 120, 70), ink, false, 2.0)
	draw_rect(Rect2(838, 330, 30, 120), Color(0.27, 0.18, 0.11))     # broken dresser
	draw_circle(copper, 26, Color(0.45, 0.3, 0.18))                   # the copper
	draw_arc(copper, 26, 0, TAU, 24, ink, 2.0)
	draw_line(chopper + Vector2(-6, -10), chopper + Vector2(6, 10), Color(0.6, 0.6, 0.62), 4.0)  # meat chopper on the wall
	# the coal heap
	for k in 22:
		var a := k * 2.39
		draw_circle(coal_heap + Vector2(cos(a), sin(a) * 0.6) * (k * 2.2), 9.0 - k * 0.2, Color(0.05, 0.05, 0.06))
	# walls and rubble, inked
	for w in walls:
		draw_rect(w, Color(0.14, 0.1, 0.08))
		draw_rect(w, ink, false, 2.0)
		if w.size.x > 40 and w.size.y > 40:
			for k in range(0, int(w.size.x + w.size.y), 14):
				var a := w.position + Vector2(k, 0)
				var b := w.position + Vector2(0, k)
				draw_line(a.clamp(w.position, w.end), b.clamp(w.position, w.end), Color(0.25, 0.19, 0.14), 1.0)
	if not hole_open:
		draw_rect(hole_plug, Color(0.2, 0.14, 0.1))
		for k in 5:
			draw_circle(hole_plug.position + Vector2(9, 10 + k * 15), 7, Color(0.25, 0.18, 0.12))
	# the peephole, a slit in the debris
	draw_line(peephole + Vector2(18, -10), peephole + Vector2(18, 10), Color(0.6, 1.0, 0.65, 0.8), 2.0)
	# labels
	for l in [["PANTRY", Vector2(540, 290)], ["KITCHEN", Vector2(560, 625)], ["SCULLERY", Vector2(900, 625)],
			["COAL CELLAR", Vector2(330, 780)], ["HALL", Vector2(300, 625)], ["THE PIT", Vector2(1440, 860)]]:
		draw_string(font, l[1], l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.75, 0.6, 0.45))
	draw_string(font, peephole + Vector2(-70, -16), "peephole", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 1.0, 0.7, 0.5))
