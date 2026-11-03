extends Node2D
## CHAPTER VI: THE RUINED HOUSE (stealth)
## Book Two, chapters I-V. The fifth cylinder has buried the house where the
## Narrator sheltered with the Curate. For fifteen days they live beside the
## Martians' pit. Keep quiet. Keep out of the light. Keep the Curate sane.

enum C { QUIET, UNEASY, BROKEN, DOWN, TAKEN, FREE }
enum G { IDLE, WARN, LOOK }

const DAY := 20.0             # seconds per day
const DAYS := 15
const NARRATOR_SPEED := 75.0
const HURRY_SPEED := 150.0
const CURATE_SPOTS := [Vector2(960, 380), Vector2(900, 600), Vector2(700, 350), Vector2(520, 580), Vector2(640, 600), Vector2(330, 360), Vector2(560, 240)]
# The Curate's own words (checked against the novel by tools/check_quotes.py
# through scripts/story.gd and scripts/cast.gd; these are from Book Two ch. III-IV).
const MUTTER := ["We are safe here", "God have mercy upon us!", "It is just, O God!", "What do these things mean?"]
const SHOUTS := ["I have been still too long", "Woe unto this unfaithful city!", "Woe! Woe! Woe! Woe! Woe!", "Speak! The word of the Lord is upon me!", "I must bear my witness! I go!"]

var map: HouseMap
var narrator: HousePerson
var curate: HousePerson
var tentacle: Tentacle = null
var hud: Control
var hole_light: PointLight2D
var pit_light: PointLight2D
var beam_fx: Node2D
var messages: Array[Dictionary] = []

var time := 0.0
var day := 1
var ended := false
var result := ""
var ending := ""
var paused := false
var show_help := true
var peeping := false

# narrator
var in_coal := false
var carrying := false
var rations := 5
var touched_t := 0.0
var touched_once := false
var calm_hold := 0.0
var calms_today := 0
var _step_t := 0.0
var noise_ring := 0.0

# curate
var nerve := 70.0
var cstate: C = C.QUIET
var c_path := PackedVector2Array()
var c_wait := 6.0
var c_talk := 8.0
var c_shout_i := 0
var c_down_t := 0.0
var c_preach := 0.0

# the Martians
var susp := 0.0
var loud_pos := Vector2.ZERO
var loud_amt := 0.0
var gaze: G = G.IDLE
var gaze_t := 10.0
var seen_t := 0.0
var tentacle_cd := 0.0
var second_search_t := -1.0
var second_search_pos := Vector2.ZERO
var martians_gone := false
var _events_done := {}

var autotest := false
var _steps: Array = []
var _shot_dir := ""
var _shot_times: Array = []


func _ready() -> void:
	var cm := CanvasModulate.new()
	cm.color = Color(0.36, 0.3, 0.25)
	add_child(cm)
	map = HouseMap.new()
	add_child(map)
	add_child(load("res://scripts/house/pit_view.gd").new())

	beam_fx = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	beam_fx.material = mat
	beam_fx.z_index = 5
	add_child(beam_fx)
	beam_fx.draw.connect(_draw_beams)

	narrator = HousePerson.new()
	narrator.label = "The Narrator"
	narrator.coat = Color(0.3, 0.3, 0.34)
	narrator.position = Vector2(880, 612)
	add_child(narrator)
	curate = HousePerson.new()
	curate.label = "The Curate"
	curate.coat = Color(0.07, 0.07, 0.08)
	curate.collar = true
	curate.position = Vector2(960, 590)
	add_child(curate)

	var warm := _light(Color(1.0, 0.85, 0.6), 0.75, 1.3)
	narrator.add_child(warm)
	hole_light = _light(Color(0.5, 1.0, 0.6), 0.6, 2.2)
	hole_light.position = Vector2(980, 480)
	add_child(hole_light)
	pit_light = _light(Color(0.45, 1.0, 0.55), 0.6, 5.0)
	pit_light.position = Vector2(1400, 470)
	add_child(pit_light)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = load("res://scripts/house/house_hud.gd").new()
	hud.mode = self
	layer.add_child(hud)

	log_msg("The fifth cylinder has fallen on the house. You are buried alive beside the Martians' pit.")
	log_msg("Keep quiet, keep out of the green light, and keep the Curate from breaking.")
	curate.say("We are safe here", 4.0)
	_parse_args()


