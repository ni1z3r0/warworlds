extends Node3D
## FIRST-PERSON MODE: THE ARTILLERY
## You are a gunner of the Royal Horse Artillery. Your crews are dead. A
## fighting-machine stalks the village with people in its cage. Move between
## the abandoned guns, stay out of its sight, and bring it down.
##
## Same rules as the strategy game: shells burst on its shield; two hits
## overload it for a few seconds; three hits on the hull bring it down. And
## the bacteria of Earth are slowly killing the Martian inside.

enum S { PATROL, INVESTIGATE, SEARCH, HUNT, CHARGE, SWEEP, GRAB, COOLDOWN, DYING, DEAD }

const GUN_SPOTS := [Vector3(-55, 0, 32), Vector3(10, 0, -62), Vector3(-22, 0, 100)]
const WAYPOINTS := [Vector3(70, 0, -70), Vector3(-10, 0, -45), Vector3(-90, 0, -15), Vector3(-75, 0, 55), Vector3(15, 0, 70), Vector3(80, 0, 15)]
const MUZZLE_V := 170.0
const RELOAD := 4.0
const CHARGE_TIME := 2.0

var world: Countryside3D
var machine: Tripod3D
var player: CharacterBody3D
var cam: Camera3D
var hud: Control
var guns: Array[FieldGun3D] = []
var people: Array[Person3D] = []
var smokes: Array[Smoke3D] = []
var messages: Array[Dictionary] = []
var path_mesh: MeshInstance3D
var impact_marker: MeshInstance3D

# player
var hp := 100.0
var crouched := false
var sprinting := false
var manning: FieldGun3D = null
var near_gun: FieldGun3D = null
var on_target := false
var look_pitch := 0.0

# the machine
var state: S = S.PATROL
var goal := Vector3.ZERO
var wp := 0
var awareness := 0.0
var seen := false
var last_known := Vector3.ZERO
var lost_t := 0.0
var charge := 0.0
var cooldown := 0.0
var search_t := 0.0
var stagger := 0.0
var beam_t := 0.0
var sweep_cd := 12.0
var sweep_house: Dictionary = {}
var smoke_cd := 10.0
var grab_target: Person3D = null
var grab_t := 0.0
var grab_cd := 4.0
var shield := 100.0
var shield_broken := 0.0
var flicker := 0.0
var since_hit := 99.0
var hull := 3
var sickness := 0.0
var dying_t := 0.0
var death_cause := ""

var time := 0.0
var ended := false
var result := ""
var why := ""
var paused := false
var show_help := true   # controls panel; F1 or H toggles
var _sick_warned := false
var _flicker_msg_t := -99.0

var autotest := false
var _steps: Array = []
var _shot_dir := ""
var _shot_times: Array = []


