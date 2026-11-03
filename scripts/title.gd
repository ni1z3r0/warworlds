extends Control
## Title card: a painted scene in the spirit of 1970s prog-rock album art.
## Blood-red sky, burning horizon, black smoke, and our own fighting-machine
## silhouetted against the fire. All drawn procedurally.

var main: Node
var serif: Font
var font: Font
var _t := 0.0


func _ready() -> void:
	size = Vector2(World.W, World.H + 100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["DejaVu Serif", "Georgia", "Times New Roman", "Liberation Serif", "serif"])
	serif = sf


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _band(y0: float, y1: float, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(World.W, y0), Vector2(World.W, y1), Vector2(0, y1)]),
		PackedColorArray([c0, c0, c1, c1]))


func _hills(base: float, amp: float, freq: float, seed_off: float, c: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, World.H + 100))
	for i in range(0, 81):
		var x := i * 20.0
		pts.append(Vector2(x, base - amp * (0.6 * sin(x * freq + seed_off) + 0.4 * sin(x * freq * 2.7 + seed_off * 3.0))))
	pts.append(Vector2(World.W, World.H + 100))
	draw_colored_polygon(pts, c)


func _draw() -> void:
	var w := float(World.W)
	# sky
	_band(0, 260, Color(0.07, 0.0, 0.03), Color(0.38, 0.03, 0.05))
	_band(260, 470, Color(0.38, 0.03, 0.05), Color(0.85, 0.22, 0.04))
	_band(470, 560, Color(0.85, 0.22, 0.04), Color(1.0, 0.62, 0.2))
	_band(560, 1000, Color(1.0, 0.62, 0.2), Color(0.3, 0.05, 0.02))

	# Mars, low and swollen
	var mars := Vector2(1210, 230)
	draw_circle(mars, 170, Color(1, 0.35, 0.1, 0.05))
	draw_circle(mars, 110, Color(1, 0.35, 0.1, 0.08))
	draw_circle(mars, 66, Color(0.78, 0.26, 0.10))
	draw_circle(mars + Vector2(-18, -10), 20, Color(0.62, 0.18, 0.08))
	draw_circle(mars + Vector2(22, 18), 14, Color(0.6, 0.17, 0.07))
	draw_arc(mars, 66, -2.2, 0.3, 24, Color(1, 0.6, 0.35, 0.6), 3)

	# a falling cylinder streaking across the sky
	var cp := Vector2(260 + fmod(_t * 60.0, 500.0), 90 + fmod(_t * 60.0, 500.0) * 0.32)
	draw_line(cp - Vector2(140, 45), cp, Color(0.6, 1.0, 0.6, 0.25), 3)
	draw_circle(cp, 4, Color(0.8, 1.0, 0.8, 0.9))

	# burning town on the horizon
	_hills(560, 18, 0.004, 1.0, Color(0.35, 0.07, 0.04))
	for i in 14:
		var x := 820.0 + i * 46.0
		var hgt := 20.0 + fmod(i * 37.0, 40.0)
		draw_rect(Rect2(x, 560 - hgt, 30, hgt + 20), Color(0.12, 0.02, 0.02))
		var fl := 0.7 + 0.3 * sin(_t * 6.0 + i * 1.3)
		draw_circle(Vector2(x + 15, 545 - hgt), 26.0 * fl, Color(1, 0.55, 0.1, 0.25))
	draw_rect(Rect2(1180, 470, 10, 80), Color(0.12, 0.02, 0.02))  # church spire
	draw_colored_polygon(PackedVector2Array([Vector2(1176, 472), Vector2(1185, 430), Vector2(1194, 472)]), Color(0.12, 0.02, 0.02))

	# black smoke pouring along the valley
	for i in 26:
		var bx := 500.0 + i * 38.0 + sin(_t * 0.4 + i) * 12.0
		var by := 520.0 - sin(i * 0.5) * 30.0 - fmod(i * 23.0, 50.0)
		draw_circle(Vector2(bx, by), 40.0 + fmod(i * 17.0, 30.0), Color(0.02, 0.01, 0.01, 0.55))

	# near hills, black
	_hills(690, 50, 0.0035, 4.0, Color(0.05, 0.01, 0.01))

	# the fighting-machine on the ridge
	var hub := Vector2(470, 300)
	var sway := sin(_t * 0.8) * 4.0
	hub.x += sway
	var dark := Color(0.03, 0.0, 0.0)
	var feet := [Vector2(330, 668), Vector2(470, 690), Vector2(640, 660)]
	var knees := [Vector2(360, 470), Vector2(520, 500), Vector2(610, 450)]
	for i in 3:
		draw_line(feet[i], knees[i], dark, 9)
		draw_line(knees[i], hub, dark, 11)
		draw_circle(knees[i], 9, dark)
		draw_line(knees[i] + Vector2(4, 0), hub + Vector2(4, 0), Color(1, 0.45, 0.1, 0.35), 2)
	for k in 4:
		var pts := PackedVector2Array()
		for s in 9:
			pts.append(hub + Vector2(-30 + k * 18 + sin(_t * 1.5 + k + s * 0.6) * s * 2.0, 30 + s * 14))
		draw_polyline(pts, dark, 3, true)
	var cowl := PackedVector2Array([hub + Vector2(-90, 10), hub + Vector2(-70, -40), hub + Vector2(-10, -66),
		hub + Vector2(60, -50), hub + Vector2(100, -10), hub + Vector2(70, 26), hub + Vector2(-40, 34)])
	draw_colored_polygon(cowl, dark)
	draw_polyline(PackedVector2Array([hub + Vector2(-70, -40), hub + Vector2(-10, -66), hub + Vector2(60, -50), hub + Vector2(100, -10)]),
		Color(1, 0.4, 0.1, 0.55), 3, true)
	var eye := hub + Vector2(84, -6)
	draw_circle(eye, 26, Color(0.4, 1.0, 0.5, 0.15))
	draw_circle(eye, 9, Color(0.6, 1.0, 0.7))

	# the heat-ray sweeping the town
	var ray_end := Vector2(1040 + sin(_t * 0.7) * 120.0, 545)
	draw_line(eye, ray_end, Color(0.4, 1.0, 0.45, 0.20), 30)
	draw_line(eye, ray_end, Color(0.6, 1.0, 0.65, 0.5), 10)
	draw_line(eye, ray_end, Color(0.95, 1.0, 0.9, 0.95), 3)
	draw_circle(ray_end, 40, Color(0.8, 1.0, 0.5, 0.35))
	draw_circle(ray_end, 18, Color(1, 1, 0.85, 0.7))

	# text
	var cream := Color(1.0, 0.9, 0.75)
	draw_string_outline(serif, Vector2(0, 110), "THE COMING OF THE MARTIANS", HORIZONTAL_ALIGNMENT_CENTER, w, 64, 8, Color(0, 0, 0, 0.6))
	draw_string(serif, Vector2(0, 110), "THE COMING OF THE MARTIANS", HORIZONTAL_ALIGNMENT_CENTER, w, 64, Color(1.0, 0.82, 0.55))
	draw_string(serif, Vector2(0, 150), "after H. G. Wells' The War of the Worlds (1898)", HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(cream, 0.8))

	var quote := [
		"\"No one would have believed in the last years of the nineteenth century",
		"that this world was being watched keenly and closely by intelligences",
		"greater than man's and yet as mortal as his own...\"",
	]
	for i in quote.size():
		draw_string(serif, Vector2(0, 815 + i * 26), quote[i], HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(cream, 0.75))
	var blink := 0.55 + 0.45 * sin(_t * 3.0)
	draw_string(font, Vector2(0, 950), "CHAPTER I  -  HORSELL COMMON        Press ENTER or click to begin", HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(1, 0.85, 0.5, blink))