func _light(c: Color, energy: float, scale_: float) -> PointLight2D:
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
	l.texture_scale = scale_
	return l


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if _shot_dir != "" and not _shot_times.is_empty() and time >= _shot_times[0]:
		_shoot(_shot_times.pop_front())
	beam_fx.queue_redraw()
	if paused or ended:
		return
	time += delta
	var d := mini(DAYS, 1 + int(time / DAY))
	if d != day:
		day = d
		calms_today = 0
		_day_event(day)
	if autotest:
		_run_test()
	_move_narrator(delta)
	_actions(delta)
	_curate_ai(delta)
	_martians(delta)
	_tentacle(delta)
	noise_ring = maxf(0.0, noise_ring - delta * 2.0)


func _day_event(d: int) -> void:
	if _events_done.has(d):
		return
	_events_done[d] = true
	match d:
		2:
			log_msg("Day 2. Through the slit you watch a handling-machine unpacking the cylinder.")
		3:
			log_msg("Day 3. The Martians are feeding, in full view of the peephole. The Curate saw it too.")
			_shock(15.0)
		6:
			log_msg("Day 6. A second fighting-machine arrives. The light will sweep the house more often.")
		9:
			log_msg("Day 9. They feed again. The Curate weeps in the dark.")
			_shock(15.0)
		14:
			martians_gone = true
			log_msg("Day 14. The red weed has grown right across the hole in the wall. The pit has gone quiet.")
			hole_light.color = Color(1.0, 0.3, 0.2)
			pit_light.color = Color(1.0, 0.3, 0.2)
		15:
			map.open_hole()
			log_msg("Day 15. A dog's nose peers in through the red weed. The pit is empty. Climb out through the hole!")


func _shock(n: float) -> void:
	if cstate == C.QUIET or cstate == C.UNEASY:
		nerve = maxf(0.0, nerve - n)


# ---------------------------------------------------------------- narrator

func _input_dir() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	return v.normalized()


func _move_narrator(delta: float) -> void:
	var v := _input_dir()
	if touched_t > 0.0:
		touched_t -= delta
		if v != Vector2.ZERO:
			_lose("You flinched. The tentacle gripped your boot and dragged you out into the pit.")
			return
		if touched_t <= 0.0:
			log_msg("It grips a lump of coal instead, and withdraws.")
	if in_coal or peeping or v == Vector2.ZERO:
		narrator.moving = false
		return
	var hurry := Input.is_key_pressed(KEY_SHIFT)
	var spd := HURRY_SPEED if hurry else NARRATOR_SPEED
	narrator.position = map.slide(narrator.position, v * spd * delta, 10.0)
	narrator.facing = v
	narrator.moving = true
	_step_t -= delta
	if _step_t <= 0.0:
		if hurry:
			make_noise(narrator.position, 260.0, 20.0)
			_step_t = 0.3
		elif map.on_crockery(narrator.position):
			make_noise(narrator.position, 170.0, 13.0)
			_step_t = 0.5
		else:
			_step_t = 0.1


