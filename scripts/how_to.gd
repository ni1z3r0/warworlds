class_name HowTo
extends Control
## "How to play" cards. Each mode shows its card the first time it is opened
## (the game pauses until you close it); the ? button and the menu's HOW TO
## PLAY page show them again. Every row gives the keyboard and the touch
## control side by side.

const SEEN_FILE := "user://tutorial.json"
const AMBER := Color(1.0, 0.72, 0.35)
const CREAM := Color(1.0, 0.92, 0.78)
const PAPER := Color(0.93, 0.87, 0.74)
const INK := Color(0.16, 0.1, 0.06)

const ORDER := ["book", "story", "rts", "house", "pilot", "soldier"]

const CARDS := {
	"book": {
		"title": "THE STORYBOOK",
		"goal": "The campaign follows the novel chapter by chapter. Each chapter opens with Henrique Alvim Corrêa's 1906 pictures and Wells' own words. Read the pages, then PLAY the chapter. Chapters without a PLAY button are read only.",
		"rows": [
			["Right arrow, Space, or click the page", "Tap the page", "turn the page"],
			["Up and down arrows, or click the list", "Tap a chapter in the list", "choose a chapter"],
			["Enter, or click PLAY", "Tap PLAY", "play this chapter"],
			["Esc or M", "MENU button", "back to the main menu"],
		],
		"tip": "The game remembers where you are. Chapters you have finished are ticked.",
	},
	"story": {
		"title": "THE STORY CHAPTERS",
		"goal": "You walk through the novel's scenes. Your goal is always written at the top left, and a gold marker shows where to go or who to talk to.",
		"rows": [
			["W A S D or the arrow keys", "Drag the MOVE stick, or tap the ground", "walk"],
			["Hold Shift", "Hold RUN", "run"],
			["E when close", "Tap the person or thing", "talk, look, use"],
			["E, Space or click", "Tap anywhere", "read on through words and pictures"],
			["R", "RESTART button", "start the chapter again"],
			["M or Esc", "MENU button", "back to the storybook"],
		],
		"tip": "Danger: when the Heat-Ray sweeps or the lightning flashes, get behind cover (sand hummocks, trees, ditches). If you die, you start again from the last safe place.",
	},
	"rts": {
		"title": "THE FIGHTING BEGINS",
		"goal": "Strategy. A fighting-machine is loose. Get the narrator and his wife down the road to Leatherhead (the exit on the map) before it finds them. The Artilleryman's gun can fight back.",
		"rows": [
			["Click a person, or drag a box", "Tap a person, or drag a box", "choose who to command"],
			["Right-click the ground", "Tap the ground", "move there"],
			["Right-click a cellar, or H", "Tap a cellar, or HIDE", "hide underground"],
			["D, then right-click the machine", "DEPLOY, then tap the machine", "set up the gun and fire"],
			["A, or 1 to 4", "ALL", "select everyone, or one person"],
			["Space", "PAUSE", "pause the game"],
		],
		"tip": "The machine sees in a cone from its hood. Its shield stops shells, but two quick hits overload it, and Earth's bacteria slowly sicken it. Keep clear of the black smoke.",
	},
	"house": {
		"title": "THE RUINED HOUSE",
		"goal": "Stealth. A cylinder has buried the house beside the Martians' pit. Survive fifteen days. Keep quiet, keep out of the green light, and keep the Curate calm.",
		"rows": [
			["W A S D", "MOVE stick", "creep, silently"],
			["Hold Shift", "Hold HURRY", "hurry (noisy!)"],
			["E", "USE", "take food, peep, hide in the coal"],
			["Hold E by the Curate", "Hold USE by the Curate", "calm him"],
			["F", "STRIKE (when it appears)", "stop the Curate if he breaks"],
			["Esc or F1", "PAUSE or ?", "pause, or show the guide"],
		],
		"tip": "Broken crockery crunches underfoot. When the light at the hole flickers, a Martian is about to look in: get into the dark. If the tentacle touches you in the coal, DON'T MOVE.",
	},
	"pilot": {
		"title": "THE FIGHTING-MACHINE",
		"goal": "First person. You are the Martian. Silence all five batteries of guns and fill your cage before Earth's air poisons you.",
		"rows": [
			["W A S D, Shift to stride", "MOVE stick, STRIDE", "walk the machine"],
			["Move the mouse", "Drag on the view", "look and aim"],
			["Hold the left mouse button", "Hold FIRE", "Heat-Ray (it runs out; let it recharge)"],
			["Right-click or E", "GRAB", "snatch a nearby human into the cage"],
			["F", "SMOKE", "fire a black-smoke canister"],
			["V", "VIEW", "cockpit or outside view"],
		],
		"tip": "Your shield stops shells until too many hit at once. Black smoke silences a battery without the Heat-Ray.",
	},
	"soldier": {
		"title": "THE ARTILLERY",
		"goal": "First person. You are a gunner. Find an abandoned field gun (the yellow GUN markers), take it, and bring the machine down before it sees you.",
		"rows": [
			["W A S D, Shift to run", "MOVE stick, RUN", "walk and run"],
			["Move the mouse", "Drag on the view", "look, and aim the gun"],
			["C or Ctrl", "CROUCH", "crouch (harder to see)"],
			["E at a gun", "GUN", "take or leave the gun"],
			["Click while on the gun", "FIRE", "fire (reloading takes 4 seconds)"],
			["Space", "JUMP", "jump"],
		],
		"tip": "The shield must overload before a shell can hurt the hull: hit it twice quickly, or fire when it flickers. If the eye on screen fills up, it has seen you: hide behind a building.",
	},
}

