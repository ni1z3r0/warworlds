extends Control
## Main menu over a painted scene in the spirit of 1970s prog-rock album art.
## Blood-red sky, burning horizon, black smoke, and our own fighting-machine
## silhouetted against the fire. All drawn procedurally.

const MODES := [
	["THE STORY", "Play the novel from the beginning, chapter by chapter. Continues where you left off.", "res://scenes/campaign.tscn"],
	["THE FIGHTING BEGINS", "Strategy: escort the narrator, his wife and the landlord to Leatherhead.", "res://scenes/main.tscn"],
	["THE FIGHTING-MACHINE", "First person: you are the Martian. Silence the batteries. Fill the cage.", "res://scenes/pilot.tscn"],
	["THE ARTILLERY", "First person: you are a gunner. Bring the machine down. Free its captives.", "res://scenes/soldier.tscn"],
]
var hover := -1
var serif: Font
var font: Font
var _t := 0.0


func _ready() -> void:
	set_deferred("size", Vector2(World.W, World.H + 100))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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

	# the fighting-machine on the ridge, after Alvim Corrêa: a wide hat with a
	# spike, two round eyes, a ribbed body, needle legs and a curtain of filaments
	var hub := Vector2(470, 250)
	hub.x += sin(_t * 0.8) * 4.0
	var dark := Color(0.03, 0.0, 0.0)
	var hip := hub + Vector2(0, 92)
	var feet := [Vector2(330, 668), Vector2(470, 690), Vector2(640, 660)]
	for i in 3:
		var knee: Vector2 = hip.lerp(feet[i], 0.45) + Vector2(0, -26)
		draw_line(feet[i], knee, dark, 5)
		draw_line(knee, hip, dark, 6)
		for u in [0.3, 0.65]:
			for seg in [[hip, knee], [knee, feet[i]]]:
				var p0: Vector2 = seg[0].lerp(seg[1], u)
				var n: Vector2 = (seg[1] - seg[0]).normalized().orthogonal() * 7.0
				draw_line(p0 - n, p0 + n, dark, 4)
		draw_circle(knee, 6, dark)
		draw_line(knee + Vector2(3, 0), hip + Vector2(3, 0), Color(1, 0.45, 0.1, 0.3), 1.5)
	# filaments
	for k in 22:
		var x := -78.0 + k * 7.4
		var pts := PackedVector2Array()
		var top := hub + Vector2(x, 18 - absf(x) * 0.12)
		var len := 110.0 + 50.0 * sin(k * 1.7)
		for s2 in 8:
			var u := s2 / 7.0
			pts.append(top + Vector2(sin(_t * 1.2 + k + u * 3.0) * 6.0 * u, u * len))
		draw_polyline(pts, dark, 1.5, true)
	# ribbed body
	for k in 6:
		var w2 := 30.0 - k * 4.0
		var y := 34.0 + k * 11.0
		draw_rect(Rect2(hub + Vector2(-w2, y), Vector2(w2 * 2, 8)), dark)
	draw_colored_polygon(PackedVector2Array([hub + Vector2(-10, 100), hub + Vector2(10, 100), hub + Vector2(0, 116)]), dark)
	# the hat
	draw_colored_polygon(PackedVector2Array([hub + Vector2(-96, 22), hub + Vector2(-20, -30), hub + Vector2(20, -30), hub + Vector2(96, 22), hub + Vector2(60, 26), hub + Vector2(-60, 26)]), dark)
	draw_rect(Rect2(hub + Vector2(-22, -40), Vector2(44, 12)), dark)
	draw_line(hub + Vector2(0, -40), hub + Vector2(0, -88), dark, 3)
	draw_line(hub + Vector2(-12, -74), hub + Vector2(12, -74), dark, 2)
	draw_circle(hub + Vector2(0, -90), 5, dark)
	draw_polyline(PackedVector2Array([hub + Vector2(-96, 22), hub + Vector2(-20, -30), hub + Vector2(20, -30), hub + Vector2(96, 22)]), Color(1, 0.4, 0.1, 0.5), 2.5, true)
	# head and two great round eyes under the brim
	draw_circle(hub + Vector2(0, 30), 32, dark)
	for side in [-1.0, 1.0]:
		var e := hub + Vector2(side * 15.0 + 6.0, 30)
		draw_circle(e, 11, Color(0.95, 0.9, 0.8))
		draw_circle(e + Vector2(3, 1), 5, dark)
	# the heat-ray box, held out on a ribbed arm
	var arm := [hub + Vector2(20, 60), hub + Vector2(60, 70), hub + Vector2(92, 52)]
	draw_polyline(PackedVector2Array(arm), dark, 6, true)
	draw_rect(Rect2(hub + Vector2(86, 40), Vector2(26, 22)), dark)
	var eye := hub + Vector2(116, 51)
	draw_circle(eye, 22, Color(0.4, 1.0, 0.5, 0.15))
	draw_circle(eye, 7, Color(0.6, 1.0, 0.7))

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
		draw_string(serif, Vector2(60, 845 + i * 26), quote[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(cream, 0.75))
	for i in MODES.size():
		var r := _option_rect(i)
		var on := i == hover
		draw_rect(r, Color(0.06, 0.02, 0.02, 0.85 if on else 0.7))
		draw_rect(r, Color(1, 0.6, 0.25, 0.95 if on else 0.45), false, 2.0 if on else 1.0)
		draw_string(serif, r.position + Vector2(18, 34), "%d   %s" % [i + 1, MODES[i][0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.85, 0.55) if on else cream)
		draw_string(font, r.position + Vector2(46, 60), MODES[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(cream, 0.75))
	draw_string(font, Vector2(0, 985), "Click a mode or press 1, 2, 3 or 4", HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(cream, 0.5))


func _option_rect(i: int) -> Rect2:
	return Rect2(1000, 500 + i * 84, 560, 74)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = -1
		for i in MODES.size():
			if _option_rect(i).has_point(event.position):
				hover = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hover >= 0:
		_go(hover)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_go(0)
			KEY_2:
				_go(1)
			KEY_3:
				_go(2)
			KEY_4:
				_go(3)


func _go(i: int) -> void:
	get_tree().change_scene_to_file(MODES[i][2])


# screenshot support for docs: --shots=/abs/dir
var _frames := 0


func _physics_process(_d: float) -> void:
	_frames += 1
	if _frames == 30:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots="):
				hover = 1
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(a.substr(8) + "/menu.png")
				get_tree().quit()
