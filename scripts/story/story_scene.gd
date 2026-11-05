extends Node2D
## The story engine: plays a chapter written as data
## (scripts/story/chapters/<id>.gd, `static func data() -> Dictionary`).
##
## A chapter is a list of steps. Each step has a goal shown to the player, a
## condition ("when") and actions ("do") run in order once it is met.
##   when: {"talk": npc_id} | {"use": prop_id} | {"reach": area} | {"auto": true} | {"after": secs}
##   do:   ["say", who, line or [segments]]  spoken (Wells' words; checked)
##         ["narr", text]                     narration (Wells' words in \"quotes\")
##         ["plate", file, caption]           a Corrêa plate, full screen
##         ["scope"]                          look through Ogilvy's telescope
##         ["wait", secs]  ["move", who, pos, speed]  ["show", who, bool]
##         ["burn", who]  ["fire", pos, size]  ["puffs", pos]  ["panic"]
##         ["martian", pos]  ["open_cylinder"]  ["ray", {...}]  ["checkpoint"]  ["end"]

const NPC_SPEED := 55.0

var id := ""
var data: Dictionary
var world: StoryWorld
var player: HousePerson
var npcs := {}                 # id -> HousePerson
var npc_goal := {}             # id -> [pos, speed]
var crowd: Array[HousePerson] = []
var crowd_goal := {}           # person -> pos (when panicking)
var hud: Control

var step_i := 0
var step_t := 0.0
var queue: Array = []
var busy: Dictionary = {}      # the blocking action on screen
var interacted := ""           # last thing the player pressed E on
var done := false
var dead := false
var dead_why := ""
var checkpoint := {"pos": Vector2.ZERO, "step": 0}
var ray: Dictionary = {}       # the heat-ray sweeping the common
var scope_t := 0.0
var scope_flash := 0.0
var scope_seen := false
var scope_note := ""
var time := 0.0
var canvas_mod: CanvasModulate
var base_light := Color(1, 1, 1)
var next_flash := 4.0
var pre_flash := 0.0

var autotest := false
var transcript: Array[String] = []
var _shot_dir := ""
var _shot_times: Array = []


## Background sound for each chapter: [loop name, volume dB]. A chapter's
## data can override this with an "ambience" list of its own.
const AMBIENCE := {
	"b1_01": [["night_loop", -6.0]],
	"b1_02": [["wind_loop", -14.0], ["night_loop", -16.0]],
	"b1_03": [["crowd_loop", -8.0], ["wind_loop", -18.0]],
	"b1_04": [["crowd_loop", -6.0], ["wind_loop", -18.0]],
	"b1_05": [["wind_loop", -12.0], ["fire_loop", -20.0]],
	"b1_07": [["night_loop", -10.0], ["fire_loop", -16.0]],
	"b1_10": [["rain_loop", -4.0], ["wind_loop", -8.0]],
	"b1_11": [["fire_loop", -20.0], ["night_loop", -16.0]],
	"b1_13": [["wind_loop", -16.0], ["fire_loop", -22.0]],
	"b1_14": [["panic_loop", -12.0], ["fire_loop", -24.0]],
	"b1_16": [["crowd_loop", -16.0], ["wind_loop", -18.0]],
}
const STEPS := {"floor": "step_floor", "round_room": "step_floor", "town": "step_gravel", "heath": "step_grass"}

## Set when one story scene leads straight into the next (data "next").
static var _next_story := ""

