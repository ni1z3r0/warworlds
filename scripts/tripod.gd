class_name Tripod
extends Node2D
## The Martian fighting-machine. An original design built from Wells' text:
## a towering three-legged engine with a cowled body, hanging metal tentacles,
## a heat-ray projector and black-smoke canisters.
##
## Like Wells' machines it carries a metal carrier-cage on its back and
## seizes people with its tentacles when they are close enough to grab.
##
## Protected by a shield (a mechanic of our own). Shells only hurt it while the
## shield is down: overloaded by hits, or failing as Earth's bacteria sicken
## the Martian inside.

enum S { PATROL, INVESTIGATE, SEARCH, HUNT, CHARGE, GRAB, COOLDOWN, DYING, DEAD }

const HEIGHT := 112.0
const SCALE := 1.6
const REACH := 84.0
const CHARGE_TIME := 1.3
const SHIELD_MAX := 100.0
const GRAB_RANGE := 125.0
const GRAB_TIME := 1.1
const CAGE_SIZE := 4
const BODY := [Vector2(36, 0), Vector2(24, -14), Vector2(4, -22), Vector2(-20, -19),
	Vector2(-36, -6), Vector2(-36, 6), Vector2(-20, 19), Vector2(4, 22), Vector2(24, 14)]

var main: Node
var world: World
var state: S = S.PATROL
var facing := Vector2.LEFT
var base_speed := 46.0
var goal := Vector2.ZERO
var waypoints: Array[Vector2] = []
var wp_i := 0
var view_range := 340.0
var fov := deg_to_rad(84.0)

var shield := SHIELD_MAX
var shield_broken := 0.0
var flicker := 0.0
var shield_flash := 0.0
var hull := 3
var sickness := 0.0
var sick_rate := 1.0 / 300.0   # fully sick after five minutes
var sick_warned := false
var flicker_msg_t := -99.0
var smoke_mark := Vector2.INF   # a cellar it saw someone dive into

var target: Unit = null
var last_known := Vector2.ZERO
var lost_t := 0.0
var charge := 0.0
var cooldown := 0.0
var stagger := 0.0
var search_t := 0.0
var since_hit := 99.0
var beam_t := 0.0
var beam_to := Vector2.ZERO
var smoke_cd := 8.0
var awareness := {}
var dying_t := 0.0
var death_cause := ""
var captives: Array[Unit] = []
var grab_t := 0.0
var _t := 0.0

var feet: Array[Vector2] = []
var foot_from: Array[Vector2] = []
var foot_to: Array[Vector2] = []
var lift: Array[float] = [0.0, 0.0, 0.0]
var step_i := -1
var step_t := 0.0


func _ready() -> void:
	z_index = 20
	for i in 3:
		var f := _ideal_foot(i)
		feet.append(f)
		foot_from.append(f)
		foot_to.append(f)


func _ideal_foot(i: int) -> Vector2:
	return position + facing.rotated(PI / 3.0 + i * TAU / 3.0) * REACH


func lens_global() -> Vector2:
	return position + Vector2(0, -HEIGHT) + facing * 30.0 * SCALE * Vector2(1, 0.78)


func shield_up() -> bool:
	return state != S.DYING and state != S.DEAD and shield_broken <= 0.0 and flicker <= 0.0


func is_active() -> bool:
	return state != S.DYING and state != S.DEAD


func status_text() -> String:
	match state:
		S.PATROL:
			return "Patrolling"
		S.INVESTIGATE:
			return "Investigating a disturbance"
		S.SEARCH:
			return "Searching..."
		S.HUNT:
			return "HUNTING"
		S.CHARGE:
			return "CHARGING HEAT-RAY!"
		S.GRAB:
			return "SEIZING SOMEONE!"
		S.COOLDOWN:
			return "Heat-ray recharging"
		S.DYING:
			return "COLLAPSING"
		S.DEAD:
			return "DESTROYED"
	return ""


# ---------------------------------------------------------------- simulation

