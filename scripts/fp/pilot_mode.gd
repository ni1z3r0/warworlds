extends Node3D
## FIRST-PERSON MODE: THE FIGHTING-MACHINE
## You are the Martian. Stride over the village, silence the artillery
## batteries with the heat-ray and black smoke, and fill the cage on your back.
## But the air of Earth is slowly killing you...

const BATTERY_SPOTS := [Vector3(-95, 0, 45), Vector3(-25, 0, -95), Vector3(25, 0, 75), Vector3(-160, 0, -60), Vector3(100, 0, 105)]
const SPEED := 7.0
const STRIDE := 11.0

var world: Countryside3D
var machine: Tripod3D
var cam: Camera3D
var hud: Control
var batteries: Array[FieldGun3D] = []
var people: Array[Person3D] = []
var smokes: Array[Smoke3D] = []
var messages: Array[Dictionary] = []

var pitch := -0.15
var third_person := false
var shield := 100.0
var shield_broken := 0.0
var flicker := 0.0
var since_hit := 99.0
var hull := 100.0
var sickness := 0.0
var ray_energy := 100.0
var overheated := false
var firing := false
var smoke_cd := 0.0
var grab_target: Person3D = null
var grab_t := -1.0
var houses_burned := 0
var shake := 0.0
var time := 0.0
var ended := false
var result := ""
var paused := false
var show_help := true   # controls panel; F1 or H toggles
var _sick_msgs := 0
var _flicker_msg_t := -99.0

var autotest := false
var _test_move := Vector3.ZERO
var _test_fire := false
var _steps: Array = []
var _shot_dir := ""
var _shot_times: Array = []


func _ready() -> void:
	world = Countryside3D.new()
	add_child(world)

	machine = Tripod3D.new()
	machine.position = Vector3(140, 0, -95)
	machine.rotation.y = deg_to_rad(60)   # facing the village (west-ish)
	add_child(machine)

	cam = Camera3D.new()
	cam.fov = 78.0
	cam.far = 1200.0
	cam.top_level = true
	add_child(cam)

	for p in BATTERY_SPOTS:
		var g := FieldGun3D.new()
		g.position = p
		g.rotation.y = randf() * TAU
		add_child(g)
		g.add_crew(3)
		g.reload = randf_range(3.0, 7.0)
		batteries.append(g)

	for i in 34:
		var person := Person3D.new()
		person.world = world
		person.threat = machine
		var a := randf() * TAU
		var d := randf_range(10, 90)
		person.position = Vector3(-70 + cos(a) * d, 0, -30 + sin(a) * d)
		if not world.house_near(person.position, 8.0).is_empty():
			person.position += Vector3(10, 0, 10)
		add_child(person)
		people.append(person)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = load("res://scripts/fp/pilot_hud.gd").new()
	hud.mode = self
	layer.add_child(hud)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	log_msg("You stand over Horsell Common. The humans have brought up guns.")
	log_msg("Silence the five batteries. Their shells cannot pierce your shield... for long.")
	_parse_args()


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_update_camera(delta)
	if _shot_dir != "" and not _shot_times.is_empty() and time >= _shot_times[0]:
		_shoot(_shot_times.pop_front())
	if paused or ended:
		if ended and result == "lost":
			machine.collapse = minf(1.0, machine.collapse + delta * 0.45)
		return
	time += delta
	if autotest:
		_run_test()

	_move(delta)
	_heat_ray(delta)
	_grab(delta)
	_batteries(delta)
	_smoke(delta)
	_vitals(delta)
	machine.set_captives(machine.captives)


func _move(delta: float) -> void:
	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input.z -= 1
	if Input.is_key_pressed(KEY_S): input.z += 1
	if Input.is_key_pressed(KEY_A): input.x -= 1
	if Input.is_key_pressed(KEY_D): input.x += 1
	if autotest:
		input = _test_move
	if input.length() > 0.0:
		var spd := (STRIDE if Input.is_key_pressed(KEY_SHIFT) else SPEED) * (1.0 - 0.4 * sickness)
		var dir := machine.global_transform.basis * input.normalized()
		dir.y = 0.0
		machine.position += dir.normalized() * spd * delta
		machine.position = machine.position.clamp(Vector3(-380, 0, -380), Vector3(380, 0, 380))