func context_action() -> String:
	var p := narrator.position
	if in_coal:
		return "E  climb out of the coal"
	if peeping:
		return "E  step back from the peephole"
	if p.distance_to(map.coal_heap) < 50.0:
		return "E  bury yourself in the coal"
	if p.distance_to(map.peephole) < 45.0:
		return "E  look through the peephole"
	if p.distance_to(map.pantry_shelf) < 60.0 and not carrying:
		return "E  take a ration (%d left)" % rations if rations > 0 else "The pantry is bare"
	if curate_near() and cstate == C.BROKEN:
		return "F  strike him with the butt of the meat chopper"
	if curate_near() and carrying and (cstate == C.QUIET or cstate == C.UNEASY):
		return "E  give the Curate food"
	if curate_near() and (cstate == C.QUIET or cstate == C.UNEASY):
		return "Hold E  calm the Curate"
	return ""


func curate_near() -> bool:
	return cstate != C.TAKEN and narrator.position.distance_to(curate.position) < 42.0


func _actions(delta: float) -> void:
	# holding E to calm the Curate
	if Input.is_key_pressed(KEY_E) and curate_near() and not carrying and not in_coal and (cstate == C.QUIET or cstate == C.UNEASY):
		calm_hold += delta
		if calm_hold >= 1.2:
			calm_hold = 0.0
			calm()
	else:
		calm_hold = 0.0


func press_e() -> void:
	var p := narrator.position
	if touched_t > 0.0:
		_lose("You flinched. The tentacle gripped your boot and dragged you out into the pit.")
		return
	if in_coal:
		in_coal = false
		narrator.in_coal = false
		log_msg("You climb out of the coal.")
	elif peeping:
		peeping = false
	elif p.distance_to(map.coal_heap) < 50.0:
		in_coal = true
		narrator.in_coal = true
		narrator.position = map.coal_heap
		log_msg("You cover yourself with firewood and coal. Don't move.")
	elif p.distance_to(map.peephole) < 45.0:
		peeping = true
	elif p.distance_to(map.pantry_shelf) < 60.0 and not carrying and rations > 0:
		rations -= 1
		carrying = true
		log_msg("You take a little bread and water from the pantry.")
	elif curate_near() and carrying and (cstate == C.QUIET or cstate == C.UNEASY):
		carrying = false
		nerve = minf(100.0, nerve + 20.0)
		curate.say("...", 1.5)
		log_msg("You give the Curate food. \"He ate more than I did.\"")


func calm() -> void:
	var gain := 14.0 * pow(0.5, calms_today)
	calms_today += 1
	nerve = minf(100.0, nerve + gain)
	log_msg("You whisper to the Curate until he is still. (+%d nerve)" % int(gain))


func strike() -> void:
	if cstate != C.BROKEN or not curate_near():
		return
	cstate = C.DOWN
	c_down_t = 30.0
	curate.down = true
	curate.speech_t = 0.0
	c_path.clear()
	make_noise(curate.position, 200.0, 10.0)
	log_msg("\"With one last touch of humanity I turned the blade back and struck him with the butt.\"")


# ---------------------------------------------------------------- the curate