func _process(delta: float) -> void:
	_t += delta
	beam_t = maxf(0.0, beam_t - delta)
	shield_flash = maxf(0.0, shield_flash - delta * 2.0)
	if state == S.DEAD:
		queue_redraw()
		return
	if state == S.DYING:
		dying_t += delta
		if dying_t >= 2.4:
			state = S.DEAD
			world.add_fire(position + Vector2(10, 6), 22.0, -1.0)
		queue_redraw()
		return

	sickness = minf(1.0, sickness + sick_rate * delta)
	since_hit += delta
	smoke_cd -= delta
	shield_broken = maxf(0.0, shield_broken - delta)
	flicker = maxf(0.0, flicker - delta)
	if shield_broken <= 0.0 and since_hit > 3.0:
		shield = minf(SHIELD_MAX, shield + 10.0 * delta)
	if sickness > 0.3 and not sick_warned:
		sick_warned = true
		main.log_msg("The machine moves sluggishly. Something is wrong with it...")
	if sickness > 0.35 and flicker <= 0.0 and randf() < sickness * 0.12 * delta:
		flicker = randf_range(1.5, 3.5) * (0.5 + sickness)
		if _t - flicker_msg_t > 15.0:
			flicker_msg_t = _t
			main.log_msg("The machine's shield is FLICKERING. Fire now!")
	if sickness >= 1.0:
		_die("struck down by Earth's bacteria")
		return

	if stagger > 0.0:
		stagger -= delta
		_update_legs(delta)
		queue_redraw()
		return

	_perceive(delta)
	match state:
		S.PATROL:
			if _move_toward(waypoints[wp_i], delta, 1.0):
				wp_i = (wp_i + 1) % waypoints.size()
		S.INVESTIGATE:
			if _move_toward(goal, delta, 1.25):
				state = S.SEARCH
				search_t = 4.0
		S.SEARCH:
			facing = facing.rotated(1.1 * delta)
			search_t -= delta
			if search_t <= 0.0:
				_end_search()
		S.HUNT:
			if _valid_target() and _can_see(target):
				last_known = target.position
				lost_t = 0.0
			else:
				lost_t += delta
			if _move_toward(last_known, delta, 1.3) or lost_t > 6.0:
				state = S.SEARCH
				search_t = 3.5
		S.CHARGE:
			if not _valid_target() or not _can_see(target):
				state = S.HUNT
				charge = 0.0
				lost_t = 0.0
			elif _can_grab(target):
				state = S.GRAB
				grab_t = 0.0
				charge = 0.0
				main.log_msg("The machine reaches for %s with its tentacles!" % target.display_name)
			else:
				last_known = target.position
				_turn_toward(target.position - position, delta * 2.0)
				charge += delta
				if charge >= CHARGE_TIME:
					_fire_ray()
		S.GRAB:
			if not _valid_target() or position.distance_to(target.position) > GRAB_RANGE + 50.0:
				if _valid_target():
					main.log_msg("%s tears free of the tentacles!" % target.display_name)
				state = S.HUNT
				lost_t = 0.0
			else:
				last_known = target.position
				_turn_toward(target.position - position, delta * 2.0)
				grab_t += delta
				if grab_t >= GRAB_TIME:
					captives.append(target)
					main.capture(target)
					target = null
					state = S.COOLDOWN
					cooldown = 1.2
		S.COOLDOWN:
			cooldown -= delta
			if cooldown <= 0.0:
				if _valid_target() and _can_see(target):
					state = S.CHARGE
					charge = 0.4
				elif _valid_target():
					state = S.HUNT
					lost_t = 0.0
				else:
					state = S.SEARCH
					search_t = 3.0
	_update_legs(delta)
	queue_redraw()


func _can_grab(u: Unit) -> bool:
	return u is Survivor and captives.size() < CAGE_SIZE and position.distance_to(u.position) < GRAB_RANGE


func _valid_target() -> bool:
	return target != null and is_instance_valid(target) and target.can_be_seen()


func _can_see(u: Unit) -> bool:
	if not u.can_be_seen():
		return false
	var to := u.position - position
	var d := to.length()
	var r := 110.0 if world.in_woods(u.position) else view_range
	if d > r:
		return false
	if d > 70.0 and absf(facing.angle_to(to)) > fov * 0.5:
		return false
	return world.has_los(position, u.position)


