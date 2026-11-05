extends CanvasLayer
## The on-screen touch controls (see Touch for the API). Turns touches into
## the key presses and mouse input the game already understands.

const S := Touch.SYNTH_DEVICE
const AMBER := Color(1.0, 0.72, 0.35)
const CREAM := Color(1.0, 0.92, 0.78)
const STICK_R := 92.0
const STICK_HOME := Vector2(190, 750)

var active := false
var forced := false
var lay := {}
var _owner: Node = null
var _owner_pending := false
var _pad: Control
var _font: Font
var _touches := {}          # touch index -> {"kind": ..., ...}
var _keys := {}             # keycodes we are holding down
var _stick_c := STICK_HOME
var _stick_v := Vector2.ZERO
var _stick_on := false
var _last_touch_ms := -100000
var _t := 0.0


func _init() -> void:
	forced = "--touch" in OS.get_cmdline_user_args()
	active = forced


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pad)
	_pad.draw.connect(_draw_pad)


func set_layout(d: Dictionary) -> void:
	_release_all()
	lay = d
	_owner = null
	_owner_pending = true


func _process(delta: float) -> void:
	_t += delta
	var cur := get_tree().current_scene
	if _owner_pending and cur != null:
		_owner = cur
		_owner_pending = false
	elif not _owner_pending and not lay.is_empty() and (_owner == null or not is_instance_valid(_owner) or cur != _owner):
		_release_all()
		lay = {}
	_pad.size = get_viewport().get_visible_rect().size
	_pad.queue_redraw()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_last_touch_ms = Time.get_ticks_msec()
		active = true
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index, event.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		_last_touch_ms = Time.get_ticks_msec()
		_drag(event.index, event.position)
		get_viewport().set_input_as_handled()
		return
	if event.device == S:
		return
	var recent := Time.get_ticks_msec() - _last_touch_ms < 1000
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and recent:
		# browsers can follow a touch with "compatibility" mouse events: drop them
		get_viewport().set_input_as_handled()
		return
	if forced:
		return
	var real_key: bool = event is InputEventKey and event.pressed
	var real_mouse: bool = event is InputEventMouseMotion and event.relative.length() > 3.0
	if active and (real_key or real_mouse):
		active = false
		_release_all()


func _buttons() -> Array:
	var out := []
	if not active:
		return out
	for b in lay.get("buttons", []):
		var label := String(b.get("label", ""))
		if b.has("label_fn"):
			label = String((b.label_fn as Callable).call())
		if label != "":
			out.append([b, label])
	return out


func _stick_zone() -> Rect2:
	return Rect2(0, 360, 640, 640)


func _press(i: int, p: Vector2) -> void:
	for bl in _buttons():
		var b: Dictionary = bl[0]
		if p.distance_to(b.pos) <= float(b.get("r", 58.0)) + 12.0:
			_touches[i] = {"kind": "button", "b": b}
			_button(b, true)
			return
	if lay.get("stick", false) and _stick_zone().has_point(p) and not _stick_on:
		_touches[i] = {"kind": "stick"}
		_stick_on = true
		_stick_c = p
		_stick_v = Vector2.ZERO
		return
	if lay.get("look", false):
		_touches[i] = {"kind": "look", "last": p}
		return
	_touches[i] = {"kind": "pointer"}
	_mouse_move(p, MOUSE_BUTTON_MASK_LEFT, Vector2.ZERO)
	_mouse_button(p, MOUSE_BUTTON_LEFT, true)


func _drag(i: int, p: Vector2) -> void:
	if not _touches.has(i):
		return
	var t: Dictionary = _touches[i]
	match t.kind:
		"stick":
			_stick_v = ((p - _stick_c) / STICK_R).limit_length(1.0)
			_apply_stick()
		"look":
			var rel: Vector2 = (p - (t.last as Vector2)) * float(lay.get("look_speed", 1.4))
			t.last = p
			_mouse_move(get_viewport().get_visible_rect().size * 0.5, 0, rel)
		"pointer":
			_mouse_move(p, MOUSE_BUTTON_MASK_LEFT, Vector2.ZERO)