func _update_camera(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	var jitter := Vector3(randf() - 0.5, randf() - 0.5, 0) * shake * 0.6
	machine.set_first_person(not third_person)
	if third_person:
		var back := -machine.forward()
		var target := machine.body_pos()
		var p := target + back * 40.0 + machine.forward().cross(Vector3.UP) * 14.0 + Vector3(0, 2.0 - pitch * 20.0, 0)
		cam.global_position = p + jitter
		cam.look_at(target + machine.forward() * 20.0 + Vector3(0, -6, 0), Vector3.UP)
	else:
		var b := machine.body.global_transform
		cam.global_position = b * Vector3(0, -1.0, -4.0) + jitter   # under the brim, between the eyes
		cam.global_basis = Basis.from_euler(Vector3(pitch + machine.body.rotation.x, machine.rotation.y, machine.body.rotation.z))


func _aim_point(max_dist: float) -> Vector3:
	var from := cam.global_position
	var dir := -cam.global_basis.z
	if third_person:
		from = machine.lens_pos()
		dir = (machine.forward() + Vector3(0, pitch, 0)).normalized()
	var hit := world.ray(from, from + dir * max_dist)
	return hit.position if not hit.is_empty() else from + dir * max_dist


func _heat_ray(delta: float) -> void:
	var want := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _test_fire
	if overheated and ray_energy > 40.0:
		overheated = false
	firing = want and not overheated and grab_t < 0.0
	if not firing:
		ray_energy = minf(100.0, ray_energy + 14.0 * delta)
		machine.beam_on = false
		machine.charge = maxf(0.0, machine.charge - delta * 3.0)
		return
	ray_energy -= 22.0 * delta
	if ray_energy <= 0.0:
		ray_energy = 0.0
		overheated = true
		log_msg("The heat-ray generator is exhausted. Let it recharge.")
	var target := _aim_point(450.0)
	var from := machine.ray_origin()
	machine.beam_on = true
	machine.beam_target = target
	machine.charge = 1.0
	for g in batteries:
		if g.alive and _seg_dist(from, target, g.global_position + Vector3(0, 1, 0)) < 4.5:
			g.heat += delta
			if g.heat > 0.6:
				g.wreck()
				world.explosion(g.global_position + Vector3(0, 1, 0), Color(1, 0.6, 0.2), 4.0)
				world.add_fire(g.global_position, 2.0, 30.0)
				log_msg("A battery is blasted to scrap. (%d left)" % _guns_left())
				_check_win()
	for p in people:
		if p.alive and _seg_dist(from, target, p.global_position + Vector3(0, 1, 0)) < 2.5:
			p.burn()
	var h := world.house_near(target, 7.0)
	if not h.is_empty() and not h.burning:
		h.heat += delta
		if h.heat > 1.0:
			world.ignite(h)
			houses_burned += 1
	if randf() < delta * 4.0:
		world.add_fire(target, 1.5, 6.0)


func _grab(delta: float) -> void:
	if grab_t < 0.0:
		machine.grab_t = -1.0
		return
	grab_t += delta / 1.6
	if not is_instance_valid(grab_target) or not grab_target.alive:
		grab_t = -1.0
		return
	if grab_t < 0.45:
		machine.grab_point = grab_target.global_position + Vector3(0, 1, 0)
		grab_target.speed = 0.0
	else:
		var cage_p := machine.cage.global_position
		var k := clampf((grab_t - 0.45) / 0.55, 0.0, 1.0)
		grab_target.global_position = grab_target.global_position.lerp(cage_p, k * 0.25)
		machine.grab_point = grab_target.global_position
	machine.grab_t = grab_t
	if grab_t >= 1.0:
		grab_target.queue_free()
		people.erase(grab_target)
		grab_target = null
		grab_t = -1.0
		machine.captives += 1
		log_msg("Another human for the cage. (%d / %d)" % [machine.captives, Tripod3D.CAGE_SIZE])


func try_grab() -> void:
	if grab_t >= 0.0 or ended:
		return
	if machine.captives >= Tripod3D.CAGE_SIZE:
		log_msg("The cage is full.")
		return
	var best: Person3D = null
	var bd := 26.0
	var c := machine.global_position
	for p in people:
		if p.alive:
			var d := Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length()
			if d < bd:
				bd = d
				best = p
	if best == null:
		log_msg("No human within reach of the tentacles.")
		return
	grab_target = best
	grab_t = 0.0


func fire_smoke() -> void:
	if smoke_cd > 0.0 or ended:
		return
	var target := _aim_point(260.0)
	var s := Shell3D.new()
	s.kind = "smoke"
	s.owner_mode = self
	s.source = machine
	add_child(s)
	s.global_position = machine.lens_pos() + Vector3(0, -2, 0)
	s.vel = Shell3D.launch_velocity(s.global_position, target, 1.6)
	smoke_cd = 14.0
	log_msg("Black smoke canister away.")


func _smoke(delta: float) -> void:
	smoke_cd = maxf(0.0, smoke_cd - delta)
	for i in range(smokes.size() - 1, -1, -1):
		if not is_instance_valid(smokes[i]):
			smokes.remove_at(i)
	for s in smokes:
		var r := s.radius()
		for g in batteries:
			if g.alive and not g.silenced and g.global_position.distance_to(s.global_position) < r:
				g.heat += delta * 0.6
				if g.heat > 1.5:
					g.silence()
					log_msg("The gunners choke in the black smoke. A battery falls silent. (%d left)" % _guns_left())
					_check_win()
		for p in people:
			if p.alive and p.global_position.distance_to(s.global_position) < r * 0.8 and randf() < delta * 0.5:
				p.burn()


func _batteries(delta: float) -> void:
	var target := machine.body_pos()
	for g in batteries:
		if not g.alive or g.silenced:
			continue
		g.aim_yaw_at(target)
		var d := g.global_position.distance_to(target)
		if d > 330.0 or g.reload > 0.0:
			continue
		var t := clampf(d / 110.0, 1.2, 3.2)
		var lead := Vector3.ZERO
		if machine.moving:
			lead = machine.forward() * SPEED * t * 0.6
		var aim := target + lead + Vector3(randf_range(-5, 5), randf_range(-4, 4), randf_range(-5, 5))
		var s := Shell3D.new()
		s.owner_mode = self
		s.source = g
		add_child(s)
		s.global_position = g.muzzle()
		s.vel = Shell3D.launch_velocity(s.global_position, aim, t)
		g.barrel_pivot.rotation.x = clampf(asin(clampf(s.vel.normalized().y, -1, 1)), -0.1, 0.8)
		g.flash()
		g.reload = randf_range(5.0, 8.0)


func _vitals(delta: float) -> void:
	since_hit += delta
	shield_broken = maxf(0.0, shield_broken - delta)
	flicker = maxf(0.0, flicker - delta)
	if shield_broken <= 0.0 and since_hit > 3.0:
		shield = minf(100.0, shield + 8.0 * delta)
	sickness = minf(1.0, sickness + delta / 480.0)
	if sickness > 0.15 and _sick_msgs == 0:
		_sick_msgs = 1
		log_msg("Something in the air of this world is poisoning you.")
	if sickness > 0.5 and _sick_msgs == 1:
		_sick_msgs = 2
		log_msg("Your strength is failing. The shield is unstable.")
	if sickness > 0.35 and flicker <= 0.0 and randf() < sickness * 0.1 * delta:
		flicker = randf_range(1.5, 3.0) * (0.5 + sickness)
		if time - _flicker_msg_t > 15.0:
			_flicker_msg_t = time
			log_msg("YOUR SHIELD FLICKERS!")
	machine.shield_strength = 0.0 if not shield_up() else 0.12
	if sickness >= 1.0:
		_lose("struck down by the smallest creatures on Earth")


func shield_up() -> bool:
	return shield_broken <= 0.0 and flicker <= 0.0


# ---------------------------------------------------------------- shells

func shell_probe(a: Vector3, b: Vector3, s: Shell3D) -> Dictionary:
	if s.kind == "shell" and _seg_dist(a, b, machine.body_pos()) < (9.0 if shield_up() else 5.5):
		return {"point": b, "what": machine}
	var hit := world.ray(a, b)
	if not hit.is_empty():
		return {"point": hit.position, "what": hit.collider}
	return {}


func shell_hit(s: Shell3D, hit: Dictionary) -> void:
	var p: Vector3 = hit.point
	if s.kind == "smoke":
		var sm := Smoke3D.new()
		sm.position = Vector3(p.x, 0.5, p.z)
		add_child(sm)
		smokes.append(sm)
		return
	if hit.what == machine and shield_up():
		world.explosion(p, Color(0.4, 1.0, 0.6), 1.2)
	else:
		world.explosion(p, Color(1, 0.55, 0.2), 3.0)
	if hit.what == machine:
		shake = 1.0
		since_hit = 0.0
		if shield_up():
			shield -= 22.0
			machine.shield_flash = 1.0
			if shield <= 0.0:
				shield = 0.0
				shield_broken = 6.0
				log_msg("YOUR SHIELD HAS FAILED! Get clear of the guns!")
		else:
			hull -= 12.0
			log_msg("A shell strikes your hull!")
			if hull <= 0.0:
				hull = 0.0
				_lose("brought down by the human guns")
	for p2 in people:
		if p2.alive and p2.global_position.distance_to(p) < 4.0:
			p2.burn()


# ---------------------------------------------------------------- end

func _guns_left() -> int:
	var n := 0
	for g in batteries:
		if g.alive and not g.silenced:
			n += 1
	return n


func _check_win() -> void:
	if _guns_left() == 0 and not ended:
		ended = true
		result = "won"
		log_msg("The guns are silent. The countryside is yours.")
		_end()


func _lose(why: String) -> void:
	if ended:
		return
	ended = true
	result = "lost"
	machine.beam_on = false
	log_msg("You are %s." % why)
	hud.set_meta("why", why)
	_end()


func _end() -> void:
	machine.beam_on = false
	if autotest:
		_finish_test()


func log_msg(t: String) -> void:
	messages.append({"text": t, "t": time})
	if messages.size() > 6:
		messages.pop_front()
	if autotest:
		print("[%6.1f] %s" % [time, t])


func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused:
		machine.rotation.y -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.2, 0.35)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not ended:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			paused = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			try_grab()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				paused = not paused
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
			KEY_F:
				fire_smoke()
			KEY_E:
				try_grab()
			KEY_V:
				third_person = not third_person
			KEY_ENTER, KEY_KP_ENTER:
				if ended and result == "won" and Progress.active:
					Progress.complete()
			KEY_R:
				get_tree().reload_current_scene()
			KEY_F1, KEY_H:
				show_help = not show_help
			KEY_M:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---------------------------------------------------------------- automated test
