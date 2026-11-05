class_name StoryWorld
extends Node2D
## Draws a story chapter's place from its data (top-down, sepia ink) and
## answers collision queries. Prop kinds: telescope, table, siphon, lantern,
## pine, house, pit, cylinder, road, bridge, fence, hummock, crate, cart,
## river (water you cannot walk into), hedge (a line of bushes; cover),
## boat. A chapter's "heliograph" (Vector2) flickers on the far hills.

const W := 1600
const H := 900

var data: Dictionary
var fires: Array[Dictionary] = []
var puffs: Array[Dictionary] = []
var martian_at := Vector2.INF
var ray_from := Vector2.INF
var machines: Array[Dictionary] = []   # fighting-machines walking the map
var flash := 0.0                         # lightning, 0..1
var ray_to := Vector2.ZERO
var cylinder_open := false
var font: Font
var _t := 0.0
var _decor: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var fx: Node2D


func setup(d: Dictionary) -> void:
	data = d
	font = ThemeDB.fallback_font
	_rng.seed = hash(d.get("title", ""))
	var g: String = d.get("ground", "heath")
	if g != "floor":
		for k in 420:
			var p := Vector2(_rng.randf() * W, _rng.randf() * H)
			_decor.append({"p": p, "r": _rng.randf_range(2.0, 5.0), "k": _rng.randi() % 3})
	fx = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	fx.z_index = 40
	add_child(fx)
	fx.draw.connect(_draw_fx)


func _process(delta: float) -> void:
	_t += delta
	for i in range(puffs.size() - 1, -1, -1):
		puffs[i].t += delta
		if puffs[i].t > 6.0:
			puffs.remove_at(i)
	fx.queue_redraw()
	queue_redraw()


# ---------------------------------------------------------------- queries

func solid(p: Vector2, r: float) -> bool:
	if p.x < r or p.y < r or p.x > W - r or p.y > H - r:
		return true
	for w in data.get("walls", []):
		if (w as Rect2).grow(r).has_point(p):
			return true
	for pr in data.get("props", []):
		if pr.kind == "house" and (pr.rect as Rect2).grow(r).has_point(p):
			return true
		if pr.kind == "telescope" and p.distance_to(pr.pos) < 26.0 + r:
			return true
		if pr.kind == "river" and _near_line(p, pr.pts, float(pr.get("w", 120.0)) * 0.5 - 6.0 + r):
			return true
	if data.has("round_room"):
		var rr: Dictionary = data.round_room
		var d: float = p.distance_to(rr.c)
		if d > rr.r - 16.0 - r:
			var a: float = (p - rr.c).angle()
			if absf(wrapf(a - rr.door, -PI, PI)) > 0.22:
				return true
	return false


func in_area(p: Vector2, name: String) -> bool:
	var areas: Dictionary = data.get("areas", {})
	return areas.has(name) and (areas[name] as Rect2).has_point(p)


func in_cover(p: Vector2) -> bool:
	for pr in data.get("props", []):
		if (pr.kind == "hummock" or pr.kind == "furze") and p.distance_to(pr.pos) < pr.get("r", 40.0) * 0.8:
			return true
		if pr.kind == "ditch" and (pr.rect as Rect2).has_point(p):
			return true
		if pr.kind == "hedge" and _near_line(p, pr.pts, 26.0):
			return true
		if pr.kind == "pine" and p.distance_to(pr.pos) < pr.get("r", 22.0) + 14.0:
			return true
	for k in data.get("areas", {}).keys():
		if String(k).begins_with("cover") and (data.areas[k] as Rect2).has_point(p):
			return true
	return false


func _near_line(p: Vector2, pts: Array, dist: float) -> bool:
	for i in pts.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		if q.distance_to(p) < dist:
			return true
	return false