var _step_t := 0.0
var _tick_t := 0.0
## Traffic lanes: [{def, lanes: [{x, spd}], walkers: [HousePerson]}]
var _traffic: Array[Dictionary] = []
var _following := false
## Tap (or click) to walk: where to, and what to use on arrival.
var walk_goal := Vector2.INF
var walk_use := ""
var _walk_stuck := 0.0
var _stride_t := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--story="):
			id = a.substr(8)
		elif a == "--autotest":
			autotest = true
		elif a.begins_with("--shots="):
			_shot_dir = a.substr(8)
		elif a.begins_with("--shot-times="):
			for v in a.substr(13).split(","):
				_shot_times.append(float(v))
	if _next_story != "":
		id = _next_story
		_next_story = ""
	if id == "":
		id = CampaignState.story_id()
	data = load("res://scripts/story/chapters/%s.gd" % id).data()

	var cm := CanvasModulate.new()
	base_light = data.get("light", Color(1, 1, 1))
	cm.color = base_light
	add_child(cm)
	canvas_mod = cm
	world = StoryWorld.new()
	world.setup(data)
	add_child(world)
	for m in data.get("machines", []):
		var md: Dictionary = (m as Dictionary).duplicate(true)
		md["i"] = 0
		world.machines.append(md)
	for l in data.get("lanterns", []):
		var lt := _light(Color(1.0, 0.75, 0.4), 1.0, 2.5)
		lt.position = l
		add_child(lt)

	var pd: Dictionary = data.player
	player = _person(pd.get("as", "narrator"), Cast.PEOPLE.get(pd.get("as", "narrator"), {}).get("name", "You"), pd.pos, pd.get("coat", Color(0.3, 0.3, 0.34)))
	if data.get("lantern", false):
		player.add_child(_light(Color(1.0, 0.85, 0.6), 0.9, 1.6))
	checkpoint = {"pos": player.position, "step": 0}
	for n in data.get("npcs", []):
		var p := _person(n.id, n.get("name", Cast.PEOPLE.get(n.id, {}).get("name", n.id)), n.pos, n.get("coat", Color(0.35, 0.3, 0.25)))
		p.collar = n.get("collar", false)
		p.visible = n.get("visible", true)
		npcs[n.id] = p
	for c in data.get("crowd", []):
		var area: Rect2 = c.rect
		for k in int(c.n):
			var p := _person("", "", area.position + Vector2(randf() * area.size.x, randf() * area.size.y),
				[Color(0.3, 0.25, 0.2), Color(0.22, 0.24, 0.3), Color(0.4, 0.3, 0.2), Color(0.3, 0.2, 0.28)][k % 4])
			p.facing = (c.get("face", area.get_center()) - p.position).normalized()
			p.scale = Vector2.ONE * 0.85
			crowd.append(p)

	if data.has("chaise"):
		world.chaise = (data.chaise as Dictionary).duplicate()
	for n in data.get("npcs", []):
		if n.has("ride"):
			npcs[n.id].set_meta("ride", int(n.ride))
	_setup_traffic()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = load("res://scripts/story/story_hud.gd").new()
	hud.scene = self
	layer.add_child(hud)
	_touch_layout()
	HowTo.show_once("story", self)
	Sound.music_for(id)
	for amb in data.get("ambience", AMBIENCE.get(id, [])):
		Sound.loop(amb[0], true, float(amb[1]))


func _touch_layout() -> void:
	Touch.layout({
		"stick": true,
		"buttons": [
			{"label_fn": _use_label, "key": KEY_E, "pos": Vector2(1470, 860), "r": 70.0},
			{"label_fn": func() -> String: return "" if dead or done else "RUN", "key": KEY_SHIFT, "pos": Vector2(1300, 900), "r": 50.0},
			{"label": "MENU", "key": KEY_M, "pos": Vector2(1550, 50), "r": 38.0},
			{"label": "?", "call": func() -> void: HowTo.show_card("story", self), "pos": Vector2(1460, 50), "r": 38.0},
		],
	})


func _use_label() -> String:
	if dead:
		return "TRY\nAGAIN"
	if done:
		return "GO ON"
	if not busy.is_empty():
		return ""
	var it := nearest_interactable()
	if it.is_empty():
		return ""
	return "TALK" if npcs.has(it.id) else "USE"


func _exit_tree() -> void:
	Sound.stop_loops()


func _person(pid: String, label: String, pos: Vector2, coat: Color) -> HousePerson:
	var p := HousePerson.new()
	p.label = label
	p.coat = coat
	p.position = pos
	p.set_meta("id", pid)
	add_child(p)
	return p


func _light(c: Color, energy: float, sc: float) -> PointLight2D:
	var l := PointLight2D.new()
	var t := GradientTexture2D.new()
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	t.gradient = g
	l.texture = t
	l.color = c
	l.energy = energy
	l.texture_scale = sc
	return l


func steps() -> Array:
	return data.steps