func _perceive(delta: float) -> void:
	var spotted: Unit = null
	var suspect: Unit = null
	var best_a := 0.0
	for u: Unit in main.units:
		var a: float = awareness.get(u, 0.0)
		if _can_see(u):
			var d := position.distance_to(u.position)
			var rate := lerpf(3.5, 0.8, clampf(d / view_range, 0.0, 1.0))
			if u is FieldGun:
				rate *= 1.5   # horses and a gun are hard to miss
			if u.moving:
				rate *= 1.3
			a = minf(1.0, a + rate * delta)
			if a >= 1.0:
				spotted = u
			elif a > best_a:
				best_a = a
				suspect = u
		else:
			a = maxf(0.0, a - 0.3 * delta)
		awareness[u] = a
		u.alert = a
	var free := state == S.PATROL or state == S.INVESTIGATE or state == S.SEARCH or state == S.HUNT
	if spotted and free:
		if target != spotted or state != S.HUNT:
			main.log_msg("The machine has seen %s!" % spotted.display_name)
		target = spotted
		state = S.CHARGE
		charge = 0.0
	elif suspect and best_a > 0.3 and (state == S.PATROL or state == S.SEARCH):
		goal = suspect.position
		state = S.INVESTIGATE


## Called when a survivor reaches a cellar. If the machine was close to
## spotting them, it saw where they went.
func saw_hide(u: Unit) -> void:
	if is_active() and awareness.get(u, 0.0) > 0.25:
		smoke_mark = u.position
		goal = u.position
		if state == S.PATROL or state == S.SEARCH:
			state = S.INVESTIGATE
		main.log_msg("The machine saw %s go to ground..." % u.display_name)


func _end_search() -> void:
	if smoke_cd <= 0.0:
		var spot := smoke_mark
		if spot == Vector2.INF:
			for u: Unit in main.units:
				if u.in_cellar and u.alive and (u.position.distance_to(last_known) < 170.0 or u.position.distance_to(position) < 200.0):
					spot = u.position
					break
		if spot != Vector2.INF:
			main.log_msg("The machine fires a canister of BLACK SMOKE!")
			main.spawn_projectile("smoke", lens_global() + Vector2(0, HEIGHT), spot + Vector2(randf_range(-30, 30), randf_range(-20, 20)), self)
			smoke_cd = 20.0
			smoke_mark = Vector2.INF
	target = null
	state = S.PATROL
	var best := 0
	for i in waypoints.size():
		if waypoints[i].distance_to(position) < waypoints[best].distance_to(position):
			best = i
	wp_i = best


func _fire_ray() -> void:
	beam_to = target.position
	beam_t = 0.35
	charge = 0.0
	main.heat_ray(lens_global(), beam_to)
	state = S.COOLDOWN
	cooldown = 1.8


func hear(pos: Vector2) -> void:
	if state == S.PATROL or state == S.SEARCH or state == S.INVESTIGATE:
		goal = pos
		state = S.INVESTIGATE
	elif state == S.HUNT and lost_t > 0.5:
		last_known = pos


func on_shell(pos: Vector2, gun: Unit) -> void:
	if not is_active():
		return
	if pos.distance_to(position) > 70.0:
		hear(gun.position)
		return
	since_hit = 0.0
	stagger = 0.9
	if shield_up():
		shield -= 50.0
		shield_flash = 1.0
		if shield <= 0.0:
			shield = 0.0
			shield_broken = 7.0
			main.log_msg("The shield OVERLOADS! It is exposed for a few seconds. Fire again!")
		else:
			main.log_msg("The shell bursts harmlessly against an invisible shield.")
	else:
		hull -= 1
		stagger = 1.5
		if hull > 0:
			main.log_msg("DIRECT HIT! The machine reels. (%d more to bring it down)" % hull)
		else:
			_die("brought down by the guns")
			return
	if gun and gun.alive:
		target = gun
		last_known = gun.position
		awareness[gun] = 1.0
		lost_t = 0.0
		state = S.HUNT


