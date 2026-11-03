extends Control
## HUD for story chapters: title and goal, interaction prompts, the dialogue
## box (with portraits), narration, Corrêa plate cutscenes, the telescope
## eyepiece, and the end-of-chapter and death cards.

var scene: Node
var font: Font
var serif: Font
var _t := 0.0
var _plates := {}
const CREAM := Color(1.0, 0.92, 0.8)
const AMBER := Color(1.0, 0.75, 0.45)
const INK := Color(0.12, 0.08, 0.05)
const PAPER := Color(0.93, 0.88, 0.76)


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


func _draw() -> void:
	var w := size.x
	var h := size.y
	var s = scene
	var d: Dictionary = s.data

	# chapter title, place, goal
	draw_rect(Rect2(12, 12, 560, 78), Color(0.06, 0.03, 0.02, 0.8))
	draw_rect(Rect2(12, 12, 560, 78), Color(0.8, 0.38, 0.15, 0.55), false, 1.0)
	draw_string(serif, Vector2(24, 38), d.get("title", ""), HORIZONTAL_ALIGNMENT_LEFT, 540, 19, AMBER)
	draw_string(font, Vector2(24, 58), d.get("place", ""), HORIZONTAL_ALIGNMENT_LEFT, 540, 12, Color(CREAM, 0.6))
	var g: String = s.goal()
	if g != "" and s.busy.is_empty() and s.queue.is_empty():
		draw_string(font, Vector2(24, 80), "> " + g, HORIZONTAL_ALIGNMENT_LEFT, 540, 14, Color(0.7, 1.0, 0.7))

	# prompt by the player
	if s.busy.is_empty() and s.queue.is_empty() and not s.done and not s.dead:
		var it: Dictionary = s.nearest_interactable()
		if not it.is_empty():
			var p: Vector2 = s.player.get_global_transform_with_canvas().origin + Vector2(0, 30)
			var txt: String = "E  " + it.prompt
			draw_string_outline(font, p - Vector2(160, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 320, 15, 4, Color(0, 0, 0, 0.85))
			draw_string(font, p - Vector2(160, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 320, 15, AMBER)
	draw_string(font, Vector2(w - 330, h - 12), "WASD move   E talk / use / continue   M storybook", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(CREAM, 0.4))

	if s.ray.get("on", false) and not s.dead and not s.done:
		var msg := "The heat-ray is sweeping the common! Hide behind the sand hummocks."
		draw_string_outline(serif, Vector2(0, 130), msg, HORIZONTAL_ALIGNMENT_CENTER, w, 20, 6, Color(0, 0, 0, 0.8))
		draw_string(serif, Vector2(0, 130), msg, HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(1, 0.6, 0.35, 0.7 + 0.3 * sin(_t * 10)))

	if not s.busy.is_empty():
		match s.busy.kind:
			"say":
				_dialogue(w, h, s.busy.who, s.busy.text)
			"narr":
				_narration(w, h, s.busy.text)
			"plate":
				_plate_card(w, h, s.busy.file, s.busy.text)
			"scope":
				_scope(w, h)
	if s.done:
		_card(w, h, "CHAPTER COMPLETE", d.get("title", ""), "E  continue the story")
	elif s.dead:
		_card(w, h, "KILLED", s.dead_why, "E  try again from the last safe place")


func _wrap(text: String, pos: Vector2, width: float, fsize: int, col: Color, f: Font) -> float:
	var y := pos.y
	var line := ""
	for wd in text.split(" "):
		var trial := wd if line == "" else line + " " + wd
		if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > width and line != "":
			draw_string(f, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
			y += fsize * 1.4
			line = wd
		else:
			line = trial
	if line != "":
		draw_string(f, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
	return y


func _dialogue(w: float, h: float, who: String, text: String) -> void:
	var r := Rect2(w * 0.5 - 520, h - 200, 1040, 170)
	draw_rect(r, Color(0.05, 0.03, 0.02, 0.92))
	draw_rect(r, Color(0.8, 0.38, 0.15, 0.7), false, 1.5)
	var tx := r.position.x + 24
	var pid: String = scene.portrait_for(who)
	if pid != "":
		draw_texture_rect(Cast.portrait(pid), Rect2(r.position + Vector2(14, 14), Vector2(106, 142)), false)
		tx = r.position.x + 136
	draw_string(serif, Vector2(tx, r.position.y + 34), scene.speaker_name(who), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, AMBER)
	_wrap("\"" + text + "\"", Vector2(tx, r.position.y + 70), r.end.x - tx - 24, 19, CREAM, serif)
	draw_string(font, Vector2(r.end.x - 120, r.end.y - 12), "E  continue", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CREAM, 0.5 + 0.3 * sin(_t * 4)))


func _narration(w: float, h: float, text: String) -> void:
	var r := Rect2(w * 0.5 - 520, h - 200, 1040, 170)
	draw_rect(r, Color(PAPER, 0.95))
	draw_rect(r.grow(-6), Color(INK, 0.6), false, 1.0)
	_wrap(text, Vector2(r.position.x + 30, r.position.y + 44), r.size.x - 60, 19, INK, serif)
	draw_string(font, Vector2(r.end.x - 120, r.end.y - 12), "E  continue", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK, 0.5 + 0.3 * sin(_t * 4)))


func _plate_card(w: float, h: float, file: String, text: String) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.02, 0.01, 0.94))
	var tex := _plate(file)
	var box := Rect2(w * 0.5 - 420, 30, 840, h - 230)
	var ts := tex.get_size()
	var k := minf(box.size.x / ts.x, box.size.y / ts.y)
	var ps := ts * k
	draw_texture_rect(tex, Rect2(box.position + (box.size - ps) * 0.5, ps), false)
	var y := _wrap(text, Vector2(w * 0.5 - 420, h - 160), 840, 19, CREAM, serif)
	draw_string(font, Vector2(0, h - 30), "E  continue", HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(CREAM, 0.5 + 0.3 * sin(_t * 4)))