func add_fire(p: Vector2, size: float) -> void:
	fires.append({"p": p, "s": size, "ph": randf() * 10.0})


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var g: String = data.get("ground", "heath")
	var ink := Color(0.1, 0.07, 0.05)
	match g:
		"floor":
			draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.1, 0.09))
		"town":
			draw_rect(Rect2(0, 0, W, H), Color(0.3, 0.3, 0.2))
		_:
			draw_rect(Rect2(0, 0, W, H), Color(0.36, 0.28, 0.18))
	for dd in _decor:
		var c: Color = [Color(0.3, 0.2, 0.2, 0.6), Color(0.25, 0.22, 0.12, 0.5), Color(0.42, 0.34, 0.22, 0.5)][dd.k]
		draw_circle(dd.p, dd.r, c)
	# rivers and roads first
	for pr in data.get("props", []):
		if pr.kind == "river":
			var pts := PackedVector2Array(pr.pts)
			var wd := float(pr.get("w", 120.0))
			draw_polyline(pts, Color(0.22, 0.2, 0.12), wd + 26.0, true)      # muddy banks
			draw_polyline(pts, Color(0.18, 0.24, 0.27), wd, true)
			draw_polyline(pts, Color(0.24, 0.31, 0.33), wd * 0.55, true)
			# ripples drifting downstream
			for k in 40:
				var i := k % (pts.size() - 1)
				var u := fmod(k * 0.37 + _t * 0.03, 1.0)
				var c := pts[i].lerp(pts[i + 1], u) + Vector2(0, (fmod(k * 53.0, wd * 0.8)) - wd * 0.4)
				draw_line(c, c + (pts[i + 1] - pts[i]).normalized() * 16.0, Color(0.5, 0.6, 0.6, 0.35), 1.5)
		if pr.kind == "road":
			draw_polyline(PackedVector2Array(pr.pts), Color(0.5, 0.42, 0.3), 46.0, true)
			draw_polyline(PackedVector2Array(pr.pts), Color(0.62, 0.53, 0.38), 34.0, true)
	if data.has("round_room"):
		var rr: Dictionary = data.round_room
		draw_circle(rr.c, rr.r, Color(0.3, 0.22, 0.15))
		for k in range(-int(rr.r), int(rr.r), 22):
			var hw := sqrt(maxf(rr.r * rr.r - k * k, 0.0))
			draw_line(rr.c + Vector2(-hw, k), rr.c + Vector2(hw, k), Color(0.22, 0.16, 0.11), 1.0)
		# the slit in the roof, with stars beyond it
		draw_rect(Rect2(rr.c.x - 24, rr.c.y - rr.r, 48, rr.r * 0.9), Color(0.08, 0.1, 0.22, 0.85))
		for k in 14:
			draw_circle(Vector2(rr.c.x - 18 + fmod(k * 13.7, 36.0), rr.c.y - rr.r + 10 + k * 17.0), 1.2, Color(1, 1, 0.9, 0.8))
		var a0: float = rr.door + 0.22
		draw_arc(rr.c, rr.r - 8, a0, a0 + TAU - 0.44, 64, ink, 18.0)
		draw_arc(rr.c, rr.r, a0, a0 + TAU - 0.44, 64, Color(0.45, 0.35, 0.25), 2.0)
	for pr in data.get("props", []):
		_draw_prop(pr, ink)
	for w in data.get("walls", []):
		draw_rect(w, Color(0.16, 0.12, 0.09))
		draw_rect(w, ink, false, 2.0)
	if martian_at != Vector2.INF:
		_draw_martian(martian_at)
	for m in machines:
		_draw_machine(m)
	if data.get("rain", false):
		for k in 140:
			var x := fmod(k * 137.0 + _t * 520.0, W + 200.0) - 100.0
			var y := fmod(k * 71.0 + _t * 900.0, H + 100.0) - 50.0
			draw_line(Vector2(x, y), Vector2(x - 10, y + 26), Color(0.75, 0.8, 0.95, 0.25 + 0.4 * flash), 1.0)
	if data.has("heliograph"):
		# "a faint flickering that danced over the sky": a signal lamp on the hills
		var hg: Vector2 = data.heliograph
		var on := fmod(_t * 2.6, 1.0) < (0.3 if int(_t * 2.6) % 3 == 0 else 0.12)
		if on:
			draw_circle(hg, 9, Color(1, 1, 0.85, 0.35))
			draw_circle(hg, 3.5, Color(1, 1, 0.9, 0.95))
	for a in data.get("labels", []):
		draw_string(font, a[1], a[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.85, 0.7, 0.45))