## Where the current goal is, for the gold marker: the person to talk to,
## the thing to use, or the middle of the place to reach. INF if none.
func goal_target() -> Vector2:
	if done or dead or step_i >= steps().size() or not busy.is_empty() or not queue.is_empty():
		return Vector2.INF
	var w: Dictionary = steps()[step_i].get("when", {})
	if w.has("talk") and npcs.has(w.talk) and (npcs[w.talk] as HousePerson).visible:
		return (npcs[w.talk] as HousePerson).position
	if w.has("use"):
		for pr in data.get("props", []):
			if pr.get("id", "") == w.use:
				return pr.pos
	if w.has("reach"):
		var r: Variant = data.get("areas", {}).get(w.reach)
		if r is Rect2:
			return (r as Rect2).get_center()
	return Vector2.INF


## The current step's tutorial tip, keyboard or touch version ("" if none).
func tip() -> String:
	if done or dead or step_i >= steps().size() or not queue.is_empty():
		return ""
	if not busy.is_empty() and busy.kind != "scope":
		return ""
	var t: Variant = steps()[step_i].get("tip")
	if busy.get("kind", "") == "scope":
		t = data.get("scope_tip")
	if t is Dictionary:
		return String((t as Dictionary).get("touch" if Touch.is_touch() else "keys", ""))
	return ""


func goal() -> String:
	if done or step_i >= steps().size():
		return ""
	return steps()[step_i].get("goal", "")


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	time += delta
	if _shot_dir != "" and not _shot_times.is_empty() and time >= _shot_times[0]:
		_shoot(_shot_times.pop_front())
	_move_npcs(delta)
	_update_traffic(delta)
	_update_chaise(delta)
	_update_ray(delta)
	_update_machines(delta)
	_update_storm(delta)
	if done or dead:
		if autotest and done:
			_finish_test()
		return
	if autotest:
		_autoplay(delta)
	# blocking actions
	if not busy.is_empty():
		match busy.kind:
			"wait":
				busy.t -= delta
				if busy.t <= 0.0:
					busy = {}
			"scope":
				scope_t += delta
				_tick_t -= delta
				if _tick_t <= 0.0:
					_tick_t = 1.0
					Sound.play("clock_tick", -6.0, 0.0)
		if not busy.is_empty() and busy.kind != "wait":
			return
	if busy.is_empty() and not queue.is_empty():
		_run(queue.pop_front())
		return
	if busy.is_empty() and queue.is_empty() and step_i < steps().size():
		step_t += delta
		_move_player(delta)
		var st: Dictionary = steps()[step_i]
		if _met(st.get("when", {"auto": true})):
			interacted = ""
			queue = (st.get("do", []) as Array).duplicate(true)
			step_i += 1
			step_t = 0.0
	elif busy.is_empty() or busy.kind == "wait":
		_move_player(delta)


func _met(w: Dictionary) -> bool:
	if w.has("auto"):
		return true
	if w.has("after"):
		return step_t >= float(w.after)
	if w.has("talk"):
		return interacted == w.talk
	if w.has("use"):
		return interacted == w.use
	if w.has("reach"):
		return world.in_area(player.position, w.reach)
	return false