func _release(i: int, p: Vector2) -> void:
	if not _touches.has(i):
		return
	var t: Dictionary = _touches[i]
	_touches.erase(i)
	match t.kind:
		"button":
			_button(t.b, false)
		"stick":
			_stick_on = false
			_stick_v = Vector2.ZERO
			_stick_c = STICK_HOME
			_apply_stick()
		"pointer":
			_mouse_move(p, 0, Vector2.ZERO)
			_mouse_button(p, MOUSE_BUTTON_LEFT, false)


func _button(b: Dictionary, down: bool) -> void:
	b["_down"] = down
	if b.has("key"):
		_key(int(b.key), down)
	elif b.has("mouse"):
		_mouse_button(get_viewport().get_visible_rect().size * 0.5, int(b.mouse), down)
	elif b.has("call") and down:
		(b.call as Callable).call()


func _apply_stick() -> void:
	var v := _stick_v
	_key(KEY_A, v.x < -0.4)
	_key(KEY_D, v.x > 0.4)
	_key(KEY_W, v.y < -0.4)
	_key(KEY_S, v.y > 0.4)


func _release_all() -> void:
	for k in _keys.keys():
		_key(k, false)
	for i in _touches.keys():
		var t: Dictionary = _touches[i]
		if t.kind == "button":
			(t.b as Dictionary)["_down"] = false
		elif t.kind == "pointer":
			_mouse_button(Vector2.ZERO, MOUSE_BUTTON_LEFT, false)
	_touches.clear()
	_stick_on = false
	_stick_v = Vector2.ZERO
	_stick_c = STICK_HOME


# ---------------------------------------------------------------- synthesised input

func _key(k: int, down: bool) -> void:
	if down == _keys.has(k):
		return
	if down:
		_keys[k] = true
	else:
		_keys.erase(k)
	var e := InputEventKey.new()
	e.device = S
	e.keycode = k as Key
	e.physical_keycode = k as Key
	e.pressed = down
	Input.parse_input_event(e)


## Our positions are in the game's 1600x1000 space; input events want window pixels.
func _win(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func _mouse_move(p: Vector2, mask: int, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.device = S
	e.position = _win(p)
	e.global_position = e.position
	e.button_mask = mask
	e.relative = rel
	e.screen_relative = rel
	Input.parse_input_event(e)


func _mouse_button(p: Vector2, b: int, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.device = S
	e.position = _win(p)
	e.global_position = e.position
	e.button_index = b as MouseButton
	e.pressed = down
	e.button_mask = (1 << (b - 1)) if down else 0
	Input.parse_input_event(e)


# ---------------------------------------------------------------- drawing

func _draw_pad() -> void:
	if not active or lay.is_empty():
		return
	if lay.get("stick", false):
		var c := _stick_c
		_pad.draw_circle(c, STICK_R, Color(0, 0, 0, 0.28 if _stick_on else 0.18))
		_pad.draw_arc(c, STICK_R, 0, TAU, 48, Color(AMBER, 0.55 if _stick_on else 0.3), 3.0)
		_pad.draw_circle(c + _stick_v * STICK_R, 38, Color(AMBER, 0.55 if _stick_on else 0.25))
		if not _stick_on:
			_pad.draw_string(_font, c + Vector2(-60, -STICK_R - 12), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(CREAM, 0.45))
	for bl in _buttons():
		var b: Dictionary = bl[0]
		var label: String = bl[1]
		var r := float(b.get("r", 58.0))
		var down: bool = b.get("_down", false)
		var p: Vector2 = b.pos
		_pad.draw_circle(p, r, Color(0.06, 0.02, 0.02, 0.75 if down else 0.55))
		_pad.draw_arc(p, r, 0, TAU, 40, Color(AMBER, 1.0 if down else 0.7), 3.0 if down else 2.0)
		var fs := 15 if r >= 50.0 else 13
		var lines := label.split("\n")
		var y0 := p.y + fs * 0.35 - (lines.size() - 1) * fs * 0.6
		for k in lines.size():
			_pad.draw_string(_font, Vector2(p.x - r, y0 + k * fs * 1.2), lines[k], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, CREAM)