var pages: Array = []
var page := 0
var modal := true            # pauses the game; closes with GOT IT
var on_close: Callable
var _was_paused := false
var serif: Font
var font: Font
var _t := 0.0
var _btns := {}


## Show `mode`'s card the first time only (never during automated tests).
static func show_once(mode: String, parent: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest") or a.begins_with("--shots") or a == "--no-tutorial" or a.begins_with("--story="):
			return
	var seen := _load_seen()
	if seen.get(mode, false):
		return
	seen[mode] = true
	_save_seen(seen)
	show_card(mode, parent)


## Show a card now (the ? button).
static func show_card(mode: String, parent: Node) -> HowTo:
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var h := HowTo.new()
	h.pages = [mode]
	layer.add_child(h)
	h.on_close = func() -> void: layer.queue_free()
	return h


static func reset_seen() -> void:
	_save_seen({})


static func _load_seen() -> Dictionary:
	if not FileAccess.file_exists(SEEN_FILE):
		return {}
	var f := FileAccess.open(SEEN_FILE, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _save_seen(d: Dictionary) -> void:
	var f := FileAccess.open(SEEN_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["DejaVu Serif", "Georgia", "Times New Roman", "serif"])
	serif = sf
	if modal:
		_was_paused = get_tree().paused
		get_tree().paused = true


func _process(delta: float) -> void:
	_t += delta
	size = get_viewport_rect().size
	queue_redraw()


func close() -> void:
	if modal:
		get_tree().paused = _was_paused
	Sound.play("ui_click", -6.0, 0.0)
	if on_close.is_valid():
		on_close.call()
	queue_free()


func _turn(d: int) -> void:
	var np := clampi(page + d, 0, pages.size() - 1)
	if np != page:
		page = np
		Sound.play("page_turn", -8.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		var p: Vector2 = event.position
		for k in _btns.keys():
			if (_btns[k] as Rect2).has_point(p):
				match k:
					"close": close()
					"next": _turn(1)
					"prev": _turn(-1)
				return
		if modal and pages.size() == 1:
			close()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	match event.keycode:
		KEY_RIGHT, KEY_D:
			_turn(1)
		KEY_LEFT, KEY_A:
			_turn(-1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_E:
			if pages.size() > 1 and page < pages.size() - 1 and event.keycode != KEY_ESCAPE:
				_turn(1)
			else:
				close()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var c: Dictionary = CARDS[pages[page]]
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.7))
	var r := Rect2(w * 0.5 - 640, 70, 1280, h - 140)
	draw_rect(r, PAPER)
	draw_rect(r.grow(-8), Color(INK, 0.5), false, 1.5)
	var x := r.position.x + 50
	var y := r.position.y + 70
	draw_string(serif, Vector2(r.position.x, y), "HOW TO PLAY:  " + String(c.title), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, INK)
	y = _wrap(String(c.goal), Vector2(x, y + 50), r.size.x - 100, 19, INK, serif) + 44
	# the table: keyboard | touch | what it does
	var touch := Touch.is_touch()
	var cols := [x, x + 420, x + 830]
	var heads := ["KEYBOARD AND MOUSE", "TOUCH SCREEN", "WHAT IT DOES"]
	for k in 3:
		var hl := (k == 1 and touch) or (k == 0 and not touch)
		draw_string(font, Vector2(cols[k], y), heads[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.2, 0.05) if hl else Color(INK, 0.6))
	draw_line(Vector2(x, y + 10), Vector2(r.end.x - 50, y + 10), Color(INK, 0.4), 1.0)
	y += 44
	for row in c.rows:
		for k in 3:
			var hl := (k == 1 and touch) or (k == 0 and not touch)
			var col := INK if (hl or k == 2) else Color(INK, 0.55)
			_wrap(String(row[k]), Vector2(cols[k], y), 390.0 if k < 2 else 360.0, 17, col, font if k < 2 else serif)
		y += 50
	# the tip
	y += 6
	draw_rect(Rect2(x - 14, y - 26, r.size.x - 72, 82), Color(0.55, 0.2, 0.05, 0.12))
	_wrap(String(c.tip), Vector2(x, y), r.size.x - 110, 17, Color(0.35, 0.1, 0.02), serif)
	# buttons
	_btns.clear()
	var by := r.end.y - 70
	var last := page == pages.size() - 1
	if pages.size() > 1:
		draw_string(font, Vector2(r.position.x, by + 34), "%d / %d" % [page + 1, pages.size()], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(INK, 0.6))
		if page > 0:
			_button("prev", Rect2(x, by, 200, 50), "< PREVIOUS")
		if not last:
			_button("next", Rect2(r.end.x - 250, by, 200, 50), "NEXT >")
	if modal and (last or pages.size() == 1):
		_button("close", Rect2(r.end.x - 250, by, 200, 50), "GOT IT")
	elif not modal:
		_button("close", Rect2(r.position.x + r.size.x * 0.5 - 100, by - 60, 200, 46), "BACK")


func _button(id: String, rr: Rect2, label: String) -> void:
	_btns[id] = rr
	draw_rect(rr, Color(0.18, 0.07, 0.03))
	draw_rect(rr, AMBER, false, 2.0)
	draw_string(font, rr.position + Vector2(0, rr.size.y * 0.5 + 7), label, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 18, CREAM)


func _wrap(text: String, pos: Vector2, width: float, fsize: int, col: Color, f: Font) -> float:
	var y := pos.y
	var line := ""
	for wd in text.split(" "):
		var trial := wd if line == "" else line + " " + wd
		if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > width and line != "":
			draw_string(f, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
			y += fsize * 1.35
			line = wd
		else:
			line = trial
	if line != "":
		draw_string(f, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
	return y