func _run(a: Array) -> void:
	match a[0]:
		"say":
			var who: String = a[1]
			var text = a[2]
			var line: String = " ".join(text) if text is Array else text
			busy = {"kind": "say", "who": who, "text": line}
			var speaker := _speaker(who)
			if speaker:
				speaker.say(line.left(60) + ("..." if line.length() > 60 else ""), 4.0)
			_log("%s: \"%s\"" % [_name(who), line])
		"narr":
			busy = {"kind": "narr", "text": a[1]}
			_log("~ " + a[1])
		"plate":
			busy = {"kind": "plate", "file": a[1], "text": a[2]}
			Sound.play("page_turn", -6.0)
			_log("[plate %s] %s" % [a[1], a[2]])
		"scope":
			busy = {"kind": "scope"}
			scope_t = 0.0
			scope_flash = randf_range(3.0, 6.0)
			scope_seen = false
			scope_note = ""
		"wait":
			busy = {"kind": "wait", "t": float(a[1])}
		"move":
			npc_goal[a[1]] = [a[2], float(a[3]) if a.size() > 3 else NPC_SPEED]
		"show":
			if npcs.has(a[1]):
				npcs[a[1]].visible = a[2]
		"burn":
			if npcs.has(a[1]):
				var p: HousePerson = npcs[a[1]]
				p.down = true
				p.coat = Color(0.05, 0.04, 0.04)
				npc_goal.erase(a[1])
				world.add_fire(p.position, 10.0)
				Sound.play("ignite", -2.0, 0.15)
				if Sound.chance(0.6):
					Sound.play("scream", -10.0, 0.2)
		"fire":
			world.add_fire(a[1], float(a[2]))
			Sound.play("ignite", -4.0, 0.15)
		"sfx":
			# ["sfx", name, volume dB]: a one-off sound effect
			Sound.play(a[1], float(a[2]) if a.size() > 2 else 0.0)
		"loop":
			# ["loop", name, on, volume dB]: start or stop an ambience
			Sound.loop(a[1], a[2], float(a[3]) if a.size() > 3 else 0.0)
		"puffs":
			Sound.play("smoke_hiss", -4.0)
			for k in 3:
				world.puffs.append({"p": a[1] + Vector2(k * 14 - 14, 0), "t": -k * 0.4})
		"panic":
			for c in crowd:
				var away: Vector2 = c.position - data.get("panic_from", Vector2(800, 450))
				crowd_goal[c] = c.position + away.normalized() * 900.0
			Sound.loop("crowd_loop", false)
			Sound.loop("panic_loop", true, -4.0)
			Sound.play("scream", -6.0)
		"martian":
			world.martian_at = a[1]
			Sound.play("tentacle", -6.0)
		"open_cylinder":
			world.cylinder_open = true
			Sound.play("cylinder_open")
		"ray":
			ray = (a[1] as Dictionary).duplicate()
			ray["a"] = ray.get("start", ray.min)
			ray["dir"] = 1.0
			ray["on"] = true
			Sound.play("ray_fire")
			Sound.loop("ray_hum", true, -8.0)
		"machine":
			# ["machine", index, pos, speed]: send a machine somewhere (stops its patrol)
			var m: Dictionary = world.machines[a[1]]
			m["path"] = [a[2]]
			m["i"] = 0
			m["speed"] = float(a[3]) if a.size() > 3 else 60.0
			m["loop"] = false
		"storm_on":
			data["storm"] = true
			Sound.loop("rain_loop", true, -4.0)
			next_flash = 2.5
		"checkpoint":
			checkpoint = {"pos": player.position, "step": step_i}
			if world.chaise.has("pos"):
				checkpoint["chaise"] = world.chaise.pos
		"speed":
			# ["speed", multiplier]: how fast the player can walk
			data["player_speed"] = float(a[1])
		"down":
			# ["down", npc, true/false]: knocked down (or back on their feet)
			if npcs.has(a[1]):
				npcs[a[1]].down = bool(a[2])
				npc_goal.erase(a[1])
		"follow":
			# ["follow", true/false]: the pony-chaise follows the player
			_following = bool(a[1])
		"ride":
			# ["ride", npc, seat]: an npc sits in the chaise (seat 0 or 1; -1 gets out)
			if npcs.has(a[1]):
				if int(a[2]) < 0:
					npcs[a[1]].remove_meta("ride")
				else:
					npcs[a[1]].set_meta("ride", int(a[2]))
		"chaise_to":
			# ["chaise_to", pos]: put the chaise somewhere (and stop following)
			_following = false
			world.chaise["pos"] = a[1]
		"end":
			done = true
			Sound.loop("ray_hum", false)
			Sound.play("sting_win", -8.0)
			ray = {}
			world.ray_from = Vector2.INF
			_log("== chapter complete")


func _speaker(who: String) -> HousePerson:
	if npcs.has(who):
		return npcs[who]
	if who == player.get_meta("id"):
		return player
	return null


func _name(who: String) -> String:
	if npcs.has(who):
		return npcs[who].label
	if who == player.get_meta("id"):
		return player.label
	if Cast.PEOPLE.has(who):
		return Cast.PEOPLE[who].name
	return data.get("voices", {}).get(who, who.capitalize())


func portrait_for(who: String) -> String:
	return who if Cast.PEOPLE.has(who) else ""


func speaker_name(who: String) -> String:
	return _name(who)


# ---------------------------------------------------------------- movement