func _curate_ai(delta: float) -> void:
	if cstate == C.TAKEN or cstate == C.FREE:
		return
	if cstate == C.DOWN:
		c_down_t -= delta
		if c_down_t <= 0.0:
			cstate = C.UNEASY
			nerve = 25.0
			curate.down = false
			curate.say("What do these things mean?")
		return
	if cstate != C.BROKEN:
		nerve = maxf(0.0, nerve - 0.45 * delta)
		cstate = C.UNEASY if nerve < 45.0 else C.QUIET
		if nerve <= 0.0 and not martians_gone:
			cstate = C.BROKEN
			c_shout_i = 0
			c_talk = 0.0
			c_path.clear()
			c_preach = 5.0
			log_msg("The Curate rises to his knees and begins to preach. Stop him before he goes to the Martians!")
	match cstate:
		C.QUIET, C.UNEASY:
			if gaze != G.IDLE:
				if map.in_light(curate.position):
					if c_path.is_empty():
						c_path = map.path(curate.position, _nearest_dark(curate.position))
					_walk_curate(delta, 80.0)   # he scrambles out of the light
				else:
					curate.moving = false     # and cowers in the dark until it passes
				return
			if c_path.is_empty():
				c_wait -= delta
				if c_wait <= 0.0 and gaze_t > 7.0:
					c_wait = randf_range(12.0, 22.0)
					c_path = map.path(curate.position, CURATE_SPOTS[randi() % CURATE_SPOTS.size()])
			_walk_curate(delta, 32.0)
			if cstate == C.UNEASY:
				c_talk -= delta
				if c_talk <= 0.0:
					c_talk = randf_range(7.0, 11.0)
					curate.say(MUTTER[randi() % MUTTER.size()])
					make_noise(curate.position, 230.0, 14.0)
		C.BROKEN:
			if c_preach > 0.0:
				c_preach -= delta
				curate.moving = false
				if c_preach <= 0.0:
					c_path = map.path(curate.position, map.hole + Vector2(-30, 0))
					log_msg("\"I must bear my witness! I go!\" He is going to the hole!")
			else:
				_walk_curate(delta, 34.0)
			c_talk -= delta
			if c_talk <= 0.0:
				c_talk = 2.2
				curate.say(SHOUTS[mini(c_shout_i, SHOUTS.size() - 1)], 2.2)
				c_shout_i += 1
				curate.shout = 1.0
				make_noise(curate.position, 900.0, 40.0)
			if curate.position.distance_to(map.hole) < 60.0:
				_send_tentacle(curate.position, "The Curate's cries have brought them.")


func _nearest_dark(p: Vector2) -> Vector2:
	for r in range(12, 260, 12):
		for k in 16:
			var q := p + Vector2.from_angle(k * TAU / 16.0) * r
			if not map.in_light(q) and not map.solid(q, 10.0):
				return q
	return p


func _walk_curate(delta: float, spd: float) -> void:
	curate.moving = not c_path.is_empty()
	if c_path.is_empty():
		return
	var tgt := c_path[0]
	var dv := tgt - curate.position
	var step := spd * delta
	if dv.length() <= step:
		curate.position = tgt
		c_path.remove_at(0)
	else:
		curate.facing = dv.normalized()
		curate.position += curate.facing * step
	if map.on_crockery(curate.position) and randf() < delta * 1.5:
		make_noise(curate.position, 170.0, 12.0)


# ---------------------------------------------------------------- the martians

func make_noise(p: Vector2, radius: float, amount: float) -> void:
	if p == narrator.position:
		noise_ring = 1.0
	if martians_gone:
		return
	var d := p.distance_to(map.hole)
	if d < radius:
		var a := amount * (1.0 - d / radius)
		susp += a
		if a >= loud_amt * 0.6:
			loud_pos = p
			loud_amt = a


func _martians(delta: float) -> void:
	tentacle_cd -= delta
	if martians_gone:
		gaze = G.IDLE
		hole_light.energy = 0.6
		return
	susp = maxf(0.0, susp - 3.5 * delta)
	loud_amt = maxf(0.0, loud_amt - 4.0 * delta)
	if susp >= 100.0 and tentacle == null and tentacle_cd <= 0.0:
		susp = 30.0
		_send_tentacle(loud_pos, "Something heard you. A tentacle comes groping in through the hole!")
	if second_search_t >= 0.0:
		second_search_t -= delta
		if second_search_t < 0.0 and tentacle == null:
			if in_coal:
				_send_tentacle(map.coal_heap, "It comes back, into the coal cellar, \"touching and examining the wall, coals, wood and ceiling.\"")
			else:
				_send_tentacle(second_search_pos, "It comes back. It is searching the kitchen.")
	# the light sweeping in through the hole
	gaze_t -= delta
	match gaze:
		G.IDLE:
			hole_light.energy = 0.6
			if gaze_t <= 0.0:
				gaze = G.WARN
				gaze_t = 1.6
		G.WARN:
			hole_light.energy = 0.6 + 0.5 * absf(sin(time * 12.0))
			if gaze_t <= 0.0:
				gaze = G.LOOK
				gaze_t = 2.6
		G.LOOK:
			hole_light.energy = 1.4
			var watched := false
			if not in_coal and map.in_light(narrator.position):
				seen_t += delta
				watched = true
				if seen_t > 0.45 and tentacle == null:
					_send_tentacle(narrator.position, "THE MARTIAN HAS SEEN YOU!", 170.0)
			if (cstate == C.QUIET or cstate == C.UNEASY or cstate == C.BROKEN or cstate == C.DOWN) and map.in_light(curate.position) and tentacle == null:
				_send_tentacle(curate.position, "The light falls on the Curate. They have seen him!", 150.0)
			if not watched:
				seen_t = 0.0
			if gaze_t <= 0.0:
				gaze = G.IDLE
				seen_t = 0.0
				gaze_t = randf_range(9.0, 14.0) * (0.7 if day >= 6 else 1.0)


