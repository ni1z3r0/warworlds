extends Control
## Cockpit overlay for the fighting-machine: the cowl's viewing slit, a
## Martian reticle, and readouts for shield, hull, heat-ray, cage and sickness.

var mode: Node
var font: Font
var serif: Font
var _t := 0.0
const GREEN := Color(0.45, 1.0, 0.6)
const AMBER := Color(1.0, 0.75, 0.45)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["DejaVu Serif", "Georgia", "Times New Roman", "serif"])
	serif = sf


func _process(delta: float) -> void:
	_t += delta
	size = get_viewport_rect().size
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := Vector2(w, h) * 0.5
	if not mode.third_person:
		_cockpit(w, h)
	# reticle
	var g := Color(GREEN, 0.75)
	draw_arc(c, 22, 0, TAU, 40, g, 1.5)
	for k in 3:
		var a := _t * 0.6 + k * TAU / 3.0
		draw_arc(c, 34, a, a + 0.7, 10, Color(GREEN, 0.5), 2.0)
		draw_line(c + Vector2.from_angle(a + 0.35) * 40, c + Vector2.from_angle(a + 0.35) * 50, g, 1.5)
	draw_circle(c, 2.0, g)
	# heat-ray energy ring
	var e: float = mode.ray_energy / 100.0
	var ec := Color(1, 0.4, 0.3) if mode.overheated else GREEN
	draw_arc(c, 60, PI * 0.75, PI * 0.75 + PI * 1.5 * e, 48, Color(ec, 0.7), 3.0)
	if mode.overheated:
		draw_string(font, c + Vector2(-60, 86), "RAY EXHAUSTED", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 0.4, 0.3))

	# vitals, bottom left
	var x := 40.0
	var y := h - 150.0
	_label(Vector2(x, y), "SHIELD", GREEN)
	if mode.shield_up():
		_bar(Rect2(x + 80, y - 12, 220, 12), mode.shield / 100.0, GREEN)
	else:
		_bar(Rect2(x + 80, y - 12, 220, 12), 0.0, GREEN)
		draw_string(font, Vector2(x + 88, y - 1), "DOWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.5, 0.3, 0.6 + 0.4 * sin(_t * 10)))
	_label(Vector2(x, y + 26), "HULL", AMBER)
	_bar(Rect2(x + 80, y + 14, 220, 12), mode.hull / 100.0, Color(1, 0.55, 0.25))
	_label(Vector2(x, y + 52), "SMOKE", Color(0.8, 0.8, 0.8))
	var sm: float = mode.smoke_cd
	draw_string(font, Vector2(x + 80, y + 52), "READY  [F]" if sm <= 0.0 else "%.0fs" % sm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.85))
	if mode.sickness > 0.12:
		_label(Vector2(x, y + 78), "EARTH'S AIR", Color(0.85, 0.7, 1.0))
		_bar(Rect2(x + 110, y + 66, 190, 12), mode.sickness, Color(0.65, 0.45, 0.85))

	# objectives, bottom right
	var rx := w - 330.0
	_label(Vector2(rx, y), "BATTERIES", AMBER)
	var left: int = mode._guns_left()
	for i in mode.batteries.size():
		var on: bool = i < left
		draw_rect(Rect2(rx + 120 + i * 30, y - 13, 22, 14), Color(1, 0.55, 0.25) if on else Color(0.25, 0.12, 0.08))
	_label(Vector2(rx, y + 30), "CAGE", GREEN)
	for i in Tripod3D.CAGE_SIZE:
		var p := Vector2(rx + 128 + i * 26, y + 24)
		if i < mode.machine.captives:
			draw_circle(p, 7, Color(0.9, 0.75, 0.6))
		draw_arc(p, 9, 0, TAU, 16, Color(GREEN, 0.6), 1.5)
	if not Touch.is_touch():
		draw_string(font, Vector2(rx, y + 60), "F1  controls guide", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.45))

	# messages, top centre
	var my := 70.0
	for i in range(mode.messages.size() - 1, -1, -1):
		var m: Dictionary = mode.messages[i]
		var age: float = mode.time - m.t
		var a := clampf(1.0 - (age - 6.0) / 3.0, 0.0, 1.0)
		if a <= 0.0:
			continue
		draw_string_outline(font, Vector2(0, my), m.text, HORIZONTAL_ALIGNMENT_CENTER, w, 17, 5, Color(0, 0, 0, 0.7 * a))
		draw_string(font, Vector2(0, my), m.text, HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color(GREEN.lerp(Color.WHITE, 0.5), a))
		my += 24.0

	if mode.shake > 0.4:
		draw_rect(Rect2(0, 0, w, h), Color(1, 0.4, 0.1, (mode.shake - 0.4) * 0.25))

	if mode.show_help and not mode.ended:
		_help([
			["GOAL", "Silence all 5 artillery batteries."],
			["", "Fill your cage with humans."],
			["", "Finish before Earth's air kills you."],
			["", ""],
			["Mouse", "look and steer"],
			["W A S D / Shift", "walk / stride faster"],
			["Hold left mouse", "HEAT-RAY (watch the energy ring)"],
			["Right-click or E", "grab a nearby human into the cage"],
			["F", "fire a black-smoke canister"],
			["V", "cockpit view / view from behind"],
			["Esc  /  R  /  M", "pause / restart / main menu"],
			["F1 or H", "show or hide this guide"],
		], "THE FIGHTING-MACHINE")
	if mode.paused and not mode.ended:
		_overlay(w, h, "PAUSED", "Esc resume     R restart     M main menu", AMBER)
	if mode.ended:
		if mode.result == "won":
			_overlay(w, h, "THE GUNS ARE SILENT", "%d humans caged, %d houses burned.  But the air of this world burns in you...\n\n%s" % [mode.machine.captives, mode.houses_burned, "Enter continue the story     R play again     M main menu" if CampaignState.active else "R play again     M main menu"], GREEN)
		else:
			_overlay(w, h, "THE MACHINE FALLS", "You were %s.\n\nR try again     M main menu" % str(get_meta("why", "destroyed")), Color(1, 0.45, 0.3))