func _move_player(delta: float) -> void:
	if dead or done:
		return
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if v != Vector2.ZERO:
		walk_goal = Vector2.INF
		walk_use = ""
	elif walk_goal != Vector2.INF:
		v = _walk_dir(delta)
	player.moving = v != Vector2.ZERO
	if v == Vector2.ZERO:
		_step_t = 0.0
		return
	v = v.normalized()
	var spd := (170.0 if Input.is_key_pressed(KEY_SHIFT) else 110.0) * float(data.get("player_speed", 1.0))
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.27 if spd > 120.0 else 0.38
		Sound.play_any(STEPS.get(data.get("ground", "heath"), "step_grass"), 2, -10.0)
	var step := v * spd * delta
	var q := player.position + Vector2(step.x, 0)
	if not world.solid(q, 10.0):
		player.position = q
	q = player.position + Vector2(0, step.y)
	if not world.solid(q, 10.0):
		player.position = q
	player.facing = v


## Walking towards a tapped spot; on reaching a tapped person or thing, use it.
func _walk_dir(delta: float) -> Vector2:
	if walk_use != "":
		var it := nearest_interactable()
		if not it.is_empty() and it.id == walk_use:
			interacted = walk_use
			walk_goal = Vector2.INF
			walk_use = ""
			return Vector2.ZERO
	var d := walk_goal - player.position
	if d.length() < 6.0:
		walk_goal = Vector2.INF
		walk_use = ""
		return Vector2.ZERO
	# give up if something solid is in the way
	var before := player.position
	if before.distance_to(walk_goal) > 6.0 and _walk_stuck > 0.6:
		walk_goal = Vector2.INF
		walk_use = ""
		_walk_stuck = 0.0
		return Vector2.ZERO
	var dir := d.normalized()
	var q := player.position + dir * 110.0 * delta
	if world.solid(q, 10.0) and world.solid(player.position + Vector2(dir.x, 0) * 110.0 * delta, 10.0) and world.solid(player.position + Vector2(0, dir.y) * 110.0 * delta, 10.0):
		_walk_stuck += delta
	else:
		_walk_stuck = 0.0
	return dir


## A tap or click on the scene: walk there, or to the person or thing tapped.
func _tap(p: Vector2) -> void:
	walk_use = ""
	walk_goal = p
	var bd := 46.0
	for nid in npcs.keys():
		var n: HousePerson = npcs[nid]
		if n.visible and not n.down and n.position.distance_to(p) < bd:
			bd = n.position.distance_to(p)
			walk_use = nid
			walk_goal = n.position
	for pr in data.get("props", []):
		if pr.has("id") and (pr.pos as Vector2).distance_to(p) < maxf(bd, 60.0):
			bd = (pr.pos as Vector2).distance_to(p)
			walk_use = pr.id
			walk_goal = pr.pos
	_walk_stuck = 0.0


# ---------------------------------------------------------------- traffic

## Lanes of fleeing traffic: carts and cabs (deadly to touch) and people on
## foot, all streaming one way. Inside a lane you are pushed along with it.
func _setup_traffic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for t in data.get("traffic", []):
		var r: Rect2 = t.rect
		var d: Vector2 = t.get("dir", Vector2.UP)
		var across := r.size.x if absf(d.y) > 0.5 else r.size.y
		var along := r.size.y if absf(d.y) > 0.5 else r.size.x
		# "band": where the wheels run, across the lane (the margins are for people on foot)
		var band: Vector2 = t.get("band", Vector2(0, across))
		var nl := maxi(1, int((band.y - band.x) / 70.0))
		var lanes := []
		for i in nl:
			var off := band.x + (i + 0.5) * (band.y - band.x) / nl
			var sp: Array = t.get("speed", [70.0, 140.0])
			lanes.append({"off": off, "spd": rng.randf_range(sp[0], sp[1])})
		var info := {"def": t, "lanes": lanes, "walkers": [], "dir": d}
		var kinds := [["cart", Color(0.4, 0.3, 0.18), 90.0, 40.0, 1], ["cab", Color(0.12, 0.12, 0.14), 70.0, 36.0, 1],
			["waggon", Color(0.5, 0.38, 0.2), 130.0, 48.0, 2], ["carriage", Color(0.2, 0.08, 0.06), 90.0, 40.0, 2]]
		for k in int(t.get("vehicles", 0)):
			var lane: Dictionary = lanes[k % nl]
			var kd: Array = kinds[rng.randi() % kinds.size()]
			var pos_along := fmod(k * 0.37 + (k / nl) * 0.5, 1.0) * along
			var v := {"lane": lanes.find(lane), "t": info, "dir": d, "kind": kd[0], "col": kd[1], "len": kd[2], "w": kd[3], "horses": kd[4]}
			v["p"] = _lane_point(r, d, lane.off, pos_along)
			world.vehicles.append(v)
		for k in int(t.get("walkers", 0)):
			var w := _person("", "", _lane_point(r, d, rng.randf() * across, rng.randf() * along),
				[Color(0.3, 0.25, 0.2), Color(0.22, 0.24, 0.3), Color(0.4, 0.3, 0.2), Color(0.3, 0.2, 0.28), Color(0.5, 0.48, 0.42)][k % 5])
			w.scale = Vector2.ONE * 0.85
			w.facing = d
			w.moving = true
			w.set_meta("spd", rng.randf_range(55.0, 95.0))
			info.walkers.append(w)
		_traffic.append(info)


