extends Control
## In-game HUD: objective, the machine's status, unit cards, message log, help.

var main: Node
var font: Font
var serif: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(World.W, World.H + 100)
	font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["DejaVu Serif", "Georgia", "Times New Roman", "Liberation Serif", "serif"])
	serif = sf


func _process(_delta: float) -> void:
	queue_redraw()


func _panel(r: Rect2) -> void:
	draw_rect(r, Color(0.06, 0.02, 0.02, 0.78))
	draw_rect(r, Color(0.8, 0.38, 0.15, 0.55), false, 1.0)


func _bar(r: Rect2, frac: float, c: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), c)
	draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)


func _text(p: Vector2, s: String, sz: int, c: Color, f: Font = null) -> void:
	draw_string(f if f else font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _draw() -> void:
	if not main.started:
		return
	var cream := Color(0.97, 0.88, 0.76)
	var amber := Color(1.0, 0.78, 0.5)

	# objective
	_panel(Rect2(12, 12, 470, 78))
	_text(Vector2(24, 36), "IX. THE FIGHTING BEGINS  -  HORSELL COMMON, 1898", 16, amber, serif)
	_text(Vector2(24, 58), "Get the survivors across the river to the Leatherhead road.", 13, cream)
	var esc := 0
	var lost := 0
	var taken := 0
	for u in main.roster:
		if u is Survivor:
			if u.escaped:
				esc += 1
			elif not u.alive:
				lost += 1
			elif u.captured:
				taken += 1
	var mt: float = main.mission_time
	_text(Vector2(24, 78), "Escaped %d / 3     Lost %d     Caged %d     %d:%02d" % [esc, lost, taken, int(mt) / 60, int(mt) % 60], 13, Color(cream, 0.8))

	# the machine
	var t: Tripod = main.tripod
	var x := World.W - 352.0
	_panel(Rect2(x, 12, 340, 118))
	_text(Vector2(x + 12, 36), "MARTIAN FIGHTING-MACHINE", 16, Color(0.6, 1.0, 0.65), serif)
	var st_col := Color(1, 0.4, 0.3) if t.state in [Tripod.S.CHARGE, Tripod.S.HUNT] else cream
	_text(Vector2(x + 12, 56), t.status_text(), 13, st_col)
	_text(Vector2(x + 12, 78), "Shield", 12, cream)
	if t.shield_up():
		_bar(Rect2(x + 70, 68, 150, 11), t.shield / Tripod.SHIELD_MAX, Color(0.4, 0.95, 0.7))
	elif t.is_active():
		_bar(Rect2(x + 70, 68, 150, 11), 0.0, Color(0.4, 0.95, 0.7))
		_text(Vector2(x + 76, 78), "DOWN - FIRE NOW!", 11, Color(1, 0.85, 0.3, 0.6 + 0.4 * sin(mt * 10.0)))
	else:
		_bar(Rect2(x + 70, 68, 150, 11), 0.0, Color(0.4, 0.95, 0.7))
	_text(Vector2(x + 232, 78), "Hull", 12, cream)
	for i in 3:
		var c := Color(0.95, 0.45, 0.2) if i < t.hull else Color(0.2, 0.1, 0.08)
		draw_rect(Rect2(x + 266 + i * 22, 68, 16, 11), c)
	if t.sickness > 0.3:
		_text(Vector2(x + 12, 102), "Ailing", 12, Color(0.85, 0.75, 0.95))
		_bar(Rect2(x + 70, 92, 258, 11), t.sickness, Color(0.6, 0.45, 0.75))
		_text(Vector2(x + 12, 122), "Something on Earth is killing them.", 11, Color(0.85, 0.75, 0.95, 0.75))
	else:
		_text(Vector2(x + 12, 102), "Shells only hurt it while the shield is down.", 11, Color(cream, 0.6))

	# command strip below the map
	draw_rect(Rect2(0, World.H, World.W, 100), Color(0.05, 0.015, 0.015))
	draw_line(Vector2(0, World.H), Vector2(World.W, World.H), Color(0.8, 0.38, 0.15, 0.7), 2.0)
	for i in main.roster.size():
		var u: Unit = main.roster[i]
		var r := Rect2(12 + i * 276, World.H + 14, 266, 72)
		_panel(r)
		if u.selected:
			draw_rect(r, Color(1, 0.85, 0.45, 0.9), false, 2.0)
		var dim := 1.0 if (u.alive and not u.escaped) else 0.45
		var tx := 38.0
		if u.portrait_id != "":
			draw_texture_rect(Cast.portrait(u.portrait_id), Rect2(r.position + Vector2(4, 4), Vector2(48, 64)), false, Color(1, 1, 1, dim) if u.alive else Color(0.5, 0.3, 0.3, 0.7))
			tx = 60.0
		_text(r.position + Vector2(tx, 20), "[%d] %s" % [i + 1, u.display_name], 15, Color(cream, dim), serif)
		_text(r.position + Vector2(tx, 38), u.role, 11, Color(cream, 0.6 * dim))
		var sc := cream
		var s := u.status_text()
		if s.begins_with("LOST"):
			sc = Color(0.9, 0.35, 0.3)
		elif s == "ESCAPED" or s == "WITHDRAWN" or s == "READY TO FIRE":
			sc = Color(0.6, 1.0, 0.6)
		elif s.ends_with("!"):
			sc = Color(1, 0.55, 0.3)
		_text(r.position + Vector2(tx, 58), s, 12, sc)
		if u.alive and not u.escaped and u.hp < 0.999:
			_bar(Rect2(r.position.x + 190, r.position.y + 12, 66, 6), u.hp, Color(0.9, 0.3, 0.2))

	# message log
	# message log in the command strip, newest at the top
	var y := World.H + 28.0
	var shown := 0
	for i in range(main.messages.size() - 1, -1, -1):
		if shown >= 4:
			break
		var m: Dictionary = main.messages[i]
		var age: float = main.mission_time - m.t
		var a := clampf(1.0 - (age - 12.0) / 4.0, 0.25, 1.0) * (1.0 if shown == 0 else 0.75)
		draw_string(font, Vector2(1122, y), m.text, HORIZONTAL_ALIGNMENT_LEFT, 470, 13, Color(1, 0.9, 0.75, a))
		y += 19.0
		shown += 1

	# selection box
	if main.dragging:
		var dr := Rect2(main.drag_start, main.drag_end - main.drag_start).abs()
		draw_rect(dr, Color(1, 0.8, 0.4, 0.10))
		draw_rect(dr, Color(1, 0.8, 0.4, 0.7), false, 1.0)

	# help
	if main.show_help:
		var hr := Rect2(World.W - 352, 140, 340, 238)
		_panel(hr)
		var lines := [
			["Left-click / drag", "select"],
			["Right-click", "move"],
			["Right-click a cellar", "hide there"],
			["H", "hide in nearest cellar"],
			["D", "unlimber / limber the gun"],
			["Right-click (gun ready)", "fire"],
			["1-4  /  A", "select unit / all"],
			["Space", "pause"],
			["R  /  M", "restart / main menu"],
			["F1", "hide this help"],
		]
		_text(hr.position + Vector2(12, 22), "ORDERS", 14, amber, serif)
		for i in lines.size():
			_text(hr.position + Vector2(12, 44 + i * 19), lines[i][0], 12, cream)
			_text(hr.position + Vector2(190, 44 + i * 19), lines[i][1], 12, Color(cream, 0.65))

	if main.get_tree().paused and not main.ended:
		_text(Vector2(World.W / 2.0 - 60, 120), "PAUSED", 32, amber, serif)

	if main.ended:
		var er := Rect2(World.W / 2.0 - 320, World.H / 2.0 - 120, 640, 220)
		draw_rect(Rect2(0, 0, World.W, World.H), Color(0, 0, 0, 0.45))
		_panel(er)
		var won: bool = main.result == "won"
		var head := ("THEY GOT AWAY" if t.is_active() else "THEY SURVIVED") if won else "NO ONE ESCAPED"
		draw_string(serif, er.position + Vector2(0, 62), head, HORIZONTAL_ALIGNMENT_CENTER, er.size.x, 40, amber if won else Color(1, 0.4, 0.3))
		var sub := "%d of 3 reached the Leatherhead road." % esc
		if not t.is_active() and won:
			sub = "%d escaped, %d lived to see the machine fall." % [esc, 3 - esc - lost]
		draw_string(font, er.position + Vector2(0, 104), sub, HORIZONTAL_ALIGNMENT_CENTER, er.size.x, 16, cream)
		if t.is_active() and taken > 0:
			draw_string(font, er.position + Vector2(0, 132), "%d carried off in the machine's cage." % taken, HORIZONTAL_ALIGNMENT_CENTER, er.size.x, 15, Color(1, 0.6, 0.4))
		if not t.is_active():
			draw_string(font, er.position + Vector2(0, 132), "The machine was %s." % t.death_cause, HORIZONTAL_ALIGNMENT_CENTER, er.size.x, 15, Color(0.6, 1.0, 0.65))
		draw_string(font, er.position + Vector2(0, 186), "Enter  continue the story      R  play again      M  main menu" if (won and Progress.active) else "R  play again        M  main menu", HORIZONTAL_ALIGNMENT_CENTER, er.size.x, 14, Color(cream, 0.7))
