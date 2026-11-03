extends Node2D
## Mission controller for the prototype: "Chapter I - Horsell Common".
## Builds the scene, handles RTS input, resolves combat and win/lose.

const ROSTER := [
	{"name": "Ellen Ashby", "role": "Schoolteacher", "speed": 46.0, "coat": Color(0.55, 0.22, 0.42)},
	{"name": "Walter Hale", "role": "Telegraph clerk", "speed": 54.0, "coat": Color(0.25, 0.38, 0.55)},
	{"name": "Joseph Marsh", "role": "Innkeeper, 61", "speed": 36.0, "coat": Color(0.55, 0.42, 0.20)},
]

var game: Node2D
var world: World
var gun: FieldGun
var tripod: Tripod
var hud: Control
var units: Array[Unit] = []      # on the map and able to act
var roster: Array[Unit] = []     # everyone, for the HUD
var smokes: Array[BlackSmoke] = []
var selected: Array[Unit] = []
var messages: Array[Dictionary] = []

var started := false
var ended := false
var result := ""
var show_help := true
var dragging := false
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var mission_time := 0.0
var autotest := false
var _test_steps: Array = []
var _shot_dir := ""
var _shot_times := [3.0, 14.0, 24.0, 45.0]
var _frames := 0
var _help_auto_hidden := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest"):
			autotest = true

	game = Node2D.new()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)

	world = World.new()
	game.add_child(world)

	gun = FieldGun.new()
	_setup_unit(gun, "Sgt. Tolliver's gun", "Royal Horse Artillery", 38.0, Vector2(330, 262))
	gun.facing = Vector2.DOWN
	var starts := [Vector2(200, 165), Vector2(222, 182), Vector2(186, 184)]
	for i in ROSTER.size():
		var s := Survivor.new()
		s.coat = ROSTER[i].coat
		_setup_unit(s, ROSTER[i].name, ROSTER[i].role, ROSTER[i].speed, starts[i])

	tripod = Tripod.new()
	tripod.main = self
	tripod.world = world
	tripod.position = Vector2(860, 250)
	tripod.facing = Vector2.LEFT
	tripod.waypoints = [Vector2(420, 280), Vector2(250, 330), Vector2(560, 460),
		Vector2(340, 600), Vector2(760, 640), Vector2(1150, 560), Vector2(1300, 380), Vector2(1240, 250)]
	game.add_child(tripod)

	# colour grade: painted, fire-lit, vignetted
	var post_layer := CanvasLayer.new()
	post_layer.layer = 5
	add_child(post_layer)
	var post := ColorRect.new()
	post.size = Vector2(World.W, World.H)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grade.gdshader")
	post.material = mat
	post_layer.add_child(post)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = load("res://scripts/hud.gd").new()
	hud.main = self
	hud_layer.add_child(hud)

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shot_dir = a.substr(8)
		if a.begins_with("--shot-times="):
			_shot_times = []
			for v in a.substr(13).split(","):
				_shot_times.append(float(v))
	if autotest:
		_setup_autotest()
	start()


func _setup_unit(u: Unit, n: String, r: String, spd: float, pos: Vector2) -> void:
	u.world = world
	u.main = self
	u.display_name = n
	u.role = r
	u.speed = spd
	u.position = pos
	game.add_child(u)
	units.append(u)
	roster.append(u)


func start() -> void:
	started = true
	get_tree().paused = false
	log_msg("A machine has risen from the pit on Horsell Common.")
	log_msg("Get everyone across the river to the Leatherhead road.")


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_frames += 1
	if _shot_dir != "" and started and not _shot_times.is_empty() and mission_time >= _shot_times[0]:
		_shoot("t%02d" % int(_shot_times.pop_front()))
	if not started or ended or get_tree().paused:
		return
	mission_time += delta

	for u in units:
		u.in_smoke = false
	for i in range(smokes.size() - 1, -1, -1):
		if not is_instance_valid(smokes[i]):
			smokes.remove_at(i)
	for s in smokes:
		var r := s.radius() * 0.85
		for u in units:
			if u.alive and u.position.distance_to(s.position) < r:
				u.in_smoke = true
				var rate := 0.12 * (2.2 if u.in_cellar else 1.0) * s.alpha()
				u.damage(rate * delta, "choked by the black smoke")

	for u in units.duplicate():
		if u.alive and not u.in_cellar and world.exit_zone.has_point(u.position):
			u.escaped = true
			u.visible = false
			u.selected = false
			u.process_mode = Node.PROCESS_MODE_DISABLED
			units.erase(u)
			selected.erase(u)
			if u is FieldGun:
				log_msg("The gun crew withdraws down the Leatherhead road.")
			else:
				log_msg("%s has escaped!" % u.display_name)
	_check_end()
	if mission_time > 25.0 and not _help_auto_hidden:
		_help_auto_hidden = true
		show_help = false
	if autotest:
		_run_autotest()


