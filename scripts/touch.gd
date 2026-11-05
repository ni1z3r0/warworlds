class_name Touch
extends RefCounted
## Touch-screen controls for tablets and phones (static, no autoload).
##
## A scene describes the on-screen controls it wants:
##
##   Touch.layout({
##       "stick": true,                 # a movement stick, bottom-left (drives WASD)
##       "look": true,                  # drag anywhere else to look (mouse motion)
##       "buttons": [
##           {"label": "USE", "key": KEY_E, "pos": Vector2(1450, 820)},
##           {"label": "FIRE", "mouse": MOUSE_BUTTON_LEFT, "hold": true, ...},
##           {"label_fn": func(): return "STRIKE" if can_strike else "", "key": KEY_F, ...},
##       ],
##   })
##
## Touches that miss every control become ordinary mouse clicks and drags,
## so menus, the storybook and the strategy map work by tapping. All input is
## fed through Input.parse_input_event, so the game sees exactly the keys and
## mouse buttons it already understands.
##
## The controls show only on a touch screen, after the first touch (or with
## --touch on the command line), and hide again when a real keyboard or mouse
## is used.

const SYNTH_DEVICE := 7071   # marks events we generate ourselves

static var _host: Node


static func _ensure() -> Node:
	if _host != null and is_instance_valid(_host):
		return _host
	_host = (load("res://scripts/touch_layer.gd") as GDScript).new()
	_host.name = "TouchLayer"
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child.call_deferred(_host)
	return _host


## Set the controls for the current scene. They are cleared automatically
## when the scene changes.
static func layout(d: Dictionary) -> void:
	_ensure().call("set_layout", d)


## True while the touch controls are in use: show touch hints, not keys.
static func is_touch() -> bool:
	if _host == null or not is_instance_valid(_host):
		return "--touch" in OS.get_cmdline_user_args()
	return bool(_host.get("active"))


## "E" on a keyboard, "tap" on a touch screen, and so on.
static func hint(keys: String, touch: String) -> String:
	return touch if is_touch() else keys


## Make sure the layer exists (it watches for the first touch).
static func init() -> void:
	_ensure()


## The CONTINUE / RESTART buttons every mode shows when it ends, plus the
## MENU and ? buttons in the top right corner.
## `corner` is where the MENU button goes; ? sits to its left, and a mode's
## own PAUSE button goes at pause_pos(corner).
static func common_buttons(is_ended: Callable, can_continue: Callable, help_mode: String, parent: Node, corner := Vector2(1550, 50), menu_key := KEY_M) -> Array:
	return [
		{"label_fn": func() -> String: return "CONTINUE" if is_ended.call() and can_continue.call() else "", "key": KEY_ENTER, "pos": Vector2(800, 820), "r": 66.0},
		{"label_fn": func() -> String: return "RESTART" if is_ended.call() else "", "key": KEY_R, "pos": Vector2(600, 840), "r": 50.0},
		{"label": "MENU", "key": menu_key, "pos": corner, "r": 38.0},
		{"label": "?", "call": func() -> void: HowTo.show_card(help_mode, parent), "pos": corner - Vector2(88, 0), "r": 38.0},
	]


static func pause_pos(corner := Vector2(1550, 50)) -> Vector2:
	return corner - Vector2(176, 0)


## Rewrite a keyboard prompt such as "E  take a ration" for touch screens.
static func prompt(text: String, keys: Dictionary) -> String:
	if not is_touch():
		return text
	for k in keys.keys():
		if text.begins_with(k):
			return String(keys[k]) + text.substr(String(k).length())
	return text
