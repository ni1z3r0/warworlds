class_name World
extends Node2D
## The map: terrain, buildings, cellars, woods, river, fires and pathfinding.
## Everything is drawn procedurally so the prototype needs no art assets.

const W := 1600
const H := 900
const CELL := 16
const COLS := 100   # W / CELL
const ROWS := 56    # H / CELL, rounded down

var buildings: Array[Rect2] = []
var burning: Array[int] = []
var woods: Array[Vector3] = []          # x, y, radius
var trees: Array[Vector3] = []
var cellars: Array[Vector2] = []
var river_poly := PackedVector2Array()
var bridges: Array[Rect2] = []
var roads: Array[PackedVector2Array] = []
var exit_zone := Rect2(40, 770, 240, 110)
var pit_pos := Vector2(1250, 215)
var fires: Array[Dictionary] = []
var astar := AStarGrid2D.new()
var fx: Node2D
var font: Font
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _decor: Array[Dictionary] = []


func _ready() -> void:
	font = ThemeDB.fallback_font
	_rng.seed = 1898
	_build_map()
	_build_nav()
	fx = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	fx.z_index = 40
	add_child(fx)
	fx.draw.connect(_draw_fx)


func _process(delta: float) -> void:
	_t += delta
	for i in range(fires.size() - 1, -1, -1):
		var f: Dictionary = fires[i]
		if f.life > 0.0:
			f.life -= delta
			if f.life <= 0.0:
				fires.remove_at(i)
	fx.queue_redraw()


# ---------------------------------------------------------------- map layout

func river_y(x: float) -> float:
	return 650.0 + sin(x * 0.006) * 30.0 + sin(x * 0.017) * 8.0


func _build_map() -> void:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in range(0, 43):
		var x := i * 40.0 - 20.0
		var y := river_y(x)
		top.append(Vector2(x, y))
		bot.append(Vector2(x, y + 58.0 + sin(x * 0.011) * 6.0))
	bot.reverse()
	river_poly = top
	river_poly.append_array(bot)

	for bx in [296.0, 1124.0]:
		var y0 := river_y(bx + 28.0)
		bridges.append(Rect2(bx, y0 - 14.0, 56.0, 94.0))

	roads.append(PackedVector2Array([Vector2(170, 40), Vector2(210, 160), Vector2(240, 300),
		Vector2(300, 440), Vector2(326, 560), Vector2(324, 700), Vector2(260, 800), Vector2(120, 840), Vector2(0, 850)]))
	roads.append(PackedVector2Array([Vector2(1250, 260), Vector2(1190, 420), Vector2(1155, 560),
		Vector2(1152, 720), Vector2(1210, 900)]))
	roads.append(PackedVector2Array([Vector2(0, 330), Vector2(420, 335), Vector2(800, 300),
		Vector2(1240, 262), Vector2(1600, 240)]))

	var rects := [
		# the village (north-west)
		Rect2(120, 90, 70, 50), Rect2(220, 70, 60, 60), Rect2(300, 110, 80, 45), Rect2(100, 190, 55, 70),
		Rect2(270, 180, 60, 48), Rect2(400, 180, 60, 60), Rect2(150, 360, 80, 40), Rect2(420, 390, 70, 50),
		Rect2(520, 250, 60, 45),
		# hamlet by the river
		Rect2(620, 560, 70, 40), Rect2(720, 535, 50, 55), Rect2(800, 572, 75, 40),
		# farms near the pit, already burning
		Rect2(1000, 150, 60, 50), Rect2(1060, 330, 70, 45), Rect2(1400, 380, 60, 60),
		# south bank
		Rect2(480, 800, 80, 45), Rect2(900, 790, 70, 50), Rect2(1350, 800, 90, 40),
	]
	for r in rects:
		buildings.append(r)
	burning = [12, 13, 14]
	for i in [0, 3, 4, 6, 7, 9, 11, 15, 16]:
		var r := buildings[i]
		cellars.append(Vector2(r.position.x + r.size.x * 0.5, r.end.y + 10.0))

	woods = [Vector3(700, 400, 105), Vector3(905, 470, 80), Vector3(480, 540, 66),
		Vector3(1450, 600, 90), Vector3(600, 110, 58), Vector3(820, 800, 70)]
	for w in woods:
		var n := int(w.z * w.z / 210.0)
		for k in n:
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf()) * w.z
			trees.append(Vector3(w.x + cos(a) * d, w.y + sin(a) * d, _rng.randf_range(9, 17)))

	for k in 260:
		var tint := _rng.randf()
		var c := Color(0.34, 0.17, 0.08).lerp(Color(0.16, 0.08, 0.05), tint)
		c.a = _rng.randf_range(0.25, 0.6)
		_decor.append({"p": Vector2(_rng.randf() * W, _rng.randf() * H), "r": _rng.randf_range(20, 90), "c": c})

	for i in burning:
		add_fire(buildings[i].get_center(), 30.0, -1.0)
	add_fire(pit_pos + Vector2(-120, 40), 14.0, -1.0)
	add_fire(pit_pos + Vector2(90, 110), 12.0, -1.0)
	add_fire(Vector2(1180, 120), 16.0, -1.0)


