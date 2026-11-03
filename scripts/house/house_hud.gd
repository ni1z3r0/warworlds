extends Control
## HUD for the ruined house: day count, the Curate's nerve, what you carry,
## the light warning, context prompts, the peephole view and endings.

var mode: Node
var font: Font
var serif: Font
var _t := 0.0
var _plates := {}
const CREAM := Color(1.0, 0.92, 0.8)
const AMBER := Color(1.0, 0.75, 0.45)
const GREEN := Color(0.55, 1.0, 0.6)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["DejaVu Serif", "Georgia", "Times New Roman", "serif"])
	serif = sf


func _process(delta: float) -> void:
	_t += delta
	size = get_viewport_rect().size
	queue_redraw()


func _plate(f: String) -> Texture2D:
	if not _plates.has(f):
		_plates[f] = load("res://art/correa/" + f)
	return _plates[f]


func _panel(r: Rect2) -> void:
	draw_rect(r, Color(0.06, 0.03, 0.02, 0.82))
	draw_rect(r, Color(0.8, 0.38, 0.15, 0.55), false, 1.0)


func _bar(r: Rect2, f: float, c: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0, 1), r.size.y)), c)
	draw_rect(r, Color(1, 1, 1, 0.2), false, 1.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var m = mode

	# title and day
	_panel(Rect2(12, 12, 520, 74))
	draw_string(serif, Vector2(24, 38), "VI. THE RUINED HOUSE  -  Day %d of %d" % [m.day, m.DAYS], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, AMBER)
	var goal := "Survive until the Martians leave the pit." if not m.map.hole_open else "The pit is empty. Climb out through the hole in the scullery!"
	draw_string(font, Vector2(24, 60), goal, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CREAM)
	_bar(Rect2(24, 68, 496, 6), m.time / (m.DAY * m.DAYS), Color(0.75, 0.55, 0.3))

	# the curate
	var x := w - 360.0
	_panel(Rect2(x, 12, 348, 96))
	draw_texture_rect(Cast.portrait("curate"), Rect2(x + 6, 18, 63, 84), false, Color(1, 1, 1) if m.cstate != m.C.TAKEN else Color(0.5, 0.3, 0.3))
	draw_string(serif, Vector2(x + 80, 38), "THE CURATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AMBER)
	var st: String = ["Quiet", "Muttering in the dark", "BREAKING! Stop him!", "Unconscious", "Taken by the Martians", "Free"][m.cstate]
	var sc := CREAM
	if m.cstate == m.C.BROKEN:
		sc = Color(1, 0.4, 0.3, 0.6 + 0.4 * sin(_t * 10))
	elif m.cstate == m.C.TAKEN:
		sc = Color(0.9, 0.35, 0.3)
	draw_string(font, Vector2(x + 80, 58), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, sc)
	draw_string(font, Vector2(x + 80, 82), "Nerve", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)
	var nc := Color(0.6, 0.9, 0.6).lerp(Color(1, 0.35, 0.25), 1.0 - m.nerve / 100.0)
	_bar(Rect2(x + 124, 72, 210, 12), m.nerve / 100.0, nc)
	if m.calm_hold > 0.0:
		_bar(Rect2(x + 124, 90, 210, 5), m.calm_hold / 1.2, GREEN)

	# the narrator
	_panel(Rect2(12, h - 108, 380, 96))
	draw_texture_rect(Cast.portrait("narrator"), Rect2(18, h - 102, 63, 84), false)
	draw_string(serif, Vector2(92, h - 82), "THE NARRATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, AMBER)
	var me := "Hidden under the coal" if m.in_coal else ("Watching through the peephole" if m.peeping else ("Carrying food for the Curate" if m.carrying else "Creeping"))
	draw_string(font, Vector2(92, h - 60), me, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CREAM)
	draw_string(font, Vector2(92, h - 40), "Rations left in the pantry: %d" % m.rations, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CREAM, 0.7))
	draw_string(font, Vector2(92, h - 22), "Shift hurries (loud). Crockery is loud.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(CREAM, 0.5))

	# the light
	if m.gaze == m.G.WARN:
		_banner("THE LIGHT IS TURNING TOWARD THE HOUSE", Color(0.6, 1.0, 0.6, 0.6 + 0.4 * sin(_t * 14)))
	elif m.gaze == m.G.LOOK:
		_banner("THE MARTIAN IS LOOKING IN. STAY OUT OF THE LIGHT.", Color(0.7, 1.0, 0.6))
	if m.touched_t > 0.0:
		_banner("IT IS TOUCHING YOUR BOOT. DON'T MOVE.", Color(1, 0.35, 0.25, 0.7 + 0.3 * sin(_t * 18)), 160.0)

	# context prompt by the narrator
	var act: String = m.context_action()
	if act != "" and not m.ended:
		var p: Vector2 = m.narrator.get_global_transform_with_canvas().origin + Vector2(0, 34)
		draw_string_outline(font, p - Vector2(150, 0), act, HORIZONTAL_ALIGNMENT_CENTER, 300, 14, 4, Color(0, 0, 0, 0.85))
		draw_string(font, p - Vector2(150, 0), act, HORIZONTAL_ALIGNMENT_CENTER, 300, 14, AMBER)

	# messages
	var my := h - 120.0
	for i in range(m.messages.size() - 1, -1, -1):
		var msg: Dictionary = m.messages[i]
		var a := clampf(1.0 - (m.time - msg.t - 9.0) / 3.0, 0.0, 1.0)
		if a <= 0.0:
			continue
		draw_string_outline(font, Vector2(410, my), msg.text, HORIZONTAL_ALIGNMENT_LEFT, w - 430, 14, 4, Color(0, 0, 0, 0.8 * a))
		draw_string(font, Vector2(410, my), msg.text, HORIZONTAL_ALIGNMENT_LEFT, w - 430, 14, Color(CREAM, a))
		my -= 20.0

	if m.peeping:
		_peephole(w, h)
	if m.show_help and not m.ended and not m.peeping:
		_help(w, h)
	if m.paused and not m.ended:
		_overlay(w, h, "PAUSED", "Esc resume     R restart     M main menu", AMBER)
	if m.ended:
		var won: bool = m.result == "won"
		_overlay(w, h, "YOU ESCAPED THE HOUSE" if won else "TAKEN", m.ending + ("\n\nEnter continue the story     R play again     M main menu" if (won and CampaignState.active) else "\n\nR play again     M main menu"), GREEN if won else Color(1, 0.45, 0.3))


func _banner(text: String, c: Color, y: float = 120.0) -> void:
	draw_string_outline(serif, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, 6, Color(0, 0, 0, 0.8))
	draw_string(serif, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, c)


func _peephole(w: float, h: float) -> void:
	var m = mode
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.015, 0.01))
	var f := "plate_0195.jpg" if m.day < 6 else ("plate_0203.jpg" if m.day < 14 else "plate_0247.jpg")
	var tex := _plate(f)
	var slit := Rect2(w * 0.5 - 380, h * 0.5 - 300, 760, 560)
	var ts := tex.get_size()
	var src := Rect2(0, ts.y * 0.15, ts.x, ts.x * slit.size.y / slit.size.x)
	draw_texture_rect_region(tex, slit, src)
	# ragged edges of the slit in the debris
	for k in 40:
		var y := slit.position.y + k * 14.0
		draw_rect(Rect2(slit.position.x - 4, y, 18 + 14 * absf(sin(k * 1.7)), 14), Color(0.02, 0.015, 0.01))
		draw_rect(Rect2(slit.end.x - 14 - 14 * absf(sin(k * 2.3)), y, 18 + 14 * absf(sin(k * 2.3)), 14), Color(0.02, 0.015, 0.01))
	draw_string(serif, Vector2(0, slit.position.y - 18), "Through the peephole: the Martians' pit", HORIZONTAL_ALIGNMENT_CENTER, w, 18, AMBER)
	var y0 := slit.end.y + 30
	if m.martians_gone:
		draw_string(font, Vector2(0, y0), "The pit is silent. The red weed is everywhere.", HORIZONTAL_ALIGNMENT_CENTER, w, 15, CREAM)
	else:
		draw_string(font, Vector2(w * 0.5 - 300, y0), "How alert they are", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CREAM)
		_bar(Rect2(w * 0.5 - 150, y0 - 12, 300, 14), m.susp / 100.0, Color(0.6, 1.0, 0.6).lerp(Color(1, 0.3, 0.2), m.susp / 100.0))
		var nxt := "now!" if m.gaze != m.G.IDLE else "%.0f s" % m.gaze_t
		draw_string(font, Vector2(w * 0.5 - 300, y0 + 26), "Next sweep of the light: %s" % nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CREAM)
	draw_string(font, Vector2(0, y0 + 56), "E or Esc  step back", HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(CREAM, 0.6))


func _help(w: float, h: float) -> void:
	var lines := [
		["GOAL", "Survive 15 days beside the Martians' pit."],
		["", "Keep the Curate alive if you can."],
		["W A S D", "creep (quiet).  Shift: hurry (loud)"],
		["Crockery", "the white shards: loud underfoot"],
		["Green light", "stay out of it when the light turns"],
		["E", "pantry: take food / Curate: give food"],
		["Hold E", "by the Curate: calm him"],
		["F", "strike him, if he breaks and goes"],
		["E at coal", "hide. If it touches you, don't move"],
		["E at slit", "peephole: see how alert they are"],
		["F1 / Esc / R / M", "guide / pause / restart / menu"],
	]
	var r := Rect2(w - 520, 130, 508, 50 + lines.size() * 22)
	draw_rect(r, Color(0.05, 0.02, 0.02, 0.85))
	draw_rect(r, Color(0.8, 0.38, 0.15, 0.7), false, 1.0)
	draw_string(serif, r.position + Vector2(16, 28), "HOW TO SURVIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, AMBER)
	for i in lines.size():
		var y := r.position.y + 54 + i * 22
		draw_string(font, Vector2(r.position.x + 16, y), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CREAM)
		draw_string(font, Vector2(r.position.x + 150, y), lines[i][1], HORIZONTAL_ALIGNMENT_LEFT, 350, 13, Color(CREAM, 0.7))


func _overlay(w: float, h: float, head: String, sub: String, c: Color) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.6))
	draw_string(serif, Vector2(0, h * 0.38), head, HORIZONTAL_ALIGNMENT_CENTER, w, 46, c)
	var lines := sub.split("\n")
	var y := h * 0.38 + 50
	for line in lines:
		# wrap long lines
		var words := line.split(" ")
		var cur := ""
		for wd in words:
			var trial := wd if cur == "" else cur + " " + wd
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x > 900 and cur != "":
				draw_string(font, Vector2(0, y), cur, HORIZONTAL_ALIGNMENT_CENTER, w, 17, CREAM)
				y += 24
				cur = wd
			else:
				cur = trial
		draw_string(font, Vector2(0, y), cur, HORIZONTAL_ALIGNMENT_CENTER, w, 17, CREAM)
		y += 24