func _send_tentacle(target: Vector2, msg: String, spd: float = 95.0) -> void:
	if tentacle != null or martians_gone:
		return
	tentacle = Tentacle.new()
	tentacle.speed = spd
	add_child(tentacle)
	tentacle.start(map, target)
	touched_once = false
	log_msg(msg)


func _tentacle(delta: float) -> void:
	if tentacle == null:
		return
	if tentacle.state == Tentacle.T.DONE:
		if tentacle.holding == curate:
			curate.visible = false
			log_msg("The tentacle drags the Curate out into the pit. You are alone.")
		tentacle.queue_free()
		tentacle = null
		tentacle_cd = 5.0
		return
	if tentacle.state == Tentacle.T.OUT:
		return
	var tip := tentacle.tip
	if cstate != C.TAKEN and tip.distance_to(curate.position) < 24.0 and tentacle.holding == null:
		tentacle.holding = curate
		tentacle.state = Tentacle.T.OUT
		cstate = C.TAKEN
		curate.down = true
		curate.speech_t = 0.0
		second_search_t = 7.0
		second_search_pos = curate.position
		log_msg("It has the Curate!")
		return
	if tip.distance_to(narrator.position) < 26.0:
		if in_coal:
			if not touched_once:
				touched_once = true
				touched_t = 2.6
				log_msg("\"Once, even, it touched the heel of my boot.\" DON'T MOVE.")
		else:
			_lose("The tentacle found you in the dark, and gripped.")


# ---------------------------------------------------------------- endings

func _check_escape() -> void:
	if map.hole_open and map.escape_zone.has_point(narrator.position) and not ended:
		ended = true
		result = "won"
		if cstate != C.TAKEN:
			cstate = C.FREE
			ending = "You and the Curate climb out together into a red, silent world. In Wells' telling, the Curate never left the house. Here, you kept him alive."
		else:
			ending = "You climb out alone into a red, silent world, as the narrator did. The Curate's body is gone with the Martians."
		log_msg("You are out of the house.")
		_end()


func _lose(why: String) -> void:
	if ended:
		return
	ended = true
	result = "lost"
	ending = why
	log_msg(why)
	_end()


func _end() -> void:
	if autotest:
		_finish_test()


func log_msg(t: String) -> void:
	messages.append({"text": t, "t": time})
	if messages.size() > 6:
		messages.pop_front()
	if autotest:
		print("[%6.1f d%02d] %s" % [time, day, t])


func _physics_process(_d: float) -> void:
	_check_escape()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_E:
			if not paused and not ended and not curate_near_for_hold():
				press_e()
		KEY_F:
			strike()
		KEY_F1, KEY_H:
			show_help = not show_help
		KEY_ESCAPE, KEY_SPACE:
			if peeping:
				peeping = false
			elif not ended:
				paused = not paused
		KEY_R:
			get_tree().reload_current_scene()
		KEY_M:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")