## "Looking through the telescope, one saw a circle of deep blue and the
## little round planet swimming in the field."
func _scope(w: float, h: float) -> void:
	var s = scene
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0))
	var c := Vector2(w * 0.5, h * 0.45)
	var r := 300.0
	draw_circle(c, r, Color(0.05, 0.08, 0.28))
	for k in 60:
		var p := c + Vector2(fmod(k * 97.3, 560.0) - 280.0, fmod(k * 53.1, 560.0) - 280.0)
		if p.distance_to(c) < r - 4:
			draw_circle(p, 1.0, Color(1, 1, 1, 0.5))
	var drift := Vector2(sin(_t * 0.3) * 12.0, cos(_t * 0.23) * 8.0)
	var m := c + drift
	draw_set_transform(m, 0, Vector2(1.0, 0.94))
	draw_circle(Vector2.ZERO, 46, Color(0.85, 0.42, 0.22))
	for k in 4:
		draw_line(Vector2(-42, -24 + k * 16), Vector2(42, -24 + k * 16), Color(0.7, 0.32, 0.17, 0.6), 4.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if s.scope_t >= s.scope_flash:
		var k := clampf((s.scope_t - s.scope_flash) / 1.2, 0.0, 1.0)
		draw_circle(m + Vector2(44, -10), 6.0 + 10.0 * (1.0 - k), Color(1.0, 0.45, 0.3, 1.0 - k * 0.5))
	draw_arc(c, r, 0, TAU, 96, Color(0.25, 0.25, 0.3), 6.0)
	draw_string(serif, Vector2(0, h - 170), "Watch the edge of the planet. Press E the moment you see something.", HORIZONTAL_ALIGNMENT_CENTER, w, 19, CREAM)
	if s.scope_note != "":
		draw_string(font, Vector2(0, h - 135), s.scope_note, HORIZONTAL_ALIGNMENT_CENTER, w, 15, AMBER)
	var tick := "tick" if int(_t * 2.0) % 2 == 0 else "tock"
	draw_string(font, Vector2(0, h - 100), "(the steady ticking of the clockwork: %s)" % tick, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(CREAM, 0.4))


func _card(w: float, h: float, head: String, sub: String, hint: String) -> void:
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.6))
	draw_string(serif, Vector2(0, h * 0.4), head, HORIZONTAL_ALIGNMENT_CENTER, w, 44, AMBER)
	draw_string(serif, Vector2(0, h * 0.4 + 56), sub, HORIZONTAL_ALIGNMENT_CENTER, w, 18, CREAM)
	draw_string(font, Vector2(0, h * 0.4 + 140), hint, HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(CREAM, 0.6 + 0.3 * sin(_t * 4)))