func _lane_point(r: Rect2, d: Vector2, off: float, along: float) -> Vector2:
	# along runs in the direction of travel, from the entry edge
	if absf(d.y) > 0.5:
		return Vector2(r.position.x + off, r.end.y - along if d.y < 0 else r.position.y + along)
	return Vector2(r.end.x - along if d.x < 0 else r.position.x + along, r.position.y + off)


func _wrap(p: Vector2, r: Rect2, d: Vector2) -> Vector2:
	if d.y < -0.5 and p.y < r.position.y - 60: p.y = r.end.y + 60
	elif d.y > 0.5 and p.y > r.end.y + 60: p.y = r.position.y - 60
	elif d.x < -0.5 and p.x < r.position.x - 60: p.x = r.end.x + 60
	elif d.x > 0.5 and p.x > r.end.x + 60: p.x = r.position.x - 60
	return p


func _update_traffic(delta: float) -> void:
	for info in _traffic:
		var t: Dictionary = info.def
		var r: Rect2 = t.rect
		var d: Vector2 = info.dir
		for w in info.walkers:
			var hp: HousePerson = w
			hp.position = _wrap(hp.position + d * float(hp.get_meta("spd")) * delta, r, d)
		# the stream carries you along (in the carriageway; the margins are slower)
		if r.has_point(player.position) and not dead and not done:
			var off := player.position.x - r.position.x if absf(d.y) > 0.5 else player.position.y - r.position.y
			var band: Vector2 = t.get("band", Vector2(-1e9, 1e9))
			var k := 1.0 if (off >= band.x and off <= band.y) else 0.15
			var q := player.position + d * float(t.get("push", 40.0)) * k * delta
			if not world.solid(q, 10.0):
				player.position = q
	for v in world.vehicles:
		var info: Dictionary = v.t
		var lane: Dictionary = info.lanes[v.lane]
		v.p = _wrap((v.p as Vector2) + (v.dir as Vector2) * float(lane.spd) * delta, info.def.rect, v.dir)
		if dead or done or autotest or not busy.is_empty():
			continue
		# under the wheels?
		var rel: Vector2 = player.position - (v.p as Vector2)
		var dd: Vector2 = v.dir
		var along := rel.dot(dd)
		var side := absf(rel.dot(dd.orthogonal()))
		if along > -float(v.len) * 0.5 and along < float(v.len) * 0.18 + 30.0 and side < float(v.w) * 0.5 + 2.0:
			_die(String(info.def.get("why", "You went down under the wheels.")))
			player.down = true
			Sound.play("scream", -4.0)