func _die(why: String) -> void:
	state = S.DYING
	dying_t = 0.0
	death_cause = why
	main.on_tripod_down(why)


func _turn_toward(dir: Vector2, max_turn: float) -> float:
	var ang := facing.angle_to(dir)
	facing = facing.rotated(clampf(ang, -max_turn, max_turn)).normalized()
	return ang


func _move_toward(p: Vector2, delta: float, mult: float) -> bool:
	var to := p - position
	if to.length() < 14.0:
		return true
	var ang := _turn_toward(to, 1.6 * delta)
	if absf(ang) < 0.9:
		position += facing * base_speed * mult * (1.0 - 0.45 * sickness) * delta
	position = position.clamp(Vector2(20, 20), Vector2(World.W - 20, World.H - 20))
	return false


func _update_legs(delta: float) -> void:
	if step_i >= 0:
		step_t += delta / 0.42
		var k := minf(step_t, 1.0)
		feet[step_i] = foot_from[step_i].lerp(foot_to[step_i], k)
		lift[step_i] = sin(k * PI)
		if step_t >= 1.0:
			lift[step_i] = 0.0
			step_i = -1
		return
	var worst := -1
	var wd := 34.0
	for i in 3:
		var d := feet[i].distance_to(_ideal_foot(i))
		if d > wd:
			wd = d
			worst = i
	if worst >= 0:
		step_i = worst
		step_t = 0.0
		foot_from[worst] = feet[worst]
		foot_to[worst] = _ideal_foot(worst) + facing * 24.0


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if state == S.DEAD:
		_draw_wreck()
		return
	var hub_h := HEIGHT
	var tilt := Vector2.ZERO
	if state == S.DYING:
		var k := minf(dying_t / 2.2, 1.0)
		hub_h = lerpf(HEIGHT, 6.0, k * k)
		tilt = Vector2(34, 12) * k * k
	var hub := Vector2(0, -hub_h) + tilt
	var sq := Vector2(1, 0.78) * SCALE
	var metal := Color(0.20, 0.15, 0.13)
	var rim := Color(1.0, 0.5, 0.15)

	# searchlight / field of view on the ground
	if is_active():
		var cone := PackedVector2Array([Vector2.ZERO])
		for j in 15:
			var a := -fov * 0.5 + fov * j / 14.0
			cone.append(facing.rotated(a) * view_range)
		var cc := Color(0.55, 1.0, 0.6, 0.045)
		if state == S.CHARGE:
			cc = Color(0.65, 1.0, 0.5, 0.09)
		elif state == S.HUNT:
			cc = Color(0.8, 1.0, 0.5, 0.07)
		draw_colored_polygon(cone, cc)

	# shadow
	draw_set_transform(Vector2(44, 28), 0, Vector2(1.7, 0.8))
	draw_circle(Vector2.ZERO, 48, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	# legs
	for i in 3:
		var f := to_local(feet[i]) + Vector2(0, -lift[i] * 16.0)
		if state == S.DYING:
			f += (f - Vector2.ZERO).normalized() * dying_t * 18.0
		var knee := (f + hub) * 0.5 + Vector2(0, -44) + (f - hub).normalized().orthogonal() * 8.0
		draw_line(f, knee, Color(0.05, 0.03, 0.03), 10.0)
		draw_line(knee, hub, Color(0.05, 0.03, 0.03), 12.0)
		draw_line(f, knee, metal, 7.0)
		draw_line(knee, hub, metal, 9.0)
		draw_line(f + Vector2(-2.5, 0), knee + Vector2(-2.5, 0), Color(rim, 0.8), 2.0)
		draw_line(knee + Vector2(-3, 0), hub + Vector2(-3, 0), Color(rim, 0.8), 2.0)
		draw_circle(knee, 7.0, Color(0.25, 0.19, 0.16))
		draw_circle(knee, 2.6, Color(0.4, 1.0, 0.5, 0.7))
		draw_circle(f, 6.0, Color(0.08, 0.06, 0.05))
		draw_arc(f, 9.0, 0, TAU, 16, Color(0, 0, 0, 0.35), 3.0)

	# hanging tentacles
	for k in 3:
		var base := hub + Vector2((k - 1) * 16.0, 18.0)
		var pts := PackedVector2Array()
		for s in 7:
			var y := s * 11.0
			pts.append(base + Vector2(sin(_t * 2.2 + k * 1.9 + s * 0.7) * (s * 1.2), y))
		draw_polyline(pts, Color(0.30, 0.22, 0.18), 3.0, true)

	# the carrier-cage slung behind, like a workman's basket
	if is_active() or state == S.DYING:
		_draw_cage(hub, sq)
	# tentacle reaching for a victim
	if state == S.GRAB and _valid_target():
		var tp := to_local(target.position)
		var k := clampf(grab_t / GRAB_TIME, 0.0, 1.0)
		var start := hub + Vector2(0, 18)
		var end := start.lerp(tp, minf(1.0, k * 1.6))
		for side in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for s in 9:
				var u := s / 8.0
				var w: float = sin(u * PI) * (10.0 + 6.0 * sin(_t * 9.0)) * side
				pts.append(start.lerp(end, u) + (end - start).normalized().orthogonal() * w)
			draw_polyline(pts, Color(0.05, 0.03, 0.03), 5.0, true)
			draw_polyline(pts, Color(0.55, 0.32, 0.2), 2.0, true)

	# cowled body
	var ang := facing.angle()
	var body := PackedVector2Array()
	for p in BODY:
		body.append(hub + (p as Vector2).rotated(ang) * sq)
	draw_colored_polygon(body, Color(0.24, 0.17, 0.14))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0.05, 0.03, 0.03), 3.0, true)
	# fire-lit lower rim
	var lower := PackedVector2Array()
	for idx in [5, 6, 7, 8, 0]:
		lower.append(body[idx])
	draw_polyline(lower, Color(rim, 0.95), 3.0, true)
	# hood ridge and plates
	draw_line(hub + Vector2(30, 0).rotated(ang) * sq, hub + Vector2(-32, 0).rotated(ang) * sq, Color(0.32, 0.22, 0.18), 3.0)
	for px in [-14.0, 6.0]:
		draw_line(hub + Vector2(px, -18).rotated(ang) * sq, hub + Vector2(px, 18).rotated(ang) * sq, Color(0.07, 0.05, 0.04), 1.5)
	# heat-ray projector arm
	var arm := hub + Vector2(18, -16).rotated(ang) * sq
	draw_line(hub + Vector2(4, -12).rotated(ang) * sq, arm, Color(0.25, 0.2, 0.17), 3.0)
	draw_circle(arm, 3.5, Color(0.3, 0.25, 0.2))

	# the eye / lens
	var lens := hub + Vector2(30, 0).rotated(ang) * sq
	var ca := charge / CHARGE_TIME if state == S.CHARGE else 0.0
	var pulse := 0.7 + 0.3 * sin(_t * 3.0)
	if is_active():
		draw_circle(lens, 16.0 + ca * 22.0, Color(0.3, 1.0, 0.5, 0.2 * pulse + ca * 0.3))
		draw_circle(lens, 7.5, Color(0.55, 1.0, 0.65))
		draw_circle(lens, 3.2, Color(0.95, 1.0, 0.9))
	else:
		draw_circle(lens, 4.0, Color(0.15, 0.25, 0.15))

	# heat-ray: charging line, then the beam
	if state == S.CHARGE and _valid_target():
		var tp := to_local(target.position)
		if int(_t * 20.0) % 2 == 0:
			draw_line(lens, tp, Color(0.5, 1.0, 0.6, 0.15 + 0.4 * ca), 1.0 + ca * 2.0)
	if beam_t > 0.0:
		var bp := to_local(beam_to)
		var a := beam_t / 0.35
		draw_line(lens, bp, Color(0.35, 1.0, 0.45, 0.30 * a), 18.0)
		draw_line(lens, bp, Color(0.55, 1.0, 0.6, 0.6 * a), 7.0)
		draw_line(lens, bp, Color(0.95, 1.0, 0.9, a), 2.5)
		draw_circle(bp, 26.0 * a, Color(0.75, 1.0, 0.55, 0.45 * a))

	# shield
	if is_active():
		draw_set_transform(hub, 0, Vector2(1.0, 0.8))
		if shield_up():
			var sa := 0.10 + 0.05 * sin(_t * 4.0) + shield_flash * 0.6
			draw_arc(Vector2.ZERO, 84, 0, TAU, 64, Color(0.5, 1.0, 0.8, sa), 2.0)
			for k in 3:
				var a0 := _t * 0.8 + k * TAU / 3.0
				draw_arc(Vector2.ZERO, 78, a0, a0 + 0.9, 16, Color(0.6, 1.0, 0.85, sa * 0.7), 1.0)
		else:
			for k in 6:
				if randf() < 0.5:
					var a0 := randf() * TAU
					draw_arc(Vector2.ZERO, 84, a0, a0 + randf_range(0.1, 0.4), 6, Color(0.6, 1.0, 0.8, 0.5), 1.5)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if shield_broken > 0.0 or flicker > 0.0:
			draw_string(ThemeDB.fallback_font, hub + Vector2(-44, -62), "SHIELD DOWN", HORIZONTAL_ALIGNMENT_CENTER, 88, 12, Color(1, 0.85, 0.3, 0.6 + 0.4 * sin(_t * 12.0)))

	if state == S.DYING:
		for k in 6:
			var p := hub + Vector2(sin(k * 2.1 + _t) * 18.0, -dying_t * 20.0 - k * 9.0)
			draw_circle(p, 9.0 + k * 2.0, Color(0.05, 0.05, 0.05, 0.4))