func _check_end() -> void:
	var escaped := 0
	var pending := 0
	for u in roster:
		if u is Survivor:
			if u.escaped:
				escaped += 1
			elif u.alive and not u.captured:
				pending += 1
	if pending > 0 and tripod.is_active():
		return
	ended = true
	if escaped + pending > 0:
		result = "won"
		log_msg("Chapter complete.")
	else:
		result = "lost"
		log_msg("Everyone is lost.")
	get_tree().paused = true
	if autotest:
		_finish_autotest()


# ---------------------------------------------------------------- events

func log_msg(text: String) -> void:
	messages.append({"text": text, "t": mission_time})
	if messages.size() > 7:
		messages.pop_front()
	if autotest:
		print("[%6.1f] %s" % [mission_time, text])


func on_unit_died(u: Unit, why: String) -> void:
	selected.erase(u)
	log_msg("%s - %s." % [u.display_name, why])


func capture(u: Unit) -> void:
	u.captured = true
	u.in_cellar = false
	u.path.clear()
	u.selected = false
	u.visible = false
	u.process_mode = Node.PROCESS_MODE_DISABLED
	units.erase(u)
	selected.erase(u)
	log_msg("%s is thrown into the machine's cage!" % u.display_name)


func free_captives(pos: Vector2) -> void:
	var i := 0
	for u in tripod.captives:
		u.captured = false
		u.alert = 0.0
		u.position = pos + Vector2(-50, 0).rotated(tripod.facing.angle()) + Vector2(i * 14 - 14, 18)
		u.visible = true
		u.process_mode = Node.PROCESS_MODE_INHERIT
		units.append(u)
		log_msg("%s climbs out of the broken cage!" % u.display_name)
		i += 1
	tripod.captives.clear()


func on_tripod_down(why: String) -> void:
	free_captives(tripod.position)
	if why.contains("bacteria"):
		log_msg("The machine shudders, its shield gone... the Martian inside is dying!")
	else:
		log_msg("THE MACHINE FALLS! It has been %s!" % why)
	_add_blast(tripod.position, Color(1, 0.6, 0.2), 90.0, 1.2)


func make_noise(pos: Vector2) -> void:
	if tripod.is_active():
		tripod.hear(pos)


func spawn_projectile(kind: String, from: Vector2, to: Vector2, source: Node2D) -> void:
	var p := Projectile.new()
	p.kind = kind
	p.from = from
	p.to = to
	p.source = source
	p.main = self
	game.add_child(p)


func on_projectile_land(p: Projectile) -> void:
	if p.kind == "shell":
		_add_blast(p.to, Color(1, 0.55, 0.2), 34.0, 0.6)
		for u in units.duplicate():
			if u.alive and not u.in_cellar and u.position.distance_to(p.to) < 26.0:
				u.die("killed by our own shell")
		if tripod.is_active():
			tripod.on_shell(p.to, gun)
	else:
		var s := BlackSmoke.new()
		s.position = p.to
		game.add_child(s)
		smokes.append(s)


func heat_ray(from: Vector2, to: Vector2) -> void:
	for u in units.duplicate():
		if u.alive and u.can_be_seen() and u.position.distance_to(to) < 28.0:
			u.die("burned by the heat-ray")
	world.add_fire(to, 16.0, 22.0)
	_add_blast(to, Color(0.5, 1.0, 0.5), 30.0, 0.5)