func _draw_prop(pr: Dictionary, ink: Color) -> void:
	var p: Vector2 = pr.get("pos", Vector2.ZERO)
	match pr.kind:
		"telescope":
			draw_circle(p, 26, Color(0.2, 0.15, 0.1))
			for k in 3:
				draw_line(p, p + Vector2.from_angle(k * TAU / 3.0 + 0.5) * 30.0, ink, 4.0)
			draw_line(p + Vector2(-50, 30), p + Vector2(60, -60), Color(0.05, 0.05, 0.06), 16.0)
			draw_line(p + Vector2(-50, 30), p + Vector2(60, -60), Color(0.55, 0.45, 0.25), 2.0)
			draw_circle(p + Vector2(-50, 30), 7, Color(0.65, 0.5, 0.25))
		"table":
			draw_rect(Rect2(p - Vector2(40, 22), Vector2(80, 44)), Color(0.32, 0.2, 0.12))
			draw_rect(Rect2(p - Vector2(40, 22), Vector2(80, 44)), ink, false, 2.0)
		"siphon":
			draw_circle(p, 7, Color(0.6, 0.75, 0.8, 0.8))
		"lantern":
			draw_circle(p, 9, Color(0.2, 0.15, 0.08))
			draw_circle(p, 5, Color(1, 0.8, 0.4))
		"pine":
			var r: float = pr.get("r", 22.0)
			draw_circle(p + Vector2(6, 8), r, Color(0, 0, 0, 0.3))
			draw_circle(p, r, Color(0.08, 0.1, 0.06))
			for k in 6:
				draw_line(p, p + Vector2.from_angle(k * 1.05 + 0.3) * r * 0.9, Color(0.16, 0.2, 0.1), 2.0)
		"house":
			var rr: Rect2 = pr.rect
			draw_rect(Rect2(rr.position + Vector2(8, 10), rr.size), Color(0, 0, 0, 0.4))
			draw_rect(rr, Color(0.45, 0.2, 0.14))
			draw_rect(rr.grow(-5), Color(0.32, 0.14, 0.1))
			draw_line(Vector2(rr.position.x + 5, rr.get_center().y), Vector2(rr.end.x - 5, rr.get_center().y), Color(0.6, 0.3, 0.2), 2.0)
			draw_rect(rr, ink, false, 2.0)
			if pr.has("label"):
				draw_string(font, rr.position + Vector2(0, rr.size.y + 16), pr.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.85, 0.7, 0.6))
			if pr.get("lit", false):
				draw_rect(Rect2(rr.get_center() - Vector2(6, 4), Vector2(12, 8)), Color(1, 0.75, 0.35))
		"pit":
			var r: float = pr.get("r", 110.0)
			draw_set_transform(p, 0, Vector2(1, 0.75))
			draw_circle(Vector2.ZERO, r + 30, Color(0.62, 0.5, 0.32))
			draw_circle(Vector2.ZERO, r, Color(0.5, 0.39, 0.24))
			draw_circle(Vector2.ZERO, r * 0.7, Color(0.4, 0.3, 0.18))
			draw_arc(Vector2.ZERO, r + 30, 0, TAU, 48, Color(0.3, 0.22, 0.14), 2.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"cylinder":
			var rr := Rect2(p - Vector2(70, 26), Vector2(140, 52))
			draw_rect(rr, Color(0.28, 0.27, 0.25))
			draw_rect(Rect2(rr.position + Vector2(0, 6), Vector2(140, 8)), Color(0.5, 0.48, 0.44))
			draw_rect(rr, ink, false, 2.0)
			var end := p + Vector2(70, 0)
			draw_circle(end, 26, Color(0.2, 0.19, 0.18) if not cylinder_open else Color(0.02, 0.02, 0.02))
			draw_arc(end, 26, 0, TAU, 24, Color(0.55, 0.5, 0.45), 3.0)
			if not cylinder_open:
				draw_line(end + Vector2.from_angle(_t * 0.4) * 22.0, end - Vector2.from_angle(_t * 0.4) * 22.0, ink, 2.0)
		"bridge":
			var rr: Rect2 = pr.rect
			draw_rect(rr, Color(0.4, 0.3, 0.22))
			draw_rect(rr, ink, false, 2.0)
		"fence":
			draw_polyline(PackedVector2Array(pr.pts), Color(0.25, 0.18, 0.1), 3.0)
		"hummock":
			var r: float = pr.get("r", 40.0)
			draw_set_transform(p, 0, Vector2(1.2, 0.8))
			draw_circle(Vector2(4, 6), r, Color(0, 0, 0, 0.25))
			draw_circle(Vector2.ZERO, r, Color(0.55, 0.44, 0.28))
			draw_circle(Vector2(-r * 0.2, -r * 0.2), r * 0.6, Color(0.62, 0.5, 0.33))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"stairs":
			var rr: Rect2 = pr.rect
			draw_rect(rr, Color(0.3, 0.2, 0.13))
			for k in range(0, int(rr.size.y), 14):
				draw_line(Vector2(rr.position.x, rr.position.y + k), Vector2(rr.end.x, rr.position.y + k), ink, 1.5)
			draw_rect(rr, ink, false, 2.0)
		"window":
			draw_rect(Rect2(p - Vector2(6, 34), Vector2(12, 68)), Color(0.55, 0.65, 0.85, 0.8))
			draw_rect(Rect2(p - Vector2(6, 34), Vector2(12, 68)), ink, false, 2.0)
		"door":
			draw_rect(Rect2(p - Vector2(8, 32), Vector2(16, 64)), Color(0.42, 0.26, 0.14))
			draw_rect(Rect2(p - Vector2(8, 32), Vector2(16, 64)), ink, false, 2.0)
		"rug":
			draw_rect(pr.rect, Color(0.4, 0.15, 0.12, 0.7))
		"body":
			draw_line(p + Vector2(-14, -3), p + Vector2(12, 4), Color(0.06, 0.05, 0.06), 9.0)
			draw_circle(p + Vector2(15, 5), 5, Color(0.6, 0.5, 0.42))
		"horse":
			draw_rect(Rect2(p - Vector2(30, 12), Vector2(60, 24)), Color(0.28, 0.17, 0.1))
			draw_circle(p + Vector2(34, -6), 9, Color(0.28, 0.17, 0.1))
			for k in 4:
				draw_line(p + Vector2(-22 + k * 14, 10), p + Vector2(-26 + k * 14, 26), Color(0.2, 0.12, 0.07), 3.0)
		"furze":
			var r: float = pr.get("r", 34.0)
			draw_circle(p + Vector2(4, 5), r, Color(0, 0, 0, 0.25))
			draw_circle(p, r, Color(0.2, 0.22, 0.1))
			for k in 10:
				draw_circle(p + Vector2.from_angle(k * 0.63) * r * 0.6, 6, Color(0.55, 0.5, 0.15, 0.6))
		"ditch":
			draw_rect(pr.rect, Color(0.12, 0.1, 0.07))
			draw_rect((pr.rect as Rect2).grow(-6), Color(0.18, 0.2, 0.25, 0.7))
		"pool":
			draw_circle(p, pr.get("r", 30.0), Color(0.2, 0.24, 0.32, 0.85))
		"hedge":
			var hp: Array = pr.pts
			for i in hp.size() - 1:
				var a: Vector2 = hp[i]
				var b: Vector2 = hp[i + 1]
				var n := int(a.distance_to(b) / 18.0)
				for k in n + 1:
					var c := a.lerp(b, float(k) / maxf(n, 1)) + Vector2(sin(k * 2.3) * 4.0, cos(k * 1.7) * 4.0)
					draw_circle(c + Vector2(4, 6), 21, Color(0, 0, 0, 0.25))
					draw_circle(c, 20, Color(0.2, 0.26, 0.12))
					draw_circle(c + Vector2(-5, -5), 9, Color(0.3, 0.36, 0.18))
		"boat":
			var bd: Vector2 = pr.get("dir", Vector2.RIGHT)
			var pts := PackedVector2Array([p + bd * 36.0, p + bd.orthogonal() * 13.0, p - bd * 30.0 + bd.orthogonal() * 11.0, p - bd * 30.0 - bd.orthogonal() * 11.0, p - bd.orthogonal() * 13.0])
			draw_colored_polygon(pts, Color(0.35, 0.22, 0.12))
			pts.append(pts[0])
			draw_polyline(pts, ink, 2.0)
		"crate":
			draw_rect(Rect2(p - Vector2(14, 14), Vector2(28, 28)), Color(0.4, 0.28, 0.15))
		"cart":
			draw_rect(Rect2(p - Vector2(24, 14), Vector2(48, 28)), Color(0.35, 0.22, 0.12))
			draw_circle(p + Vector2(-18, 16), 7, ink)
			draw_circle(p + Vector2(18, 16), 7, ink)


## A fighting-machine seen from above, after Alvim Corrêa: hat, two eyes,
## needle legs, the basket on its back.
func _draw_machine(m: Dictionary) -> void:
	var p: Vector2 = m.pos
	var f: Vector2 = m.get("facing", Vector2.LEFT)
	var ink := Color(0.05, 0.04, 0.04)
	var hub := p + Vector2(0, -70)
	for k in 3:
		var a := f.angle() + PI / 3.0 + k * TAU / 3.0 + sin(_t * 3.0 + k) * 0.15
		var foot := p + Vector2.from_angle(a) * 70.0
		draw_line(foot, hub + Vector2(0, 30), ink, 4.0)
	draw_circle(hub + Vector2(0, 30) - f * 46.0, 18, Color(0.85, 0.85, 0.8))      # the basket
	draw_arc(hub + Vector2(0, 30) - f * 46.0, 18, 0, TAU, 20, ink, 2.0)
	for k in 12:
		var x := -34.0 + k * 6.0
		draw_line(hub + Vector2(x, 6), hub + Vector2(x + sin(_t + k) * 3.0, 50), Color(0.1, 0.08, 0.07, 0.8), 1.0)
	draw_set_transform(hub, 0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 46, ink)
	draw_circle(Vector2.ZERO, 43, Color(0.55, 0.52, 0.48))
	draw_circle(Vector2.ZERO, 16, Color(0.65, 0.62, 0.56))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	draw_line(hub, hub + Vector2(0, -24), ink, 2.0)
	for side in [-1.0, 1.0]:
		var e: Vector2 = hub + Vector2(0, 14) + f * 16.0 + f.orthogonal() * 9.0 * side
		draw_circle(e, 6, ink)
		draw_circle(e, 5, Color(0.95, 0.92, 0.85))
		draw_circle(e + f * 2.0, 2.2, ink)


func _draw_martian(p: Vector2) -> void:
	var ink := Color(0.05, 0.04, 0.04)
	for k in 9:
		var a := PI + (k - 4) * 0.3 + sin(_t * 2.0 + k) * 0.15
		var pts := PackedVector2Array()
		for s in 7:
			pts.append(p + Vector2.from_angle(a + sin(_t * 3.0 + s + k) * 0.2) * (20.0 + s * 9.0))
		draw_polyline(pts, ink, 3.0, true)
	draw_circle(p, 30, Color(0.38, 0.36, 0.34))
	draw_circle(p, 30 - 2.0 * absf(sin(_t * 2.5)), Color(0.45, 0.43, 0.4))
	for side in [-1.0, 1.0]:
		draw_circle(p + Vector2(-12, side * 11), 8, Color(0.05, 0.05, 0.05))
		draw_circle(p + Vector2(-14, side * 11), 3, Color(0.5, 0.9, 0.55))


func _draw_fx() -> void:
	for f in fires:
		var fl := 0.8 + 0.2 * sin(_t * 8.0 + f.ph)
		fx.draw_circle(f.p, f.s * 3.0 * fl, Color(0.5, 0.15, 0.02, 0.18))
		fx.draw_circle(f.p, f.s * 1.4 * fl, Color(1.0, 0.45, 0.08, 0.35))
		fx.draw_circle(f.p, f.s * 0.6, Color(1.0, 0.85, 0.5, 0.5))
	for p in puffs:
		for k in 3:
			var t: float = p.t - k * 0.5
			if t > 0.0:
				var c: Vector2 = p.p + Vector2(0, -t * 30.0)
				fx.draw_circle(c, 20.0 + t * 14.0, Color(0.3, 1.0, 0.45, maxf(0.0, 0.35 - t * 0.06)))
	if ray_from != Vector2.INF:
		# "the ghost of a beam of light", and the flash where it strikes
		var fl := 0.6 + 0.4 * sin(_t * 40.0)
		fx.draw_line(ray_from, ray_to, Color(0.45, 0.35, 0.18, 0.35 * fl), 30.0)
		fx.draw_line(ray_from, ray_to, Color(1.0, 0.92, 0.65, 0.6 * fl), 4.0)
	if data.has("lanterns"):
		for l in data.lanterns:
			fx.draw_circle(l, 120, Color(0.35, 0.22, 0.08, 0.12))