func _draw_cage(hub: Vector2, sq: Vector2) -> void:
	var ang := facing.angle()
	var c := hub + Vector2(-58, 0).rotated(ang) * sq
	var r := 19.0
	var metal := Color(0.32, 0.24, 0.2)
	for side in [-12.0, 12.0]:
		draw_line(hub + Vector2(-26, side).rotated(ang) * sq, c + Vector2(r * 0.6, side * 0.8).rotated(ang), Color(0.1, 0.07, 0.06), 4.0)
	draw_set_transform(c, ang, Vector2(1.0, 0.85))
	draw_circle(Vector2.ZERO, r, Color(0.05, 0.03, 0.03, 0.85))
	var i := 0
	for u in captives:
		var p := Vector2(-6 + (i % 2) * 12, -6 + (i / 2) * 12) + Vector2(sin(_t * 3.0 + i), cos(_t * 2.0 + i)) * 1.5
		draw_circle(p, 4.5, (u as Survivor).coat if u is Survivor else Color(0.5, 0.4, 0.3))
		draw_circle(p + Vector2(1.5, 0), 2.2, Color(0.9, 0.75, 0.6))
		i += 1
	for x in range(-15, 16, 6):
		var h := sqrt(maxf(r * r - x * x, 0.0))
		draw_line(Vector2(x, -h), Vector2(x, h), metal, 1.5)
		draw_line(Vector2(-h, x), Vector2(h, x), metal, 1.5)
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(0.05, 0.03, 0.03), 4.0)
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1.0, 0.5, 0.15, 0.7), 1.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_wreck() -> void:
	var metal := Color(0.12, 0.09, 0.08)
	for i in 3:
		var dir := facing.rotated(PI / 3.0 + i * TAU / 3.0)
		draw_line(Vector2(34, 12), Vector2(34, 12) + dir * 90.0, metal, 5.0)
		draw_line(Vector2(34, 12) + dir * 90.0, Vector2(34, 12) + dir * 90.0 + dir.orthogonal() * 20.0, metal, 4.0)
	var body := PackedVector2Array()
	for p in BODY:
		body.append(Vector2(34, 12) + (p as Vector2).rotated(facing.angle() + 0.4) * Vector2(1, 0.78))
	draw_colored_polygon(body, Color(0.10, 0.07, 0.06))
	draw_circle(Vector2(34, 12) + facing * 26.0, 4.0, Color(0.15, 0.25, 0.15))
