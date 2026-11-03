extends Control
## Soldier HUD: crosshair or gun-sight, the Martian "eye" that shows how close
## it is to seeing you, the machine's state, prompts and messages.

var mode: Node
var font: Font
var serif: Font
var _t := 0.0
const CREAM := Color(1.0, 0.92, 0.8)
const AMBER := Color(1.0, 0.75, 0.45)
const GREEN := Color(0.5, 1.0, 0.6)


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


func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := Vector2(w, h) * 0.5

	if mode.manning != null:
		_gun_sight(c, w, h)
	else:
		draw_line(c + Vector2(-9, 0), c + Vector2(-3, 0), Color(CREAM, 0.8), 1.5)
		draw_line(c + Vector2(3, 0), c + Vector2(9, 0), Color(CREAM, 0.8), 1.5)
		draw_line(c + Vector2(0, -9), c + Vector2(0, -3), Color(CREAM, 0.8), 1.5)
		draw_line(c + Vector2(0, 3), c + Vector2(0, 9), Color(CREAM, 0.8), 1.5)

	_eye(Vector2(w * 0.5, 54))
	_machine_panel(w)

	# health and stance
	_panel(Rect2(20, h - 92, 330, 72))
	draw_texture_rect(Cast.portrait("artilleryman"), Rect2(24, h - 88, 48, 64), false)
	draw_string(serif, Vector2(82, h - 66), "THE ARTILLERYMAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AMBER)
	_bar(Rect2(82, h - 58, 250, 8), mode.hp / 100.0, Color(0.9, 0.3, 0.2))
	var stance := "CROUCHED  (C)" if mode.crouched else ("SPRINTING" if mode.sprinting else "Standing  (C to crouch)")
	draw_string(font, Vector2(82, h - 40), stance, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CREAM, 0.7))
	draw_string(font, Vector2(w - 200, h - 30), "F1  gunner's guide", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(CREAM, 0.6))

	if mode.near_gun != null and mode.manning == null and not mode.ended:
		draw_string_outline(font, Vector2(0, h * 0.62), "E  -  take the gun", HORIZONTAL_ALIGNMENT_CENTER, w, 20, 5, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(0, h * 0.62), "E  -  take the gun", HORIZONTAL_ALIGNMENT_CENTER, w, 20, AMBER)

	# messages
	var my := 150.0
	for i in range(mode.messages.size() - 1, -1, -1):
		var m: Dictionary = mode.messages[i]
		var a := clampf(1.0 - (mode.time - m.t - 7.0) / 3.0, 0.0, 1.0)
		if a <= 0.0:
			continue
		draw_string_outline(font, Vector2(24, my), m.text, HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, 15, 5, Color(0, 0, 0, 0.7 * a))
		draw_string(font, Vector2(24, my), m.text, HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, 15, Color(CREAM, a))
		my += 22.0

	if mode.manning == null and not mode.ended:
		_gun_markers()
	if mode.show_help and not mode.ended:
		_help([
			["GOAL", "Bring the machine down. Free its captives."],
			["1. Find a gun", "Follow the GUN markers (yellow diamonds)."],
			["2. Take it", "Walk up to it and press E."],
			["3. Aim", "Mouse moves the gun. Get ON TARGET."],
			["4. Fire", "Click. Reload takes 4 s."],
			["5. Survive", "If the eye fills, hide behind a building."],
			["", ""],
			["W A S D / Mouse", "move / look"],
			["Shift / Space / C", "sprint / jump / crouch (harder to see)"],
			["E", "take or leave a gun"],
			["Esc  /  R  /  M", "pause / restart / main menu"],
			["F1 or H", "show or hide this guide"],
		], "GUNNER'S GUIDE")
	if mode.paused and not mode.ended:
		_overlay(w, h, "PAUSED", "WASD move  Shift sprint  C crouch  E take/leave gun  Click fire\nEsc resume     R restart     M main menu", AMBER)
	elif mode.ended and mode.result == "lost":
		_overlay(w, h, "YOU ARE DEAD", "You were %s.\n\nR try again     M main menu" % mode.why, Color(1, 0.45, 0.3))
	elif mode.ended and mode.result == "won":
		var freed: int = mode.machine.captives
		_overlay(w, h, "THE MACHINE IS DOWN", "It was %s.\n%d people freed from its cage.\n\nR play again     M main menu" % [mode.death_cause, freed], GREEN)


func _gun_markers() -> void:
	var cam: Camera3D = mode.cam
	for i in mode.guns.size():
		var g: FieldGun3D = mode.guns[i]
		var p: Vector3 = g.global_position + Vector3(0, 2.5, 0)
		var d: float = p.distance_to(cam.global_position)
		var s: Vector2
		var behind := cam.is_position_behind(p)
		if behind:
			# point at the screen edge in the gun's direction
			var local := cam.global_transform.affine_inverse() * p
			s = size * 0.5 + Vector2(-local.x, 0).normalized() * size.x * 0.45
			s.y = size.y * 0.75
		else:
			s = cam.unproject_position(p)
			s = s.clamp(Vector2(40, 140), size - Vector2(40, 120))
		var col := Color(1, 0.85, 0.3, 0.95 if d < 4.5 else 0.8)
		var dm := PackedVector2Array([s + Vector2(0, -9), s + Vector2(9, 0), s + Vector2(0, 9), s + Vector2(-9, 0)])
		draw_colored_polygon(dm, Color(col, 0.35))
		dm.append(dm[0])
		draw_polyline(dm, col, 2.0)
		draw_string_outline(font, s + Vector2(-60, -16), "GUN %d  %d m" % [i + 1, int(d)], HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 4, Color(0, 0, 0, 0.8))
		draw_string(font, s + Vector2(-60, -16), "GUN %d  %d m" % [i + 1, int(d)], HORIZONTAL_ALIGNMENT_CENTER, 120, 13, col)