func add_fire(pos: Vector2, size: float, life: float) -> void:
	fires.append({"pos": pos, "size": size, "life": life, "phase": _rng.randf() * 10.0})


# ---------------------------------------------------------------- queries

func in_river(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, river_poly)


func on_bridge(p: Vector2) -> bool:
	for b in bridges:
		if b.has_point(p):
			return true
	return false


func in_woods(p: Vector2) -> bool:
	for w in woods:
		if p.distance_to(Vector2(w.x, w.y)) < w.z:
			return true
	return false


func blocked(p: Vector2) -> bool:
	if p.x < 4 or p.y < 4 or p.x > W - 4 or p.y > H - 4:
		return true
	for b in buildings:
		if b.grow(6).has_point(p):
			return true
	return in_river(p) and not on_bridge(p)


func nearest_cellar(p: Vector2, max_dist: float) -> Vector2:
	var best := Vector2.INF
	var bd := max_dist
	for c in cellars:
		var d := p.distance_to(c)
		if d < bd:
			bd = d
			best = c
	return best


## Line of sight at ground level. Buildings block; a building the viewer is
## standing over (the tripod straddles houses) does not.
func has_los(a: Vector2, b: Vector2) -> bool:
	for r in buildings:
		if r.has_point(a):
			continue
		if _seg_hits_rect(a, b, r.grow(-3)):
			return false
	return true


func _seg_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(b):
		return false  # standing against a wall: still visible
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


# ---------------------------------------------------------------- pathfinding

func _build_nav() -> void:
	astar.region = Rect2i(0, 0, COLS, ROWS)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for cx in range(COLS):
		for cy in range(ROWS):
			if blocked(Vector2(cx * CELL + CELL * 0.5, cy * CELL + CELL * 0.5)):
				astar.set_point_solid(Vector2i(cx, cy), true)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, COLS - 1), clampi(int(p.y / CELL), 0, ROWS - 1))


func _nearest_free(c: Vector2i) -> Vector2i:
	if not astar.is_point_solid(c):
		return c
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
					return n
	return c