## The pony-chaise trails behind the player; its passengers ride in it.
func _update_chaise(delta: float) -> void:
	if world.chaise.is_empty():
		return
	var cp: Vector2 = world.chaise.pos
	if _following and not dead:
		var to := player.position - cp
		if to.length() > 70.0:
			world.chaise["dir"] = to.normalized()
			world.chaise["pos"] = cp + to.normalized() * (to.length() - 70.0)
	var cd: Vector2 = world.chaise.get("dir", Vector2.RIGHT)
	for nid in npcs.keys():
		var p: HousePerson = npcs[nid]
		if p.has_meta("ride"):
			var seat := int(p.get_meta("ride"))
			p.position = (world.chaise.pos as Vector2) - cd * 6.0 + cd.orthogonal() * (8.0 if seat == 0 else -8.0)
			p.facing = cd
			p.moving = false
			npc_goal.erase(nid)


func _move_npcs(delta: float) -> void:
	for nid in npc_goal.keys():
		var p: HousePerson = npcs[nid]
		var g: Vector2 = npc_goal[nid][0]
		var d := g - p.position
		var step: float = npc_goal[nid][1] * delta
		p.moving = d.length() > 2.0
		if d.length() <= step:
			p.position = g
			npc_goal.erase(nid)
			p.moving = false
		else:
			p.facing = d.normalized()
			p.position += p.facing * step
	for c in crowd_goal.keys():
		var p: HousePerson = c
		var d: Vector2 = crowd_goal[c] - p.position
		p.moving = true
		p.facing = d.normalized()
		p.position += p.facing * 140.0 * delta
		if p.position.x < -30 or p.position.y < -30 or p.position.x > 1630 or p.position.y > 930:
			p.visible = false


## The heat-ray: an invisible jet sweeping from the pit, made visible by what
## it ignites. Touching it is death unless you are behind a sand hummock.
func _update_ray(delta: float) -> void:
	if ray.is_empty() or not ray.on:
		return
	ray.a += ray.speed * ray.dir * delta
	if ray.a > ray.max:
		ray.a = ray.max
		ray.dir = -1.0
	elif ray.a < ray.min:
		ray.a = ray.min
		ray.dir = 1.0
	var from: Vector2 = ray.from
	var dir := Vector2.from_angle(ray.a)
	world.ray_from = from
	world.ray_to = from + dir * ray.len
	if randf() < delta * 6.0:
		world.add_fire(from + dir * randf_range(120.0, ray.len), randf_range(5.0, 9.0))
	if world.fires.size() > 60:
		world.fires.remove_at(0)
	if dead or done or autotest:
		return
	var to_p := player.position - from
	var along := to_p.dot(dir)
	if along > 0.0 and along < ray.len:
		var off := absf(to_p.cross(dir))
		if off < 16.0 and not world.in_cover(player.position):
			_die("It was as if you were suddenly and momentarily turned to fire.")
			player.down = true
			world.add_fire(player.position, 12.0)
			Sound.play("ignite")


func _update_machines(delta: float) -> void:
	for m in world.machines:
		var path: Array = m.get("path", [])
		if path.is_empty():
			continue
		var tgt: Vector2 = path[m.i]
		var d: Vector2 = tgt - (m.pos as Vector2)
		var step: float = m.get("speed", 40.0) * delta
		if d.length() > step:
			# a stride every so often, louder the closer the machine is
			var k := world.machines.find(m)
			_stride_t[k] = float(_stride_t.get(k, Sound.rand(0.0, 1.0))) - delta
			if _stride_t[k] <= 0.0:
				_stride_t[k] = clampf(90.0 / maxf(m.get("speed", 40.0), 1.0), 0.7, 2.2)
				var dist := (m.pos as Vector2).distance_to(player.position)
				Sound.play("stride", clampf(-dist / 60.0, -24.0, 0.0), 0.08)
		if d.length() <= step:
			m.pos = tgt
			if m.get("loop", true):
				m.i = (m.i + 1) % path.size()
			elif m.i < path.size() - 1:
				m.i += 1
		else:
			m.facing = d.normalized()
			m.pos = (m.pos as Vector2) + d.normalized() * step


