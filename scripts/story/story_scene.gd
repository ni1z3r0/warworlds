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

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = load("res://scripts/story/story_hud.gd").new()
	hud.scene = self
	layer.add_child(hud)


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
		"fire":
			world.add_fire(a[1], float(a[2]))
		"puffs":
			for k in 3:
				world.puffs.append({"p": a[1] + Vector2(k * 14 - 14, 0), "t": -k * 0.4})
		"panic":
			for c in crowd:
				var away: Vector2 = c.position - data.get("panic_from", Vector2(800, 450))
				crowd_goal[c] = c.position + away.normalized() * 900.0
		"martian":
			world.martian_at = a[1]
		"open_cylinder":
			world.cylinder_open = true
		"ray":
			ray = (a[1] as Dictionary).duplicate()
			ray["a"] = ray.get("start", ray.min)
			ray["dir"] = 1.0
			ray["on"] = true
		"machine":
			# ["machine", index, pos, speed]: send a machine somewhere (stops its patrol)
			var m: Dictionary = world.machines[a[1]]
			m["path"] = [a[2]]
			m["i"] = 0
			m["speed"] = float(a[3]) if a.size() > 3 else 60.0
			m["loop"] = false
		"storm_on":
			data["storm"] = true
			next_flash = 2.5
		"checkpoint":
			checkpoint = {"pos": player.position, "step": step_i}
		"end":
			done = true
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
	player.moving = v != Vector2.ZERO
	if v == Vector2.ZERO:
		return
	v = v.normalized()
	var spd := 170.0 if Input.is_key_pressed(KEY_SHIFT) else 110.0
	var step := v * spd * delta
	var q := player.position + Vector2(step.x, 0)
	if not world.solid(q, 10.0):
		player.position = q
	q = player.position + Vector2(0, step.y)
	if not world.solid(q, 10.0):
		player.position = q
	player.facing = v


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
			dead = true
			dead_why = "It was as if you were suddenly and momentarily turned to fire."
			player.down = true
			world.add_fire(player.position, 12.0)


func _update_machines(delta: float) -> void:
	for m in world.machines:
		var path: Array = m.get("path", [])
		if path.is_empty():
			continue
		var tgt: Vector2 = path[m.i]
		var d: Vector2 = tgt - (m.pos as Vector2)
		var step: float = m.get("speed", 40.0) * delta
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
		if not dead and not done and not autotest and busy.is_empty():
			for m in world.machines:
				if (m.pos as Vector2).distance_to(player.position) < m.get("view", 380.0) and not world.in_cover(player.position):
					dead = true
					dead_why = "The lightning lit you up in the open, and the hood turned towards you."
					break
	var flick := pre_flash * 0.15 * absf(sin(time * 40.0))
	canvas_mod.color = base_light.lerp(Color(0.95, 0.92, 1.0), clampf(world.flash + flick, 0.0, 1.0))


func respawn() -> void:
	dead = false
	player.down = false
	player.position = checkpoint.pos


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		advance()
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
	print("--- story %s complete: %d lines, %d steps" % [id, transcript.size(), steps().size()])
	if _shot_dir == "":
		get_tree().quit()


func _shoot(t: float) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/story_%s_%03d.png" % [_shot_dir, id, int(t)])
	print("screenshot ", id, " ", t)