func _clear_line(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var steps := int(d / 6.0) + 1
	for i in range(1, steps + 1):
		if blocked(a.lerp(b, float(i) / steps)):
			return false
	return true


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	to = to.clamp(Vector2(8, 8), Vector2(W - 8, H - 8))
	var a := _nearest_free(_cell(from))
	var b := _nearest_free(_cell(to))
	var raw := astar.get_point_path(a, b)
	var pts := PackedVector2Array()
	var half := Vector2(CELL, CELL) * 0.5
	for i in range(1, raw.size()):
		pts.append(raw[i] + half)
	if not blocked(to):
		if pts.is_empty():
			pts.append(to)
		else:
			pts[pts.size() - 1] = to
	# string-pull: skip waypoints we can walk straight past
	var out := PackedVector2Array()
	var anchor := from
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not _clear_line(anchor, pts[j]):
			j -= 1
		out.append(pts[j])
		anchor = pts[j]
		i = j + 1
	return out


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.27, 0.13, 0.07))
	for d in _decor:
		draw_circle(d.p, d.r, d.c)
	# scorched heath around the pit
	draw_circle(pit_pos, 190, Color(0.07, 0.03, 0.02, 0.55))
	draw_circle(pit_pos, 130, Color(0.05, 0.02, 0.02, 0.5))

	for r in roads:
		draw_polyline(r, Color(0.36, 0.21, 0.12), 24, true)
		draw_polyline(r, Color(0.55, 0.37, 0.22), 15, true)

	# river: dark water reflecting a burning sky
	draw_colored_polygon(river_poly, Color(0.24, 0.03, 0.04))
	for k in 5:
		var line := PackedVector2Array()
		for i in range(0, 41):
			var x := i * 40.0
			line.append(Vector2(x, river_y(x) + 10.0 + k * 9.0 + sin(x * 0.03 + k) * 2.0))
		draw_polyline(line, Color(0.75, 0.22, 0.08, 0.10 + 0.04 * (k % 2)), 2.0, true)
	for b in bridges:
		draw_rect(Rect2(b.position + Vector2(4, 6), b.size), Color(0, 0, 0, 0.4))
		draw_rect(b, Color(0.30, 0.20, 0.14))
		for y in range(int(b.position.y) + 4, int(b.end.y), 8):
			draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), Color(0.18, 0.11, 0.08), 1.5)
		draw_line(b.position, Vector2(b.position.x, b.end.y), Color(0.12, 0.07, 0.05), 3)
		draw_line(Vector2(b.end.x, b.position.y), b.end, Color(0.12, 0.07, 0.05), 3)

	# escape route
	draw_rect(exit_zone, Color(0.85, 0.65, 0.3, 0.07))
	_dashed_rect(exit_zone, Color(1.0, 0.8, 0.45, 0.6))
	draw_string(font, exit_zone.position + Vector2(10, 22), "THE LEATHERHEAD ROAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.55, 0.9))
	draw_string(font, exit_zone.position + Vector2(10, 40), "escape here", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.55, 0.6))

	# the pit and the cylinder
	draw_set_transform(pit_pos, 0, Vector2(1.0, 0.7))
	draw_circle(Vector2.ZERO, 70, Color(0.42, 0.28, 0.16))
	draw_circle(Vector2.ZERO, 54, Color(0.22, 0.13, 0.08))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var cyl := Rect2(pit_pos + Vector2(-40, -14), Vector2(80, 28))
	draw_rect(cyl, Color(0.20, 0.19, 0.18))
	draw_rect(Rect2(cyl.position + Vector2(0, 3), Vector2(80, 5)), Color(0.42, 0.38, 0.33))
	draw_circle(cyl.position + Vector2(80, 14), 14, Color(0.16, 0.15, 0.14))
	draw_arc(cyl.position + Vector2(80, 14), 14, 0, TAU, 24, Color(0.45, 0.4, 0.35), 2)
	draw_string(font, pit_pos + Vector2(-46, 64), "THE PIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.7, 0.5, 0.6))

	# woods
	for w in woods:
		draw_circle(Vector2(w.x, w.y), w.z + 6, Color(0.05, 0.05, 0.03, 0.55))
	for t in trees:
		draw_circle(Vector2(t.x + 4, t.y + 5), t.z, Color(0, 0, 0, 0.35))
	for t in trees:
		draw_circle(Vector2(t.x, t.y), t.z, Color(0.12, 0.13, 0.06))
		draw_circle(Vector2(t.x - t.z * 0.25, t.y - t.z * 0.3), t.z * 0.55, Color(0.30, 0.13, 0.05, 0.55))

	# buildings
	for i in buildings.size():
		var r := buildings[i]
		var burnt := i in burning
		draw_rect(Rect2(r.position + Vector2(7, 8), r.size), Color(0, 0, 0, 0.5))
		draw_rect(r, Color(0.12, 0.06, 0.05) if burnt else Color(0.26, 0.12, 0.09))
		var inset := r.grow(-4)
		draw_rect(inset, Color(0.08, 0.04, 0.04) if burnt else Color(0.40, 0.15, 0.10))
		if r.size.x >= r.size.y:
			draw_line(Vector2(inset.position.x, r.get_center().y), Vector2(inset.end.x, r.get_center().y), Color(0.62, 0.30, 0.18), 2)
		else:
			draw_line(Vector2(r.get_center().x, inset.position.y), Vector2(r.get_center().x, inset.end.y), Color(0.62, 0.30, 0.18), 2)
		draw_rect(Rect2(inset.end.x - 12, inset.position.y + 3, 6, 6), Color(0.1, 0.05, 0.04))  # chimney

	for c in cellars:
		draw_rect(Rect2(c - Vector2(8, 6), Vector2(16, 12)), Color(0.32, 0.20, 0.12))
		draw_rect(Rect2(c - Vector2(8, 6), Vector2(16, 12)), Color(0.08, 0.04, 0.03), false, 1.5)
		draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(0.08, 0.04, 0.03), 1.0)
		draw_circle(c + Vector2(5, 3), 1.2, Color(0.8, 0.6, 0.3))


func _dashed_rect(r: Rect2, c: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(pts[i], pts[(i + 1) % 4], c, 2.0, 8.0)


func _draw_fx() -> void:
	# additive layer: firelight and the cylinder's glow
	for f in fires:
		var p: Vector2 = f.pos
		var s: float = f.size
		var fade := 1.0
		if f.life > 0.0:
			fade = clampf(f.life / 4.0, 0.0, 1.0)
		var fl := 0.85 + 0.15 * sin(_t * 7.0 + f.phase) * sin(_t * 3.1 + f.phase * 2.0)
		fx.draw_circle(p, s * 4.0 * fl, Color(0.35, 0.08, 0.0, 0.10 * fade))
		fx.draw_circle(p, s * 2.2 * fl, Color(0.6, 0.18, 0.02, 0.16 * fade))
		for k in 5:
			var o := Vector2(sin(_t * 5.0 + k * 1.7 + f.phase), cos(_t * 4.0 + k * 2.3 + f.phase)) * s * 0.45
			fx.draw_circle(p + o, s * (0.45 + 0.1 * k) * fl, Color(0.9, 0.38, 0.05, 0.22 * fade))
		fx.draw_circle(p, s * 0.35, Color(1.0, 0.75, 0.3, 0.35 * fade))
	var g := 0.6 + 0.4 * sin(_t * 1.7)
	fx.draw_circle(pit_pos, 60, Color(0.1, 0.35, 0.12, 0.10 * g))
	fx.draw_circle(pit_pos + Vector2(40, 0), 10, Color(0.3, 0.9, 0.4, 0.35 * g))