func _ready() -> void:
	world = Countryside3D.new()
	add_child(world)

	for p in GUN_SPOTS:
		var g := FieldGun3D.new()
		g.position = p
		add_child(g)
		guns.append(g)
	guns[0].rotation.y = deg_to_rad(-30)
	guns[1].rotation.y = deg_to_rad(-120)
	guns[2].rotation.y = deg_to_rad(-60)

	machine = Tripod3D.new()
	machine.position = Countryside3D.PIT + Vector3(-25, 0, 20)
	machine.rotation.y = deg_to_rad(60)
	add_child(machine)
	machine.set_captives(2)

	for i in 16:
		var person := Person3D.new()
		person.world = world
		person.threat = machine
		var a := randf() * TAU
		person.position = Vector3(-30 + cos(a) * randf_range(10, 80), 0, -20 + sin(a) * randf_range(10, 70))
		add_child(person)
		people.append(person)

	player = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	player.add_child(cs)
	player.position = Vector3(-50, 0.2, 40)
	player.rotation.y = deg_to_rad(-46)   # facing the pit
	add_child(player)
	cam = Camera3D.new()
	cam.position = Vector3(0, 1.6, 0)
	cam.fov = 75.0
	cam.far = 1200.0
	player.add_child(cam)

	path_mesh = MeshInstance3D.new()
	path_mesh.mesh = ImmediateMesh.new()
	path_mesh.material_override = Tripod3D._emit(Color(1.0, 0.8, 0.4), 2.0)
	path_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(path_mesh)
	impact_marker = MeshInstance3D.new()
	impact_marker.mesh = Tripod3D._sphere(1.2)
	impact_marker.material_override = Tripod3D._emit(Color(1.0, 0.8, 0.4), 3.0)
	add_child(impact_marker)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = load("res://scripts/fp/soldier_hud.gd").new()
	hud.mode = self
	layer.add_child(hud)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	log_msg("Your battery is gone. Two people are in the machine's cage.")
	log_msg("Find an abandoned gun. Bring the machine down.")
	_parse_args()


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if _shot_dir != "" and not _shot_times.is_empty() and time >= _shot_times[0]:
		_shoot(_shot_times.pop_front())
	_update_gun_view()
	if paused:
		return
	if state == S.DYING:
		dying_t += delta
		machine.collapse = minf(1.0, dying_t / 3.0)
		if dying_t > 3.0 and state != S.DEAD:
			state = S.DEAD
			world.explosion(machine.body_pos(), Color(1, 0.6, 0.2), 10.0)
			world.add_fire(machine.body_pos(), 6.0, -1.0)
	if ended:
		return
	time += delta
	if autotest:
		_run_test()
	_machine(delta)
	_hazards(delta)
	near_gun = null
	if manning == null:
		for g in guns:
			if g.global_position.distance_to(player.global_position) < 4.0:
				near_gun = g


func _physics_process(delta: float) -> void:
	if paused or ended or manning != null:
		return
	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input.z -= 1
	if Input.is_key_pressed(KEY_S): input.z += 1
	if Input.is_key_pressed(KEY_A): input.x -= 1
	if Input.is_key_pressed(KEY_D): input.x += 1
	sprinting = Input.is_key_pressed(KEY_SHIFT) and not crouched and input.length() > 0.0
	var spd := 2.4 if crouched else (7.5 if sprinting else 4.5)
	var dir := player.global_transform.basis * input.normalized() if input.length() > 0.0 else Vector3.ZERO
	player.velocity.x = dir.x * spd
	player.velocity.z = dir.z * spd
	if not player.is_on_floor():
		player.velocity.y -= 9.8 * delta
	elif Input.is_key_pressed(KEY_SPACE) and not crouched:
		player.velocity.y = 4.5
	player.move_and_slide()
	cam.position.y = lerpf(cam.position.y, 1.0 if crouched else 1.6, delta * 8.0)


# ---------------------------------------------------------------- the gun

func man_gun(g: FieldGun3D) -> void:
	manning = g
	cam.top_level = true
	log_msg("You take the gun. Mouse to traverse and elevate, click to fire, E to leave.")


func leave_gun() -> void:
	if manning == null:
		return
	player.global_position = manning.global_transform * Vector3(0, 0.2, 3.0)
	manning = null
	cam.top_level = false
	cam.position = Vector3(0, 1.6, 0)
	cam.rotation = Vector3(look_pitch, 0, 0)
	path_mesh.visible = false
	impact_marker.visible = false


func _update_gun_view() -> void:
	if manning == null:
		path_mesh.visible = false
		impact_marker.visible = false
		return
	var sight := manning.barrel_pivot.global_transform * Vector3(0.0, 0.85, 0.5)
	cam.global_position = sight
	cam.global_basis = manning.barrel_pivot.global_basis
	_draw_trajectory()


func fire_gun() -> void:
	var g := manning
	if g == null or g.reload > 0.0 or ended:
		return
	var s := Shell3D.new()
	s.owner_mode = self
	s.source = g
	add_child(s)
	s.global_position = g.muzzle()
	s.vel = g.barrel_dir() * MUZZLE_V
	g.flash()
	g.reload = RELOAD
	world.explosion(g.muzzle(), Color(1, 0.7, 0.3), 1.0)
	hear(g.global_position)


