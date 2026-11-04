class_name FieldGun
extends Unit
## A horse-drawn field gun and its crew. Must unlimber (deploy) before firing;
## every shot is heard by the machine.

enum G { LIMBERED, DEPLOYING, READY, RELOADING, LIMBERING }

const RANGE := 640.0
const DEPLOY_TIME := 2.5
const RELOAD_TIME := 4.0

var gstate: G = G.LIMBERED
var timer := 0.0
var aim := Vector2.RIGHT
var pending_move := Vector2.INF
var recoil := 0.0
var shots := 0


func is_deployed() -> bool:
	return gstate == G.READY or gstate == G.RELOADING


func can_fire() -> bool:
	return alive and gstate == G.READY


func toggle_deploy() -> void:
	if not alive:
		return
	match gstate:
		G.LIMBERED:
			path.clear()
			gstate = G.DEPLOYING
			timer = DEPLOY_TIME
			main.log_msg("The crew unlimber the gun...")
			Sound.play("gun_load", -6.0)
		G.READY, G.RELOADING:
			gstate = G.LIMBERING
			timer = DEPLOY_TIME
			main.log_msg("The crew limber up the gun.")
		G.DEPLOYING:
			gstate = G.LIMBERING
			timer = DEPLOY_TIME - timer


func order_move(target: Vector2) -> void:
	if gstate == G.LIMBERED:
		super.order_move(target)
	else:
		pending_move = target
		if gstate != G.LIMBERING:
			toggle_deploy()


func fire_at(p: Vector2) -> bool:
	if not can_fire():
		return false
	if position.distance_to(p) > RANGE:
		main.log_msg("Out of range.")
		return false
	aim = (p - position).normalized()
	gstate = G.RELOADING
	timer = RELOAD_TIME
	recoil = 1.0
	shots += 1
	main.spawn_projectile("shell", position + aim * 26.0, p, self)
	main.make_noise(position)
	return true


func _tick(delta: float) -> void:
	recoil = maxf(0.0, recoil - delta * 2.0)
	match gstate:
		G.DEPLOYING:
			timer -= delta
			if timer <= 0.0:
				gstate = G.READY
				aim = facing
				main.log_msg("Gun ready. Right-click to fire.")
		G.RELOADING:
			timer -= delta
			if timer <= 0.0:
				gstate = G.READY
				main.log_msg("Gun reloaded.")
		G.LIMBERING:
			timer -= delta
			if timer <= 0.0:
				gstate = G.LIMBERED
				if pending_move != Vector2.INF:
					super.order_move(pending_move)
					pending_move = Vector2.INF


func status_text() -> String:
	if escaped:
		return "WITHDRAWN"
	if not alive:
		return "LOST - " + cause
	if in_smoke:
		return "CREW CHOKING!"
	match gstate:
		G.LIMBERED:
			return "Limbered, moving" if moving else "Limbered"
		G.DEPLOYING:
			return "Unlimbering... %.1fs" % timer
		G.READY:
			return "READY TO FIRE"
		G.RELOADING:
			return "Reloading... %.1fs" % timer
		G.LIMBERING:
			return "Limbering... %.1fs" % timer
	return ""


func _draw() -> void:
	var wood := Color(0.55, 0.35, 0.18)
	var metal := Color(0.40, 0.40, 0.42)
	var dark := Color(0.06, 0.04, 0.03)
	if not alive:
		draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.5))
		draw_line(Vector2(-14, -4), Vector2(12, 6), dark, 4)
		draw_line(Vector2(-6, 8), Vector2(8, -8), Color(0.2, 0.1, 0.06), 3)
		return
	var deployed_look := gstate != G.LIMBERED
	var ang := (aim if deployed_look else facing).angle()
	draw_set_transform(Vector2.ZERO, ang, Vector2(1.3, 1.3))
	if not deployed_look:
		var bob := sin(_t * 12.0) * 1.2 if moving else 0.0
		draw_rect(Rect2(-28, -8, 74, 22), Color(0, 0, 0, 0.35))
		for hy in [-5.0, 5.0]:
			for hx in [26.0, 42.0]:
				draw_rect(Rect2(hx - 7, hy - 2.6 + bob, 14, 5.2), Color(0.42, 0.24, 0.13))
				draw_circle(Vector2(hx + 8, hy + bob), 2.4, Color(0.42, 0.24, 0.13))
		draw_line(Vector2(18, 0), Vector2(46, 0), Color(0.15, 0.1, 0.06), 1.0)
		draw_rect(Rect2(4, -6, 12, 12), wood)
		draw_rect(Rect2(-9, -10, 8, 3), dark)
		draw_rect(Rect2(-9, 7, 8, 3), dark)
		draw_line(Vector2(-4, 0), Vector2(-28, 0), metal, 4.5)
		draw_circle(Vector2(10, -9), 3, Color(0.18, 0.20, 0.42))
	else:
		var r := -recoil * 6.0
		draw_rect(Rect2(-26, -12, 54, 26), Color(0, 0, 0, 0.3))
		draw_line(Vector2(-4, 0), Vector2(-26, 0), wood, 4.0)
		draw_rect(Rect2(-6, -11, 9, 3), dark)
		draw_rect(Rect2(-6, 8, 9, 3), dark)
		draw_line(Vector2(r - 2, 0), Vector2(24 + r, 0), metal, 5.5)
		draw_circle(Vector2(24 + r, 0), 2.6, dark)
		for c in [Vector2(-12, -15), Vector2(-16, 13), Vector2(4, -16), Vector2(6, 15)]:
			draw_circle(c, 3.6, Color(0.18, 0.20, 0.42))
			draw_circle(c + Vector2(1, 0), 1.8, Color(0.8, 0.65, 0.55))
		if recoil > 0.6:
			draw_circle(Vector2(34, 0), 10.0 * recoil, Color(1, 0.75, 0.3, 0.8))
			draw_circle(Vector2(34, 0), 5.0 * recoil, Color(1, 1, 0.8, 0.9))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if selected and is_deployed():
		draw_arc(Vector2.ZERO, RANGE, 0, TAU, 128, Color(1, 0.7, 0.3, 0.22), 1.5)
	var prog := -1.0
	if gstate == G.DEPLOYING or gstate == G.LIMBERING:
		prog = 1.0 - timer / DEPLOY_TIME
	elif gstate == G.RELOADING:
		prog = 1.0 - timer / RELOAD_TIME
	if prog >= 0.0:
		draw_arc(Vector2.ZERO, 21, -PI / 2, -PI / 2 + TAU * prog, 32, Color(1, 0.8, 0.4, 0.85), 2.0)
	elif gstate == G.READY:
		draw_arc(Vector2.ZERO, 21, 0, TAU, 32, Color(0.6, 1.0, 0.5, 0.5 + 0.3 * sin(_t * 6.0)), 2.0)
	_draw_overlay()