## E is a hold (calming) when standing by a quiet curate with nothing to give.
func curate_near_for_hold() -> bool:
	var p := narrator.position
	if in_coal or peeping or p.distance_to(map.coal_heap) < 50.0 or p.distance_to(map.peephole) < 45.0:
		return false
	return curate_near() and not carrying and (cstate == C.QUIET or cstate == C.UNEASY)


# ---------------------------------------------------------------- drawing

func _draw_beams() -> void:
	if martians_gone:
		for poly in map.light_polys:
			beam_fx.draw_colored_polygon(poly, Color(0.35, 0.05, 0.03, 0.25))
		return
	var a := 0.12
	if gaze == G.WARN:
		a = 0.12 + 0.12 * absf(sin(time * 12.0))
	elif gaze == G.LOOK:
		a = 0.42
	for poly in map.light_polys:
		beam_fx.draw_colored_polygon(poly, Color(0.25, 0.7, 0.3, a))
	if noise_ring > 0.0:
		var r := 30.0 + (1.0 - noise_ring) * 60.0
		beam_fx.draw_arc(narrator.position, r, 0, TAU, 32, Color(1.0, 0.6, 0.3, noise_ring * 0.6), 2.0)


# ---------------------------------------------------------------- automated test
# godot --headless --fixed-fps 60 res://scenes/ruined_house.tscn -- --autotest[=caught]

func _parse_args() -> void:
	var variant := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest"):
			autotest = true
			variant = a.substr(11) if a.length() > 10 else ""
		elif a.begins_with("--shots="):
			_shot_dir = a.substr(8)
		elif a.begins_with("--shot-times="):
			for v in a.substr(13).split(","):
				_shot_times.append(float(v))
	if not autotest:
		return
	show_help = false
	if variant == "wells":
		# as in the novel: the Curate breaks and is taken; the tentacle searches the coal cellar
		_steps = [
			[30.0, func(): nerve = 0.0],
			[31.0, func(): narrator.position = map.coal_heap + Vector2(20, 0); press_e()],
			[80.0, func(): _finish_test()],
		]
		return
	if variant == "caught":
		_steps = [[1.0, func(): narrator.position = Vector2(950, 480); gaze = G.WARN; gaze_t = 0.1]]
		_steps.append([20.0, func(): _finish_test()])
		return
	_steps = [
		[1.0, func(): narrator.position = map.pantry_shelf + Vector2(0, 40); press_e()],
		[2.0, func(): narrator.position = curate.position + Vector2(20, 0); press_e()],
		[3.0, func(): calm(); calm()],
		[4.0, func(): narrator.position = map.peephole + Vector2(-10, 0); press_e()],
		[6.0, func(): press_e()],
		[30.0, func(): nerve = 0.0],
		[33.0, func(): narrator.position = curate.position + Vector2(15, 0); strike()],
		[37.0, func(): narrator.position = map.coal_heap + Vector2(20, 0); press_e()],
		[90.0, func(): press_e()],
		[100.0, func(): time = 14.0 * DAY - 0.5],
		[14.0 * DAY + 21.0, func(): narrator.position = Vector2(1000, 480)],
		[14.0 * DAY + 21.5, func(): narrator.position = Vector2(1120, 480)],
		[14.0 * DAY + 40.0, func(): _finish_test()],
	]


func _run_test() -> void:
	while not _steps.is_empty() and time >= _steps[0][0]:
		var st: Array = _steps.pop_front()
		(st[1] as Callable).call()


func _finish_test() -> void:
	print("--- house summary t=%.1f day=%d result=%s curate=%s nerve=%.0f rations=%d ending=%s" % [time, day, result, C.keys()[cstate], nerve, rations, ending])
	if _shot_dir == "":
		get_tree().quit()


func _shoot(t: float) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/house_%03d.png" % [_shot_dir, int(t)])
	print("screenshot house ", t)