# godot --headless --fixed-fps 60 res://scenes/pilot.tscn -- --autotest

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--shots="):
			_shot_dir = a.substr(8)
		elif a.begins_with("--shot-times="):
			for v in a.substr(13).split(","):
				_shot_times.append(float(v))
	if autotest:
		_steps = [
			[0.5, func(): _test_move = Vector3(0, 0, -1)],
			[6.0, func(): _test_move = Vector3.ZERO; _face(batteries[1].global_position); _test_fire = true],
			[8.5, func(): _test_fire = false],
			[9.0, func(): _face(batteries[0].global_position); fire_smoke()],
			[10.0, func(): machine.position = _nearest_person_pos() + Vector3(8, 0, 8); try_grab()],
			[13.0, func(): machine.position = _nearest_person_pos() + Vector3(8, 0, 8); try_grab()],
			[16.0, func(): third_person = true],
			[17.0, func(): _face(batteries[2].global_position); _test_fire = true],
			[22.0, func(): _test_fire = false; _face(world.houses[0].pos); _test_fire = true],
			[25.0, func(): _test_fire = false; machine.position = batteries[3].global_position + Vector3(60, 0, 0); _face(batteries[3].global_position); _test_fire = true],
			[28.0, func(): _test_fire = false; machine.position = batteries[4].global_position + Vector3(0, 0, -70); _face(batteries[4].global_position); _test_fire = true],
			[32.0, func(): _test_fire = false],
			[70.0, func(): _finish_test()],
		]


func _face(p: Vector3) -> void:
	machine.turn_toward(p - machine.global_position, PI * 2)
	var flat := Vector2(p.x - machine.body_pos().x, p.z - machine.body_pos().z).length()
	pitch = atan2(p.y - machine.body_pos().y, flat)


func _nearest_person_pos() -> Vector3:
	for p in people:
		if p.alive:
			return p.global_position
	return machine.position


func _run_test() -> void:
	while not _steps.is_empty() and time >= _steps[0][0]:
		var st: Array = _steps.pop_front()
		(st[1] as Callable).call()


func _finish_test() -> void:
	print("--- pilot summary t=%.1f result=%s hull=%.0f shield=%.0f captives=%d guns_left=%d houses_burned=%d sickness=%.2f" % [
		time, result, hull, shield, machine.captives, _guns_left(), houses_burned, sickness])
	if _shot_dir == "":
		get_tree().quit()


func _shoot(t: float) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/pilot_%02d.png" % [_shot_dir, int(t)])
	print("screenshot pilot ", t)