func _gun_sight(c: Vector2, w: float, h: float) -> void:
	var col := Color(0.05, 0.03, 0.02, 0.85)
	# round sight tube
	var r := minf(w, h) * 0.42
	var band := 1400.0
	draw_arc(c, r + band * 0.5, 0, TAU, 128, col, band)
	draw_arc(c, r, 0, TAU, 96, Color(0.6, 0.4, 0.25), 3.0)
	var lc := Color(0.1, 0.05, 0.03, 0.9)
	draw_line(c + Vector2(-r, 0), c + Vector2(-14, 0), lc, 2.0)
	draw_line(c + Vector2(14, 0), c + Vector2(r, 0), lc, 2.0)
	draw_line(c + Vector2(0, -r), c + Vector2(0, -14), lc, 2.0)
	for k in range(1, 6):
		draw_line(c + Vector2(-8, k * 26), c + Vector2(8, k * 26), lc, 1.5)
	var g: FieldGun3D = mode.manning
	var el := rad_to_deg(g.barrel_pivot.rotation.x)
	draw_string(font, c + Vector2(r * 0.55, r * 0.75), "Elev. %+.1f deg" % el, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AMBER)
	var ready_txt := "READY - click to fire" if g.reload <= 0.0 else "Reloading %.1f" % g.reload
	draw_string(font, c + Vector2(-r * 0.9, r * 0.75), ready_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GREEN if g.reload <= 0.0 else AMBER)
	if mode.on_target:
		draw_string(serif, c + Vector2(-100, -r * 0.7), "ON TARGET", HORIZONTAL_ALIGNMENT_CENTER, 200, 22, Color(1, 0.35, 0.25, 0.6 + 0.4 * sin(_t * 10)))
	draw_string(font, c + Vector2(-200, r * 0.88), "The glowing line shows where the shell will fall.   E leave the gun", HORIZONTAL_ALIGNMENT_CENTER, 400, 12, Color(CREAM, 0.55))


func _eye(p: Vector2) -> void:
	var a: float = mode.awareness
	var charging: bool = mode.state == mode.S.CHARGE
	var col := Color(0.5, 1.0, 0.6).lerp(Color(1, 0.25, 0.15), a)
	var open := 4.0 + a * 16.0
	var pts := PackedVector2Array()
	for i in 17:
		var u := i / 16.0
		pts.append(p + Vector2(lerpf(-34, 34, u), -sin(u * PI) * open))
	for i in range(16, -1, -1):
		var u := i / 16.0
		pts.append(p + Vector2(lerpf(-34, 34, u), sin(u * PI) * open))
	draw_colored_polygon(pts, Color(0.05, 0.02, 0.02, 0.85))
	draw_polyline(pts, Color(col, 0.9), 2.0, true)
	draw_circle(p, 3.0 + a * 6.0, col)
	if mode.seen:
		draw_string(font, p + Vector2(-100, 34), "IT SEES YOU", HORIZONTAL_ALIGNMENT_CENTER, 200, 14, col)
	if charging:
		draw_string(serif, p + Vector2(-200, 58), "HEAT-RAY CHARGING - BREAK ITS LINE OF SIGHT!", HORIZONTAL_ALIGNMENT_CENTER, 400, 16, Color(1, 0.3, 0.2, 0.6 + 0.4 * sin(_t * 14)))


func _machine_panel(w: float) -> void:
	var x := w - 330.0
	_panel(Rect2(x, 16, 314, 112))
	draw_string(serif, Vector2(x + 12, 40), "FIGHTING-MACHINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GREEN)
	draw_string(font, Vector2(x + 12, 60), mode.status_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CREAM)
	draw_string(font, Vector2(x + 12, 82), "Shield", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)
	if mode.shield_up():
		_bar(Rect2(x + 64, 72, 130, 11), mode.shield / 100.0, GREEN)
	else:
		_bar(Rect2(x + 64, 72, 130, 11), 0.0, GREEN)
		if mode.machine_active():
			draw_string(font, Vector2(x + 70, 82), "DOWN - FIRE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.3, 0.6 + 0.4 * sin(_t * 10)))
	draw_string(font, Vector2(x + 206, 82), "Hull", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CREAM)
	for i in 3:
		draw_rect(Rect2(x + 240 + i * 22, 72, 16, 11), Color(1, 0.55, 0.25) if i < mode.hull else Color(0.25, 0.12, 0.08))
	draw_string(font, Vector2(x + 12, 104), "In its cage: %d" % mode.machine.captives, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AMBER)
	if mode.sickness > 0.3:
		draw_string(font, Vector2(x + 130, 104), "Ailing", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.7, 1))
		_bar(Rect2(x + 180, 95, 120, 10), mode.sickness, Color(0.65, 0.45, 0.85))


func _panel(r: Rect2) -> void:
	draw_rect(r, Color(0.06, 0.02, 0.02, 0.72))
	draw_rect(r, Color(0.8, 0.38, 0.15, 0.55), false, 1.0)


func _bar(r: Rect2, f: float, c: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0, 1), r.size.y)), c)
	draw_rect(r, Color(1, 1, 1, 0.2), false, 1.0)


func _overlay(w: float, h: float, head: String, sub: String, c: Color) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
	draw_string(serif, Vector2(0, h * 0.42), head, HORIZONTAL_ALIGNMENT_CENTER, w, 46, c)
	var lines := sub.split("\n")
	for i in lines.size():
		draw_string(font, Vector2(0, h * 0.42 + 50 + i * 24), lines[i], HORIZONTAL_ALIGNMENT_CENTER, w, 17, CREAM)


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
