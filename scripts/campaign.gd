extends Control
## The story: the campaign told through Alvim Corrêa's 1906 plates.
## Left: the chapters. Right: flip through the chapter's plates with Wells'
## words, then play the chapter if it is built.

var chapter := 0
var plate := 0
var font: Font
var serif: Font
var _tex := {}
var _t := 0.0
var _fade := 1.0
var _list_rects: Array[Rect2] = []
var _prev_rect := Rect2()
var _next_rect := Rect2()
var _play_rect := Rect2()

const INK := Color(0.07, 0.05, 0.04)
const PAPER := Color(0.93, 0.88, 0.76)
const CREAM := Color(1.0, 0.92, 0.8)
const AMBER := Color(1.0, 0.75, 0.45)
const DIM := Color(0.75, 0.68, 0.58)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["DejaVu Serif", "Georgia", "Times New Roman", "serif"])
	serif = sf
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chapter="):
			chapter = int(a.substr(10))
		elif a.begins_with("--plate="):
			plate = int(a.substr(8))


func _process(delta: float) -> void:
	_t += delta
	_fade = minf(1.0, _fade + delta * 3.0)
	size = get_viewport_rect().size
	queue_redraw()


func _plates() -> Array:
	return Story.CHAPTERS[chapter].plates


func _texture(file: String) -> Texture2D:
	if not _tex.has(file):
		_tex[file] = load("res://art/correa/" + file)
	return _tex[file]


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), INK)

	# chapter list
	draw_string(serif, Vector2(40, 58), "THE WAR OF THE WORLDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, AMBER)
	draw_string(font, Vector2(40, 84), "Illustrated by Henrique Alvim Corrêa, 1906", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	_list_rects.clear()
	var y := 128.0
	var book := ""
	for i in Story.CHAPTERS.size():
		var c: Dictionary = Story.CHAPTERS[i]
		if c.book != book:
			book = c.book
			y += 10.0
			draw_string(font, Vector2(40, y), book, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(AMBER, 0.6))
			y += 14.0
		var r := Rect2(30, y, 500, 50)
		_list_rects.append(r)
		var on := i == chapter
		if on:
			draw_rect(r, Color(0.25, 0.1, 0.05, 0.8))
			draw_rect(r, Color(AMBER, 0.8), false, 1.5)
		var playable: bool = c.scene != ""
		draw_string(serif, r.position + Vector2(14, 24), c.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CREAM if on else Color(CREAM, 0.8))
		var tag: String = c.get("mode", "") if playable else "coming soon"
		draw_string(font, r.position + Vector2(14, 42), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 1.0, 0.6, 0.85) if playable else Color(DIM, 0.6))
		y += 56.0

	# the plate, mounted like a page
	var plates := _plates()
	var entry: Array = plates[plate]
	var tex := _texture(entry[0])
	var box := Rect2(580, 40, 640, h - 80)
	var ts := tex.get_size()
	var k := minf(box.size.x / ts.x, box.size.y / ts.y)
	var ps := ts * k
	var pr := Rect2(box.position + (box.size - ps) * 0.5, ps)
	draw_rect(pr.grow(10), Color(0, 0, 0, 0.5))
	draw_texture_rect(tex, pr, false, Color(1, 1, 1, _fade))

	# narration
	var tx := 1250.0
	var c: Dictionary = Story.CHAPTERS[chapter]
	draw_string(font, Vector2(tx, 70), c.book, HORIZONTAL_ALIGNMENT_LEFT, 320, 11, Color(AMBER, 0.6))
	draw_string(serif, Vector2(tx, 104), c.title, HORIZONTAL_ALIGNMENT_LEFT, 320, 22, AMBER)
	_wrap(entry[1], Vector2(tx, 150), 320.0, 18, Color(CREAM, _fade))
	draw_string(font, Vector2(tx, h - 210), "Plate %d of %d" % [plate + 1, plates.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	_prev_rect = Rect2(tx, h - 196, 150, 40)
	_next_rect = Rect2(tx + 170, h - 196, 150, 40)
	_button(_prev_rect, "<  previous", plate > 0)
	_button(_next_rect, "next  >", plate < plates.size() - 1 or chapter < Story.CHAPTERS.size() - 1)
	_play_rect = Rect2(tx, h - 140, 320, 56)
	if c.scene != "":
		var pulse := 0.75 + 0.25 * sin(_t * 3.0)
		draw_rect(_play_rect, Color(0.15, 0.3, 0.12, 0.9))
		draw_rect(_play_rect, Color(0.6, 1.0, 0.6, pulse), false, 2.0)
		draw_string(serif, _play_rect.position + Vector2(0, 36), "PLAY THIS CHAPTER", HORIZONTAL_ALIGNMENT_CENTER, 320, 20, Color(0.8, 1.0, 0.8))
	else:
		draw_rect(_play_rect, Color(0.12, 0.08, 0.06, 0.8))
		draw_string(font, _play_rect.position + Vector2(0, 34), "Not playable yet", HORIZONTAL_ALIGNMENT_CENTER, 320, 15, Color(DIM, 0.7))
	draw_string(font, Vector2(tx, h - 40), "Arrows / click to read.  Enter to play.  Esc menu", HORIZONTAL_ALIGNMENT_LEFT, 330, 11, Color(DIM, 0.6))


func _button(r: Rect2, label: String, enabled: bool) -> void:
	draw_rect(r, Color(0.2, 0.1, 0.06, 0.8 if enabled else 0.3))
	draw_rect(r, Color(AMBER, 0.6 if enabled else 0.15), false, 1.0)
	draw_string(font, r.position + Vector2(0, 26), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(CREAM, 1.0 if enabled else 0.3))


func _wrap(text: String, pos: Vector2, width: float, fsize: int, col: Color) -> void:
	var words := text.split(" ")
	var line := ""
	var y := pos.y
	for wd in words:
		var trial := wd if line == "" else line + " " + wd
		if serif.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > width and line != "":
			draw_string(serif, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
			y += fsize * 1.45
			line = wd
		else:
			line = trial
	if line != "":
		draw_string(serif, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _go(ch: int, pl: int) -> void:
	ch = clampi(ch, 0, Story.CHAPTERS.size() - 1)
	pl = clampi(pl, 0, Story.CHAPTERS[ch].plates.size() - 1)
	if ch != chapter or pl != plate:
		_fade = 0.0
	chapter = ch
	plate = pl


func _next() -> void:
	if plate < _plates().size() - 1:
		_go(chapter, plate + 1)
	elif chapter < Story.CHAPTERS.size() - 1:
		_go(chapter + 1, 0)


func _prev() -> void:
	if plate > 0:
		_go(chapter, plate - 1)
	elif chapter > 0:
		_go(chapter - 1, Story.CHAPTERS[chapter - 1].plates.size() - 1)


func _play() -> void:
	var s: String = Story.CHAPTERS[chapter].scene
	if s != "":
		get_tree().change_scene_to_file(s)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		for i in _list_rects.size():
			if _list_rects[i].has_point(p):
				_go(i, 0)
				return
		if _prev_rect.has_point(p):
			_prev()
		elif _next_rect.has_point(p):
			_next()
		elif _play_rect.has_point(p):
			_play()
		elif p.x > 560 and p.x < 1240:
			_next()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_RIGHT, KEY_SPACE:
				_next()
			KEY_LEFT:
				_prev()
			KEY_DOWN:
				_go(chapter + 1, 0)
			KEY_UP:
				_go(chapter - 1, 0)
			KEY_ENTER, KEY_KP_ENTER:
				_play()
			KEY_ESCAPE, KEY_M:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")


# docs screenshots: --shots=/abs/dir [--chapter=N --plate=N]
var _frames := 0


func _physics_process(_d: float) -> void:
	_frames += 1
	if _frames == 40:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shots="):
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/story_%d_%d.png" % [a.substr(8), chapter, plate])
				get_tree().quit()