func _add_blast(pos: Vector2, c: Color, size: float, life: float) -> void:
	var b := Blast.new()
	b.position = pos
	b.color = c
	b.size = size
	b.life = life
	game.add_child(b)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not started:
		if (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]) \
				or (event is InputEventMouseButton and event.pressed):
			start()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event.keycode)
		return
	if ended or get_tree().paused:
		return
	if event is InputEventMouseButton:
		var mp := get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = mp
				drag_end = mp
			elif dragging:
				dragging = false
				drag_end = mp
				_select_area(drag_start, drag_end, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			command(mp)
	elif event is InputEventMouseMotion and dragging:
		drag_end = get_global_mouse_position()


func _on_key(k: Key) -> void:
	match k:
		KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()
		KEY_M:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		KEY_F1, KEY_QUESTION:
			show_help = not show_help
		KEY_SPACE, KEY_P:
			if not ended:
				get_tree().paused = not get_tree().paused
		KEY_ESCAPE:
			_set_selection([])
		KEY_D:
			if gun in selected:
				gun.toggle_deploy()
		KEY_H:
			hide_selected()
		KEY_1, KEY_2, KEY_3, KEY_4:
			var i: int = k - KEY_1
			if i < roster.size() and roster[i] in units and roster[i].alive:
				_set_selection([roster[i]])
		KEY_A:
			var all: Array[Unit] = []
			for u in units:
				if u.alive:
					all.append(u)
			_set_selection(all)


func _set_selection(list: Array) -> void:
	for u in selected:
		u.selected = false
	selected.clear()
	for u in list:
		if u.alive and not u.escaped:
			selected.append(u)
			u.selected = true


func _select_area(a: Vector2, b: Vector2, add: bool) -> void:
	var picked: Array[Unit] = []
	if a.distance_to(b) < 6.0:
		var best: Unit = null
		var bd := 20.0
		for u in units:
			if u.alive and u.position.distance_to(b) < bd:
				bd = u.position.distance_to(b)
				best = u
		if best:
			picked.append(best)
	else:
		var r := Rect2(a, b - a).abs()
		for u in units:
			if u.alive and r.has_point(u.position):
				picked.append(u)
	if add:
		for u in selected:
			if not u in picked:
				picked.append(u)
	_set_selection(picked)


func command(p: Vector2) -> void:
	if selected.is_empty():
		return
	if gun in selected and gun.is_deployed():
		if gun.can_fire():
			if gun.fire_at(p):
				return
		elif selected.size() == 1:
			log_msg("The gun is still reloading.")
			return
	var cellar := world.nearest_cellar(p, 24.0)
	var movers: Array[Unit] = []
	for u in selected:
		if u.alive and not (u == gun and gun.is_deployed() and selected.size() > 1):
			movers.append(u)
	for i in movers.size():
		var u := movers[i]
		if u is Survivor and cellar != Vector2.INF:
			(u as Survivor).hide_at(cellar)
		else:
			var off := Vector2.ZERO
			if movers.size() > 1:
				off = Vector2.RIGHT.rotated(TAU * i / movers.size()) * 16.0
			u.order_move(p + off)


func hide_selected() -> void:
	for u in selected:
		if u is Survivor and u.alive:
			var c := world.nearest_cellar(u.position, 220.0)
			if c != Vector2.INF:
				(u as Survivor).hide_at(c)
			else:
				log_msg("No cellar near %s." % u.display_name)


# ---------------------------------------------------------------- automated smoke test
# Run: godot --headless --fixed-fps 60 -- --autotest

func _setup_autotest() -> void:
	var variant := "a"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest="):
			variant = arg.substr(11)
	if variant == "b":
		# gun stands and fights; everyone else hides
		_test_steps = [[0.3, func(): _set_selection([roster[1], roster[2], roster[3]]); hide_selected()],
			[0.4, func(): _set_selection([gun]); gun.toggle_deploy()]]
		for k in 40:
			_test_steps.append([3.0 + k * 2.5, func(): _set_selection([gun]); if gun.can_fire() and tripod.is_active(): command(tripod.position)])
		_test_steps.append([150.0, func(): _set_selection([roster[1], roster[2], roster[3]]); command(Vector2(160, 830))])
		_test_steps.append([330.0, func(): _finish_autotest()])
		return
	if variant == "d":
		# code-path test: shield overload, hull hits, being seen diving into a cellar, black smoke
		_test_steps = [
			[0.5, func(): _set_selection([roster[1]]); command(Vector2(470, 300))],
			[3.0, func(): _set_selection([roster[1]]); hide_selected()],
			[30.0, func(): tripod.on_shell(tripod.position, gun)],
			[30.5, func(): tripod.on_shell(tripod.position, gun)],
			[31.0, func(): tripod.on_shell(tripod.position, gun)],
			[33.0, func(): tripod.on_shell(tripod.position, gun)],
			[35.0, func(): tripod.on_shell(tripod.position, gun)],
			[60.0, func(): _finish_autotest()],
		]
		return
	if variant == "e":
		# capture: a survivor walks into the machine's path, then the machine is shot down
		_test_steps = [
			[0.5, func(): _set_selection([roster[1]]); command(Vector2(560, 280))],
			[30.0, func(): tripod.on_shell(tripod.position, gun)],
			[30.5, func(): tripod.on_shell(tripod.position, gun)],
			[31.0, func(): tripod.on_shell(tripod.position, gun)],
			[33.0, func(): tripod.on_shell(tripod.position, gun)],
			[35.0, func(): tripod.on_shell(tripod.position, gun)],
			[60.0, func(): _finish_autotest()],
		]
		return
	if variant == "c":
		# nobody does anything
		_test_steps = [[330.0, func(): _finish_autotest()]]
		return
	_test_steps = [
		[0.5, func(): _set_selection([roster[1], roster[2]]); command(Vector2(160, 830))],
		[0.6, func(): _set_selection([roster[3]]); hide_selected()],
		[0.7, func(): _set_selection([gun]); command(Vector2(420, 360))],
		[9.0, func(): _set_selection([gun]); gun.toggle_deploy()],
		[13.0, func(): _set_selection([gun]); command(tripod.position)],
		[19.0, func(): _set_selection([gun]); command(tripod.position)],
		[25.0, func(): _set_selection([gun]); command(tripod.position)],
		[40.0, func(): _set_selection([roster[3]]); command(Vector2(160, 830))],
		[240.0, func(): _finish_autotest()],
	]


func _run_autotest() -> void:
	while not _test_steps.is_empty() and mission_time >= _test_steps[0][0]:
		var step: Array = _test_steps.pop_front()
		(step[1] as Callable).call()


func _finish_autotest() -> void:
	print("--- autotest summary at %.1fs: result=%s tripod=%s hull=%d shield=%.0f sickness=%.2f" % [
		mission_time, result, tripod.status_text(), tripod.hull, tripod.shield, tripod.sickness])
	for u in roster:
		print("    %-22s %s" % [u.display_name, u.status_text()])
	get_tree().quit()


func _shoot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_shot_dir, n])
	print("screenshot ", n)
