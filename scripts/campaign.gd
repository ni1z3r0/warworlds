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
var _cast_rects: Array = []

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
	chapter = clampi(CampaignState.get_current(), 0, Story.CHAPTERS.size() - 1)
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


func _cast_index() -> int:
	return Story.CHAPTERS.size()


func _plates() -> Array:
	if chapter == _cast_index():
		return Cast.ORDER
	return Story.CHAPTERS[chapter].plates


func _draw_cast_page(w: float, h: float) -> void:
	var id: String = Cast.ORDER[plate]
	var p: Dictionary = Cast.PEOPLE[id]
	var tex := Cast.portrait(id)
	var box := Rect2(580, 40, 640, h - 80)
	var ts := tex.get_size()
	var k := minf(box.size.x / ts.x, box.size.y / ts.y)
	var ps := ts * k
	var pr := Rect2(box.position + (box.size - ps) * 0.5, ps)
	draw_rect(pr.grow(10), Color(0, 0, 0, 0.5))
	draw_texture_rect(tex, pr, false, Color(1, 1, 1, _fade))
	var tx := 1250.0
	draw_string(font, Vector2(tx, 70), "THE CAST", HORIZONTAL_ALIGNMENT_LEFT, 320, 11, Color(AMBER, 0.6))
	draw_string(serif, Vector2(tx, 106), p.name, HORIZONTAL_ALIGNMENT_LEFT, 320, 26, AMBER)
	var y := _wrap(p.role, Vector2(tx, 146), 320.0, 15, Color(CREAM, 0.8))
	y = _wrap("\"" + p.desc + "\"", Vector2(tx, y + 24), 320.0, 17, Color(CREAM, _fade))
	if p.line != "":
		draw_string(font, Vector2(tx, y + 26), "SAYS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(AMBER, 0.6))
		y = _wrap("\"" + p.line + "\"", Vector2(tx, y + 50), 320.0, 17, Color(0.85, 1.0, 0.85, _fade))
	draw_string(font, Vector2(tx, y + 30), "APPEARS IN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(AMBER, 0.6))
	_wrap(p.chapters, Vector2(tx, y + 52), 320.0, 14, Color(CREAM, 0.75))
	draw_string(font, Vector2(tx, h - 210), "%d of %d" % [plate + 1, Cast.ORDER.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	_prev_rect = Rect2(tx, h - 196, 150, 40)
	_next_rect = Rect2(tx + 170, h - 196, 150, 40)
	_button(_prev_rect, "<  previous", plate > 0)
	_button(_next_rect, "next  >", plate < Cast.ORDER.size() - 1)
	_play_rect = Rect2()
	draw_string(font, Vector2(tx, h - 120), "Words in quotes are Wells' own.", HORIZONTAL_ALIGNMENT_LEFT, 330, 12, Color(DIM, 0.7))
	draw_string(font, Vector2(tx, h - 100), "Portraits: AI-generated ink illustrations.", HORIZONTAL_ALIGNMENT_LEFT, 330, 12, Color(DIM, 0.7))


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
	var y := 112.0
	var book := ""
	for i in Story.CHAPTERS.size():
		var c: Dictionary = Story.CHAPTERS[i]
		if c.book != book:
			book = c.book
			y += 6.0
			draw_string(font, Vector2(40, y + 8), book, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(AMBER, 0.6))
			y += 14.0
		var r := Rect2(30, y, 510, 36)
		_list_rects.append(r)
		var on := i == chapter
		if on:
			draw_rect(r, Color(0.25, 0.1, 0.05, 0.8))
			draw_rect(r, Color(AMBER, 0.8), false, 1.5)
		var playable := _playable(i)
		var done := CampaignState.is_done(i)
		draw_string(serif, r.position + Vector2(14, 17), c.title, HORIZONTAL_ALIGNMENT_LEFT, 440, 15, CREAM if on else Color(CREAM, 0.8))
		var tag: String = c.get("mode", "Read") if playable else ("Read" if c.cast.is_empty() else "Read  (coming soon to play)")
		draw_string(font, r.position + Vector2(14, 31), tag, HORIZONTAL_ALIGNMENT_LEFT, 440, 11, Color(0.6, 1.0, 0.6, 0.85) if playable else Color(DIM, 0.6))
		if done:
			draw_string(font, r.position + Vector2(470, 22), "done", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 1.0, 0.6, 0.7))
		elif i == CampaignState.get_current():
			draw_string(font, r.position + Vector2(425, 22), "you are here", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(AMBER, 0.9))
		y += 38.0
	y += 6.0
	var cr := Rect2(30, y, 510, 36)
	_list_rects.append(cr)
	var con := chapter == _cast_index()
	if con:
		draw_rect(cr, Color(0.25, 0.1, 0.05, 0.8))
		draw_rect(cr, Color(AMBER, 0.8), false, 1.5)
	draw_string(serif, cr.position + Vector2(14, 17), "THE CAST", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREAM if con else Color(CREAM, 0.8))
	draw_string(font, cr.position + Vector2(14, 31), "Wells' characters, in his own words", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(AMBER, 0.7))
	if con:
		_draw_cast_page(w, h)
		return

	# the plate, mounted like a page
	var plates := _plates()
	var entry: Array = plates[plate]
	var box := Rect2(580, 40, 640, h - 80)
	if entry[0] == "":
		# a title page, for chapters Corrêa did not illustrate
		var pr0 := Rect2(box.position + Vector2(40, 60), box.size - Vector2(80, 120))
		draw_rect(pr0.grow(10), Color(0, 0, 0, 0.5))
		draw_rect(pr0, Color(0.9, 0.85, 0.72, _fade))
		draw_rect(pr0.grow(-14), Color(0.25, 0.18, 0.12, 0.6 * _fade), false, 1.5)
		var t: String = Story.CHAPTERS[chapter].title
		draw_string(serif, Vector2(pr0.position.x, pr0.position.y + pr0.size.y * 0.42), t, HORIZONTAL_ALIGNMENT_CENTER, pr0.size.x, 30, Color(0.2, 0.13, 0.08, _fade))
		draw_line(pr0.position + Vector2(pr0.size.x * 0.3, pr0.size.y * 0.5), pr0.position + Vector2(pr0.size.x * 0.7, pr0.size.y * 0.5), Color(0.2, 0.13, 0.08, 0.6 * _fade), 1.5)
	else:
		var tex := _texture(entry[0])
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
	var people: Array = c.get("cast", [])
	if not people.is_empty():
		draw_string(font, Vector2(tx, h - 310), "IN THIS CHAPTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(AMBER, 0.6))
		_cast_rects.clear()
		for i in people.size():
			var r := Rect2(tx + (i % 7) * 46, h - 300 + floorf(i / 7.0) * 62, 42, 56)
			draw_texture_rect(Cast.portrait(people[i]), r, false)
			draw_rect(r, Color(AMBER, 0.5), false, 1.0)
			_cast_rects.append([r, people[i]])
	draw_string(font, Vector2(tx, h - 210), "Plate %d of %d" % [plate + 1, plates.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	_prev_rect = Rect2(tx, h - 196, 150, 40)
	_next_rect = Rect2(tx + 170, h - 196, 150, 40)
	_button(_prev_rect, "<  previous", plate > 0)
	_button(_next_rect, "next  >", plate < plates.size() - 1 or chapter < _cast_index())
	_play_rect = Rect2(tx, h - 140, 320, 56)
	if _playable(chapter):
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


func _wrap(text: String, pos: Vector2, width: float, fsize: int, col: Color) -> float:
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
	return y


func _go(ch: int, pl: int) -> void:
	ch = clampi(ch, 0, _cast_index())
	var n: int = Cast.ORDER.size() if ch == _cast_index() else Story.CHAPTERS[ch].plates.size()
	pl = clampi(pl, 0, n - 1)
	if ch != chapter or pl != plate:
		_fade = 0.0
	chapter = ch
	plate = pl


func _next() -> void:
	if plate < _plates().size() - 1:
		_go(chapter, plate + 1)
	elif chapter < _cast_index():
		_go(chapter + 1, 0)


func _prev() -> void:
	if plate > 0:
		_go(chapter, plate - 1)
	elif chapter > 0:
		_go(chapter - 1, 999)


func _playable(i: int) -> bool:
	var c: Dictionary = Story.CHAPTERS[i]
	return c.has("story") or c.get("scene", "") != ""


func _play() -> void:
	if chapter == _cast_index() or not _playable(chapter):
		return
	CampaignState.play(chapter)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		for i in _list_rects.size():
			if _list_rects[i].has_point(p):
				_go(i, 0)
				return
		for cr in _cast_rects:
			if chapter != _cast_index() and (cr[0] as Rect2).has_point(p):
				_go(_cast_index(), Cast.ORDER.find(cr[1]))
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