## The thunderstorm: blinding flashes, and in each flash the machines can see
## anyone out in the open. A flicker in the sky warns of the next one.
func _update_storm(delta: float) -> void:
	if not data.get("storm", false):
		return
	world.flash = maxf(0.0, world.flash - delta * 3.0)
	next_flash -= delta
	pre_flash = clampf(1.0 - next_flash / 0.9, 0.0, 1.0) if next_flash < 0.9 else 0.0
	if next_flash <= 0.0:
		next_flash = randf_range(3.2, 5.5)
		world.flash = 1.0
		Sound.play_any("thunder", 2, 0.0)
		if not dead and not done and not autotest and busy.is_empty():
			for m in world.machines:
				if (m.pos as Vector2).distance_to(player.position) < m.get("view", 380.0) and not world.in_cover(player.position):
					_die("The lightning lit you up in the open, and the hood turned towards you.")
					break
	var flick := pre_flash * 0.15 * absf(sin(time * 40.0))
	canvas_mod.color = base_light.lerp(Color(0.95, 0.92, 1.0), clampf(world.flash + flick, 0.0, 1.0))


func _die(why: String) -> void:
	dead = true
	dead_why = why
	Sound.play("sting_death", -2.0, 0.0)


func respawn() -> void:
	if world.chaise.has("pos") and checkpoint.has("chaise"):
		world.chaise["pos"] = checkpoint.chaise
	walk_goal = Vector2.INF
	walk_use = ""
	dead = false
	player.down = false
	player.position = checkpoint.pos


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dead:
			respawn()
		elif done:
			_complete()
		elif not busy.is_empty():
			advance()
		else:
			_tap(get_canvas_transform().affine_inverse() * (event as InputEventMouseButton).position)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if dead:
				respawn()
			elif done:
				_complete()
			else:
				advance()
		KEY_R:
			if dead:
				respawn()
			else:
				get_tree().reload_current_scene()
		KEY_M, KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/campaign.tscn")


func advance() -> void:
	if not busy.is_empty():
		match busy.kind:
			"say", "narr", "plate":
				busy = {}
			"scope":
				if scope_t >= scope_flash:
					scope_seen = true
					busy = {}
				else:
					scope_note = "Nothing yet. Keep watching the planet..."
		return
	var t := nearest_interactable()
	if not t.is_empty():
		interacted = t.id


## The nearest person or thing the player can talk to or use, or {}.
func nearest_interactable() -> Dictionary:
	var best := {}
	var bd := 60.0
	for nid in npcs.keys():
		var p: HousePerson = npcs[nid]
		if p.visible and not p.down and p.position.distance_to(player.position) < bd:
			bd = p.position.distance_to(player.position)
			best = {"id": nid, "prompt": "talk to " + p.label}
	for pr in data.get("props", []):
		if pr.has("id") and (pr.pos as Vector2).distance_to(player.position) < pr.get("reach", 70.0) and (pr.pos as Vector2).distance_to(player.position) < bd + 20.0:
			best = {"id": pr.id, "prompt": pr.get("prompt", "examine")}
	return best


func _complete() -> void:
	if data.has("next"):
		# this chapter goes on in another place: load the next scene of it
		_next_story = data.next
		get_tree().reload_current_scene()
		return
	if CampaignState.active:
		CampaignState.complete()
	else:
		get_tree().change_scene_to_file("res://scenes/campaign.tscn")


func _log(s: String) -> void:
	transcript.append(s)
	if autotest:
		print("[%5.1f] %s" % [time, s])


# ---------------------------------------------------------------- automated test
# godot --headless --fixed-fps 30 res://scenes/story_scene.tscn -- --story=b1_01 --autotest

func _autoplay(delta: float) -> void:
	if not busy.is_empty():
		if busy.kind in ["say", "narr", "plate"]:
			busy = {}
		elif busy.kind == "scope" and scope_t > scope_flash:
			scope_seen = true
			busy = {}
		return
	if not queue.is_empty() or step_i >= steps().size():
		return
	var w: Dictionary = steps()[step_i].get("when", {})
	if w.has("talk") and npcs.has(w.talk):
		player.position = npcs[w.talk].position + Vector2(30, 0)
		interacted = w.talk
	elif w.has("use"):
		interacted = w.use
	elif w.has("reach") and step_t > 4.0:
		player.position = (data.areas[w.reach] as Rect2).get_center()


func _finish_test() -> void:
	if Sound.is_quitting():
		return
	print("--- story %s complete: %d lines, %d steps" % [id, transcript.size(), steps().size()])
	if _shot_dir == "":
		Sound.quit_game()


func _shoot(t: float) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/story_%s_%03d.png" % [_shot_dir, id, int(t)])
	print("screenshot ", id, " ", t)