func _cockpit(w: float, h: float) -> void:
	var dark := Color(0.05, 0.03, 0.025)
	var rim := Color(1.0, 0.45, 0.15, 0.8)
	# the hood's brow
	var top := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.16)])
	for i in range(20, -1, -1):
		var u := i / 20.0
		top.append(Vector2(u * w, h * 0.04 + sin(u * PI) * -h * 0.0 + (1.0 - sin(u * PI)) * h * 0.13))
	top.append(Vector2(0, h * 0.16))
	draw_colored_polygon(top, dark)
	# side frames
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.07, h * 0.1), Vector2(w * 0.035, h), Vector2(0, h)]), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w * 0.93, h * 0.1), Vector2(w * 0.965, h), Vector2(w, h)]), dark)
	# lower sill
	draw_colored_polygon(PackedVector2Array([Vector2(0, h), Vector2(0, h * 0.86), Vector2(w * 0.3, h * 0.9), Vector2(w * 0.7, h * 0.9), Vector2(w, h * 0.86), Vector2(w, h)]), Color(dark, 0.92))
	draw_polyline(PackedVector2Array([Vector2(w * 0.07, h * 0.1), Vector2(w * 0.035, h)]), rim, 2.0)
	draw_polyline(PackedVector2Array([Vector2(w * 0.93, h * 0.1), Vector2(w * 0.965, h)]), rim, 2.0)
	draw_polyline(PackedVector2Array([Vector2(0, h * 0.86), Vector2(w * 0.3, h * 0.9), Vector2(w * 0.7, h * 0.9), Vector2(w, h * 0.86)]), rim, 2.0)
	var brow := PackedVector2Array()
	for i in 21:
		var u := i / 20.0
		brow.append(Vector2(u * w, h * 0.04 + (1.0 - sin(u * PI)) * h * 0.13))
	draw_polyline(brow, rim, 2.0)
	# rivets
	for i in 9:
		var u := 0.1 + i * 0.1
		draw_circle(Vector2(u * w, h * 0.04 + (1.0 - sin(u * PI)) * h * 0.13 - 10), 3, Color(0.35, 0.22, 0.15))
	# faint green tint of the lens
	draw_rect(Rect2(0, 0, w, h), Color(0.2, 1.0, 0.4, 0.035))


func _label(p: Vector2, s: String, c: Color) -> void:
	draw_string(serif, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)


func _bar(r: Rect2, f: float, c: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0, 1), r.size.y)), c)
	draw_rect(r, Color(1, 1, 1, 0.2), false, 1.0)


func _overlay(w: float, h: float, head: String, sub: String, c: Color) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
	draw_string(serif, Vector2(0, h * 0.42), head, HORIZONTAL_ALIGNMENT_CENTER, w, 46, c)
	var lines := sub.split("\n")
	for i in lines.size():
		draw_string(font, Vector2(0, h * 0.42 + 50 + i * 24), lines[i], HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color(1, 0.92, 0.8))


func _help(lines: Array, title: String) -> void:
	var w := 590.0
	var h := 50.0 + lines.size() * 22.0
	var r := Rect2(24, size.y * 0.5 - h * 0.5, w, h)
	draw_rect(r, Color(0.05, 0.02, 0.02, 0.82))
	draw_rect(r, Color(0.8, 0.38, 0.15, 0.7), false, 1.0)
	draw_string(serif, r.position + Vector2(16, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.75, 0.45))
	for i in lines.size():
		var y := r.position.y + 54 + i * 22
		draw_string(font, Vector2(r.position.x + 16, y), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.92, 0.8))
		draw_string(font, Vector2(r.position.x + 190, y), lines[i][1], HORIZONTAL_ALIGNMENT_LEFT, 390, 14, Color(1.0, 0.92, 0.8, 0.7))