func _simulate(from: Vector3, v: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var p := from
	var dt := 0.05
	on_target = false
	for i in 120:
		pts.append(p)
		var np := p + v * dt
		v += Shell3D.G * dt
		if state != S.DEAD and state != S.DYING and _seg_dist(p, np, machine.body_pos()) < 9.0:
			on_target = true
			pts.append(np)
			break
		if np.y <= 0.0:
			pts.append(np)
			break
		p = np
	return pts


func _draw_trajectory() -> void:
	var pts := _simulate(manning.muzzle(), manning.barrel_dir() * MUZZLE_V)
	var im := path_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(2, pts.size() - 1, 2):
		im.surface_add_vertex(pts[i])
		im.surface_add_vertex(pts[i + 1])
	im.surface_end()
	path_mesh.visible = true
	impact_marker.visible = true
	impact_marker.global_position = pts[pts.size() - 1]
	(impact_marker.material_override as StandardMaterial3D).emission = Color(1, 0.25, 0.15) if on_target else Color(1, 0.8, 0.4)


# ---------------------------------------------------------------- the machine

func machine_active() -> bool:
	return state != S.DYING and state != S.DEAD


func shield_up() -> bool:
	return machine_active() and shield_broken <= 0.0 and flicker <= 0.0


func status_text() -> String:
	match state:
		S.PATROL: return "Patrolling"
		S.INVESTIGATE: return "Investigating"
		S.SEARCH: return "Searching"
		S.HUNT: return "HUNTING YOU"
		S.CHARGE: return "CHARGING HEAT-RAY!"
		S.SWEEP: return "Burning the village"
		S.GRAB: return "Seizing a civilian"
		S.COOLDOWN: return "Heat-ray recharging"
		S.DYING: return "COLLAPSING"
		S.DEAD: return "DESTROYED"
	return ""


func _machine(delta: float) -> void:
	if not machine_active():
		machine.beam_on = false
		machine.charge = 0.0
		return
	sickness = minf(1.0, sickness + delta / 300.0)
	since_hit += delta
	shield_broken = maxf(0.0, shield_broken - delta)
	flicker = maxf(0.0, flicker - delta)
	smoke_cd -= delta
	grab_cd -= delta
	if shield_broken <= 0.0 and since_hit > 5.0:
		shield = minf(100.0, shield + 10.0 * delta)
	if sickness > 0.3 and not _sick_warned:
		_sick_warned = true
		log_msg("The machine lurches. Something is wrong with it...")
	if sickness > 0.35 and flicker <= 0.0 and randf() < sickness * 0.12 * delta:
		flicker = randf_range(1.5, 3.5) * (0.5 + sickness)
		if time - _flicker_msg_t > 15.0:
			_flicker_msg_t = time
			log_msg("Its shield is FLICKERING. Fire now!")
	machine.shield_strength = 0.14 if shield_up() else (0.12 * randf() if flicker > 0.0 or shield_broken > 0.0 else 0.0)
	if sickness >= 1.0:
		_machine_down("struck down by Earth's bacteria")
		return

	beam_t = maxf(0.0, beam_t - delta)
	machine.beam_on = beam_t > 0.0
	if stagger > 0.0:
		stagger -= delta
		return

	_perceive(delta)
	var spd := 1.0 - 0.45 * sickness
	match state:
		S.PATROL:
			if _walk(WAYPOINTS[wp], 4.5 * spd, delta):
				wp = (wp + 1) % WAYPOINTS.size()
			sweep_cd -= delta
			if sweep_cd <= 0.0:
				_start_sweep()
			_try_grab_civilian()
		S.INVESTIGATE:
			if _walk(goal, 6.5 * spd, delta):
				state = S.SEARCH
				search_t = 4.0
			_try_grab_civilian()
		S.SEARCH:
			machine.rotation.y += 0.7 * delta
			search_t -= delta
			if search_t <= 0.0:
				_end_search()
		S.HUNT:
			if seen:
				last_known = player.global_position
				lost_t = 0.0
			else:
				lost_t += delta
			if _walk(last_known, 6.0 * spd, delta) or lost_t > 7.0:
				state = S.SEARCH
				search_t = 3.5
		S.CHARGE:
			if not seen:
				state = S.HUNT
				lost_t = 0.0
				machine.charge = 0.0
			else:
				last_known = player.global_position
				machine.turn_toward(player.global_position - machine.global_position, delta * 1.5)
				charge += delta
				machine.charge = charge / CHARGE_TIME
				if charge >= CHARGE_TIME:
					_fire_at(player.global_position + Vector3(0, 1, 0))
					_kill_player("burned to ash by the heat-ray")
		S.SWEEP:
			var hp_: Vector3 = sweep_house.pos
			machine.turn_toward(hp_ - machine.global_position, delta * 1.5)
			charge += delta
			machine.charge = charge
			if charge >= 1.0:
				_fire_at(hp_ + Vector3(0, 4, 0))
				world.ignite(sweep_house)
		S.GRAB:
			_grab_step(delta)
		S.COOLDOWN:
			cooldown -= delta
			machine.charge = maxf(0.0, machine.charge - delta * 2.0)
			if cooldown <= 0.0:
				state = S.HUNT if awareness > 0.5 else S.PATROL
				lost_t = 0.0


func _walk(p: Vector3, spd: float, delta: float) -> bool:
	var d := p - machine.global_position
	d.y = 0.0
	if d.length() < 6.0:
		return true
	var diff := machine.turn_toward(d, 0.9 * delta)
	if absf(diff) < 0.6:
		machine.position += machine.forward() * spd * delta
	return false


func _perceive(delta: float) -> void:
	seen = false
	if manning == null and not player.is_inside_tree():
		return
	var eye := cam.global_position
	var to := eye - machine.lens_pos()
	var flat := Vector3(to.x, 0, to.z)
	var d := flat.length()
	var rng := 190.0 * (0.65 if crouched else 1.0)
	if manning != null:
		rng = 160.0   # the gun's shield plate hides you
	if d < rng and (d < 30.0 or absf(machine.forward().signed_angle_to(flat.normalized(), Vector3.UP)) < deg_to_rad(60)):
		var hit := world.ray(machine.lens_pos(), eye, [player.get_rid()])
		seen = hit.is_empty()
	if seen:
		var rate := lerpf(2.4, 0.45, clampf(d / rng, 0.0, 1.0))
		if sprinting:
			rate *= 1.4
		if crouched:
			rate *= 0.5
		awareness = minf(1.0, awareness + rate * delta)
	else:
		awareness = maxf(0.0, awareness - 0.25 * delta)
	var free := state == S.PATROL or state == S.INVESTIGATE or state == S.SEARCH or state == S.HUNT
	if seen and awareness >= 1.0 and free:
		state = S.CHARGE
		charge = 0.0
		log_msg("IT HAS SEEN YOU! Get out of its sight!")
	elif seen and awareness > 0.35 and (state == S.PATROL or state == S.SEARCH):
		goal = player.global_position
		state = S.INVESTIGATE


func hear(p: Vector3) -> void:
	if not machine_active():
		return
	if state == S.PATROL or state == S.SEARCH or state == S.INVESTIGATE or state == S.SWEEP:
		goal = p
		state = S.INVESTIGATE
		machine.charge = 0.0
	elif state == S.HUNT:
		last_known = p


func _start_sweep() -> void:
	sweep_cd = randf_range(12.0, 20.0)
	var best := {}
	for h in world.houses:
		var d := machine.global_position.distance_to(h.pos)
		if not h.burning and d < 140.0 and d > 30.0:
			best = h
			break
	if best.is_empty():
		return
	sweep_house = best
	state = S.SWEEP
	charge = 0.0


func _fire_at(p: Vector3) -> void:
	machine.beam_target = p
	beam_t = 0.6
	machine.beam_on = true
	charge = 0.0
	machine.charge = 1.0
	state = S.COOLDOWN
	cooldown = 2.0
	world.add_fire(Vector3(p.x, 0, p.z), 2.0, 12.0)


func _try_grab_civilian() -> void:
	if grab_cd > 0.0 or machine.captives >= Tripod3D.CAGE_SIZE:
		return
	for p in people:
		if p.alive and Vector2(p.global_position.x - machine.global_position.x, p.global_position.z - machine.global_position.z).length() < 22.0:
			grab_target = p
			grab_t = 0.0
			state = S.GRAB
			return


func _grab_step(delta: float) -> void:
	grab_t += delta / 1.8
	if not is_instance_valid(grab_target) or not grab_target.alive:
		state = S.PATROL
		machine.grab_t = -1.0
		return
	if grab_t < 0.45:
		machine.grab_point = grab_target.global_position + Vector3(0, 1, 0)
		grab_target.speed = 0.0
	else:
		grab_target.global_position = grab_target.global_position.lerp(machine.cage.global_position, 0.06)
		machine.grab_point = grab_target.global_position
	machine.grab_t = grab_t
	if grab_t >= 1.0:
		people.erase(grab_target)
		grab_target.queue_free()
		grab_target = null
		machine.grab_t = -1.0
		machine.set_captives(machine.captives + 1)
		log_msg("The machine snatches up another person. (%d in the cage)" % machine.captives)
		grab_cd = 15.0
		state = S.PATROL


func _end_search() -> void:
	if smoke_cd <= 0.0 and last_known != Vector3.ZERO:
		var s := Shell3D.new()
		s.kind = "smoke"
		s.owner_mode = self
		s.source = machine
		add_child(s)
		s.global_position = machine.lens_pos() + Vector3(0, -3, 0)
		s.vel = Shell3D.launch_velocity(s.global_position, last_known, 1.6)
		smoke_cd = 22.0
		log_msg("It fires a canister of BLACK SMOKE where it last saw you!")
	state = S.PATROL


func _machine_down(why_: String) -> void:
	state = S.DYING
	death_cause = why_
	dying_t = 0.0
	machine.beam_on = false
	machine.shield_strength = 0.0
	if why_.contains("bacteria"):
		log_msg("The machine shudders and sags... the Martian inside is dying!")
	else:
		log_msg("THE MACHINE IS DOWN! It has been %s!" % why_)
	if machine.captives > 0:
		log_msg("%d people climb out of the broken cage." % machine.captives)
	ended = true
	result = "won"
	if autotest:
		_finish_test()


# ---------------------------------------------------------------- shells, smoke, damage

func shell_probe(a: Vector3, b: Vector3, s: Shell3D) -> Dictionary:
	if s.kind == "shell" and machine_active() and _seg_dist(a, b, machine.body_pos()) < (9.0 if shield_up() else 6.0):
		return {"point": b, "what": machine}
	var hit := world.ray(a, b, [player.get_rid()])
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
	world.explosion(p, Color(1, 0.55, 0.2), 3.5)
	var pd := p.distance_to(player.global_position + Vector3(0, 1, 0))
	if pd < 9.0:
		_damage((9.0 - pd) * 14.0, "killed by the blast of your own shell")
	for c in people:
		if c.alive and c.global_position.distance_to(p) < 5.0:
			c.burn()
	if hit.what == machine:
		_machine_hit()
	elif machine_active():
		hear(s.source.global_position if s.source else p)


func _machine_hit() -> void:
	since_hit = 0.0
	stagger = 1.0
	if shield_up():
		shield -= 50.0
		machine.shield_flash = 1.0
		if shield <= 0.0:
			shield = 0.0
			shield_broken = 7.0
			log_msg("ITS SHIELD OVERLOADS! You have seconds. Fire again!")
		else:
			log_msg("The shell bursts against its shield.")
	else:
		hull -= 1
		stagger = 1.8
		if hull > 0:
			log_msg("DIRECT HIT ON THE HULL! (%d more)" % hull)
		else:
			_machine_down("brought down by your gun")
			return
	if manning != null:
		last_known = manning.global_position
		awareness = maxf(awareness, 0.6)
		state = S.HUNT
		lost_t = 0.0


func _hazards(delta: float) -> void:
	for i in range(smokes.size() - 1, -1, -1):
		if not is_instance_valid(smokes[i]):
			smokes.remove_at(i)
	for s in smokes:
		var r := s.radius() * 0.8
		var pp := cam.global_position
		if pp.distance_to(s.global_position) < r:
			_damage(22.0 * delta, "choked by the black smoke")
		for c in people:
			if c.alive and c.global_position.distance_to(s.global_position) < r and randf() < delta * 0.4:
				c.burn()


func _damage(amount: float, how: String) -> void:
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		_kill_player(how)


func _kill_player(how: String) -> void:
	if ended:
		return
	ended = true
	result = "lost"
	why = how
	log_msg("You were %s." % how)
	if autotest:
		_finish_test()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused and not ended:
		if manning != null:
			manning.carriage.rotation.y -= event.relative.x * 0.0012
			manning.barrel_pivot.rotation.x = clampf(manning.barrel_pivot.rotation.x - event.relative.y * 0.0008, -0.05, 0.6)
		else:
			player.rotation.y -= event.relative.x * 0.0022
			look_pitch = clampf(look_pitch - event.relative.y * 0.0022, -1.4, 1.4)
			cam.rotation.x = look_pitch
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not ended:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			paused = false
		elif event.button_index == MOUSE_BUTTON_LEFT and manning != null:
			fire_gun()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				if manning != null:
					leave_gun()
				elif near_gun != null:
					man_gun(near_gun)
			KEY_C, KEY_CTRL:
				crouched = not crouched
			KEY_ESCAPE:
				paused = not paused
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
			KEY_R:
				get_tree().reload_current_scene()
			KEY_F1, KEY_H:
				show_help = not show_help
			KEY_M:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---------------------------------------------------------------- helpers

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


# ---------------------------------------------------------------- automated test
# godot --headless --fixed-fps 60 res://scenes/soldier.tscn -- --autotest

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
		crouched = true
		_steps = [[0.5, func(): player.global_position = guns[0].global_position + Vector3(0, 0.2, 3); man_gun(guns[0])]]
		for k in 40:
			_steps.append([2.0 + k * 4.2, func(): _test_aim_and_fire()])
		_steps.append([200.0, func(): _finish_test()])


## Test-only gunner: traverse onto the machine and find an elevation that hits.
func _test_aim_and_fire() -> void:
	if manning == null or not machine_active():
		return
	manning.aim_yaw_at(machine.body_pos())
	var best := 0.0
	var best_d := INF
	for i in 60:
		var el := -0.05 + i * 0.011
		manning.barrel_pivot.rotation.x = el
		var pts := _simulate(manning.muzzle(), manning.barrel_dir() * MUZZLE_V)
		var dmin := INF
		for k in range(pts.size() - 1):
			dmin = minf(dmin, _seg_dist(pts[k], pts[k + 1], machine.body_pos()))
		if dmin < best_d:
			best_d = dmin
			best = el
	manning.barrel_pivot.rotation.x = best
	fire_gun()


func _run_test() -> void:
	while not _steps.is_empty() and time >= _steps[0][0]:
		var st: Array = _steps.pop_front()
		(st[1] as Callable).call()


func _finish_test() -> void:
	print("--- soldier summary t=%.1f result=%s why=%s machine=%s hull=%d shield=%.0f sickness=%.2f captives=%d hp=%.0f" % [
		time, result, why, status_text(), hull, shield, sickness, machine.captives, hp])
	if _shot_dir == "":
		get_tree().quit()


func _shoot(t: float) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/soldier_%02d.png" % [_shot_dir, int(t)])
	print("screenshot soldier ", t)
