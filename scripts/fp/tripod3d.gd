class_name Tripod3D
extends Node3D
## 3D Martian fighting-machine, shared by both first-person modes.
## Styled after Henrique Alvim Corrêa's 1906 illustrations (public domain): a
## wide conical hat with a spike, two great round eyes, a ribbed screw-like
## body, needle-thin legs with ringed joints, a curtain of hair-thin filaments,
## ribbed tentacles, a camera-like heat-ray box on an arm, and Wells
## "a great metallic carrier which projected behind him, much as a workman's
## basket hangs over his shoulder" - the cage its captives are thrown into.
##
## This node only animates and draws the machine. Whoever owns it (the player
## in pilot mode, MachineAI in soldier mode) moves it and sets its state.
## The node's origin sits on the ground; forward is -Z.

const H := 28.0          # body height
const REACH := 11.0      # foot distance from centre
const SEG := 13.6        # leg segment length (long, nearly straight stilts)
const CAGE_SIZE := 6

var body: Node3D
var cage: Node3D
var lens: MeshInstance3D
var lens_mat: StandardMaterial3D
var lens_light: OmniLight3D
var shield_mat: ShaderMaterial
var beam_core: MeshInstance3D
var beam_glow: MeshInstance3D
var beam_light: OmniLight3D
var beam_on := false
var beam_target := Vector3.ZERO
var charge := 0.0            # 0..1, glows the lens
var shield_strength := 0.14  # 0 hides the shield
var shield_flash := 0.0
var collapse := 0.0          # 0..1 death animation
var captives := 0
var moving := false
var grab_point := Vector3.ZERO
var grab_t := -1.0           # 0..1 while a tentacle reaches out

var _metal: StandardMaterial3D
var _dark: StandardMaterial3D
var _captive_meshes: Array[MeshInstance3D] = []
var _upper: Array[MeshInstance3D] = []
var _lower: Array[MeshInstance3D] = []
var _knees: Array[MeshInstance3D] = []
var _feet_m: Array[MeshInstance3D] = []
var _tent: Array = []
var _filaments: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var feet: Array[Vector3] = []
var _from: Array[Vector3] = []
var _to: Array[Vector3] = []
var _leg_t: Array[float] = [-1.0, -1.0, -1.0]
var _t := 0.0
var _last_pos := Vector3.ZERO


func _ready() -> void:
	_metal = _mat(Color(0.55, 0.5, 0.44), 0.55, 0.45)
	_dark = _mat(Color(0.12, 0.1, 0.09), 0.5, 0.6)
	body = Node3D.new()
	body.position = Vector3(0, H, 0)
	add_child(body)

	# --- after Alvim Corrêa's 1906 plates ---
	# a wide conical hat with a spike on top
	var hat := _mesh(_cyl(0.4, 7.4, 2.4), _metal, body)
	hat.position = Vector3(0, 1.6, 0)
	var brim := _mesh(_cyl(7.8, 7.8, 0.18), _dark, body)
	brim.position = Vector3(0, 0.42, 0)
	var band := _mesh(_cyl(2.2, 2.4, 0.5), _dark, body)
	band.position = Vector3(0, 2.6, 0)
	var spike := _mesh(_cyl(0.06, 0.16, 3.0), _dark, body)
	spike.position = Vector3(0, 4.3, 0)
	var knob := _mesh(_sphere(0.38), _metal, body)
	knob.position = Vector3(0, 5.9, 0)
	var vane := _mesh(_box(Vector3(1.6, 0.08, 0.08)), _dark, body)
	vane.position = Vector3(0, 5.2, 0)
	# the head under the brim, with two great round eyes
	var head := _mesh(_sphere(2.6), _dark, body)
	head.scale = Vector3(1.0, 0.8, 1.0)
	head.position = Vector3(0, -0.6, 0)
	var white := _emit(Color(0.92, 0.9, 0.82), 0.6)
	var black := _mat(Color(0.02, 0.02, 0.02), 0.2, 0.3)
	for side in [-1.0, 1.0]:
		var eye := _mesh(_sphere(0.9), white, body)
		eye.position = Vector3(side * 1.15, -0.45, -2.15)
		var pupil := _mesh(_sphere(0.42), black, body)
		pupil.position = Vector3(side * 1.1, -0.5, -2.95)
	# a ribbed, screw-like body tapering beneath
	var rib_y := -2.4
	var rib_r := 2.2
	for k in 6:
		var rib := _mesh(_cyl(rib_r, rib_r * 0.92, 0.5), _metal, body)
		rib.position = Vector3(0, rib_y, 0)
		var gap := _mesh(_cyl(rib_r * 0.8, rib_r * 0.8, 0.3), _dark, body)
		gap.position = Vector3(0, rib_y - 0.4, 0)
		rib_y -= 0.8
		rib_r *= 0.86
	var tip := _mesh(_cyl(0.8, 0.15, 1.4), _dark, body)
	tip.position = Vector3(0, rib_y - 0.3, 0)

	# the heat-ray: a camera-like box held out on a ribbed arm
	var arm_pts := [Vector3(1.6, -3.0, -0.6), Vector3(3.4, -3.6, -2.0), Vector3(4.4, -3.0, -3.8), Vector3(4.6, -2.3, -5.4)]
	for k in arm_pts.size() - 1:
		var seg := _mesh(_cyl(1, 1, 1), _metal, body)
		_local_segment(seg, arm_pts[k], arm_pts[k + 1], 0.3)
		var ring := _mesh(_cyl(0.42, 0.42, 0.25), _dark, body)
		_local_segment(ring, arm_pts[k].lerp(arm_pts[k + 1], 0.45), arm_pts[k].lerp(arm_pts[k + 1], 0.55), 0.42)
	var box := _mesh(_box(Vector3(1.3, 1.1, 1.8)), _dark, body)
	box.position = Vector3(4.6, -2.3, -6.0)
	var hood_box := _mesh(_box(Vector3(1.5, 0.15, 0.9)), _metal, body)
	hood_box.position = Vector3(4.6, -1.65, -6.6)
	lens_mat = _emit(Color(0.35, 1.0, 0.5), 5.0)
	lens = _mesh(_cyl(0.42, 0.42, 0.3), lens_mat, body)
	lens.rotation.x = PI / 2
	lens.position = Vector3(4.6, -2.3, -6.95)
	lens_light = OmniLight3D.new()
	lens_light.light_color = Color(0.4, 1.0, 0.55)
	lens_light.omni_range = 22.0
	lens_light.light_energy = 1.5
	lens_light.position = Vector3(4.6, -2.3, -8.5)
	body.add_child(lens_light)
	# a second, coiled ribbed tentacle on the left
	var coil := [Vector3(-1.6, -3.2, -0.4), Vector3(-3.6, -4.0, -1.6), Vector3(-4.6, -5.6, -1.0), Vector3(-4.0, -6.8, 0.2), Vector3(-3.0, -6.2, -0.6), Vector3(-3.4, -5.0, -1.8)]
	for k in coil.size() - 1:
		var seg := _mesh(_cyl(1, 1, 1), _metal, body)
		_local_segment(seg, coil[k], coil[k + 1], 0.24)
	# a curtain of hair-thin filaments hanging from under the brim
	for k in 18:
		var a := TAU * k / 18.0
		var f := _mesh(_cyl(1, 1, 1), _dark, body)
		var top := Vector3(cos(a) * 5.5, 0.3, sin(a) * 5.5)
		_local_segment(f, top, top + Vector3(randf_range(-0.6, 0.6), -randf_range(5.0, 9.0), randf_range(-0.6, 0.6)), 0.05)
		_filaments.append(f)

	_build_cage()

	# legs and tentacles live in world space
	var joint := _mat(Color(0.28, 0.2, 0.15), 0.8, 0.4)
	var glow := _emit(Color(0.35, 1.0, 0.5), 2.0)
	for i in 3:
		_upper.append(_world_mesh(_cyl(1, 1, 1), _metal))
		_lower.append(_world_mesh(_cyl(1, 1, 1), _metal))
		for r in 4:
			_rings.append(_world_mesh(_cyl(1, 1, 1), joint))
		var k := _world_mesh(_sphere(0.7), joint)
		var kl := _mesh(_sphere(0.35), glow, k)
		kl.position = Vector3(0, 0, -1.0)
		_knees.append(k)
		_feet_m.append(_world_mesh(_cyl(0.5, 1.0, 0.6), _dark))
		var f := _ideal_foot(i)
		feet.append(f)
		_from.append(f)
		_to.append(f)
	for k in 4:
		var chain: Array[MeshInstance3D] = []
		for s in 5:
			chain.append(_world_mesh(_cyl(1, 1, 1), _metal))
		_tent.append(chain)

	# heat-ray beam
	beam_core = _world_mesh(_cyl(1, 1, 1), _emit(Color(0.85, 1.0, 0.85), 12.0))
	var gm := _emit(Color(0.08, 0.35, 0.12), 1.0)
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_glow = _world_mesh(_cyl(1, 1, 1), gm)
	beam_core.visible = false
	beam_glow.visible = false
	beam_light = OmniLight3D.new()
	beam_light.light_color = Color(0.6, 1.0, 0.5)
	beam_light.omni_range = 30.0
	beam_light.light_energy = 0.0
	beam_light.top_level = true
	add_child(beam_light)

	# shield
	var sh := MeshInstance3D.new()
	sh.mesh = _sphere(1.0)
	sh.scale = Vector3.ONE * 12.0
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield_mat = ShaderMaterial.new()
	shield_mat.shader = load("res://shaders/shield.gdshader")
	sh.material_override = shield_mat
	body.add_child(sh)
	_last_pos = global_position


func _build_cage() -> void:
	cage = Node3D.new()
	cage.position = Vector3(0, -5.5, 7.0)
	body.add_child(cage)
	var bar := _mat(Color(0.18, 0.13, 0.1), 0.85, 0.5)
	for side in [-1.6, 1.6]:
		var strut := _mesh(_box(Vector3(0.4, 0.4, 4.8)), _metal, body)
		strut.position = Vector3(side, -3.0, 4.2)
		strut.rotation.x = 0.55
	var r := 2.8
	var h := 4.6
	for y in [h * 0.5, -h * 0.5, 0.0]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.14
		tm.outer_radius = r + 0.14
		ring.mesh = tm
		ring.material_override = bar
		ring.position = Vector3(0, y, 0)
		cage.add_child(ring)
	var floor_m := _mesh(_cyl(r, r * 0.9, 0.35), _dark, cage)
	floor_m.position = Vector3(0, -h * 0.5, 0)
	for k in 16:
		var a := TAU * k / 16.0
		var b := _mesh(_box(Vector3(0.16, h, 0.16)), bar, cage)
		b.position = Vector3(cos(a) * r, 0, sin(a) * r)
	for k in 2:
		var top := _mesh(_box(Vector3(r * 2.0, 0.16, 0.16)), bar, cage)
		top.position = Vector3(0, h * 0.5, 0)
		top.rotation.y = k * PI / 2
	var coats := [Color(0.35, 0.18, 0.3), Color(0.2, 0.28, 0.4), Color(0.4, 0.32, 0.18), Color(0.3, 0.3, 0.3), Color(0.45, 0.2, 0.15), Color(0.2, 0.3, 0.2)]
	for k in CAGE_SIZE:
		var person := _mesh(_capsule(0.28, 1.7), _mat(coats[k], 0.0, 0.9), cage)
		var a := TAU * k / CAGE_SIZE + 0.4
		person.position = Vector3(cos(a) * 1.4, -h * 0.5 + 1.0, sin(a) * 1.4)
		var head := _mesh(_sphere(0.22), _mat(Color(0.85, 0.68, 0.55), 0.0, 0.8), person)
		head.position = Vector3(0, 0.95, 0)
		person.visible = false
		_captive_meshes.append(person)


## Hide the parts that would block a pilot's view from under the brim.
func set_first_person(on: bool) -> void:
	for f in _filaments:
		f.visible = not on


func set_captives(n: int) -> void:
	captives = clampi(n, 0, CAGE_SIZE)
	for k in _captive_meshes.size():
		_captive_meshes[k].visible = k < captives


# ---------------------------------------------------------------- queries

func forward() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func body_pos() -> Vector3:
	return body.global_position


## Between the two eyes: where the machine looks from.
func lens_pos() -> Vector3:
	return body.global_transform * Vector3(0, -0.5, -3.0)


## Where the heat-ray leaves the projector arm on the machine's right side.
func ray_origin() -> Vector3:
	return body.global_transform * Vector3(4.6, -2.3, -7.2)


## Turn toward a world direction at a limited rate. Returns the remaining angle.
func turn_toward(dir: Vector3, max_turn: float) -> float:
	dir.y = 0.0
	if dir.length() < 0.01:
		return 0.0
	var want := atan2(-dir.x, -dir.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	rotation.y += clampf(diff, -max_turn, max_turn)
	return diff


# ---------------------------------------------------------------- animation

func _process(delta: float) -> void:
	_t += delta
	var vel := (global_position - _last_pos) / maxf(delta, 0.0001)
	_last_pos = global_position
	moving = vel.length() > 0.5

	var bob := sin(_t * 4.0) * 0.35 if moving else sin(_t * 1.2) * 0.12
	var drop := collapse * collapse * (H - 4.0)
	body.position = Vector3(collapse * 6.0, H + bob - drop, 0)
	body.rotation = Vector3(collapse * 0.5, 0, collapse * 0.7)
	cage.rotation.z = sin(_t * 1.6) * (0.08 if moving else 0.03)
	cage.rotation.x = sin(_t * 1.1) * 0.04

	_update_feet(delta, vel)
	_draw_legs()
	_draw_tentacles(delta)

	var c := clampf(charge, 0.0, 1.0)
	lens_mat.emission_energy_multiplier = 5.0 + c * 25.0
	lens.scale = Vector3.ONE * (1.0 + c * 0.7)
	lens_light.light_energy = 1.5 + c * 10.0 if collapse < 0.5 else 0.0

	beam_core.visible = beam_on
	beam_glow.visible = beam_on
	if beam_on:
		var flick := 0.85 + 0.15 * sin(_t * 60.0)
		_segment(beam_core, ray_origin(), beam_target, 0.14 * flick)
		_segment(beam_glow, ray_origin(), beam_target, 0.42 * flick)
		beam_light.global_position = beam_target + Vector3(0, 2, 0)
		beam_light.light_energy = 6.0 * flick
	else:
		beam_light.light_energy = 0.0

	shield_flash = maxf(0.0, shield_flash - delta * 2.0)
	shield_mat.set_shader_parameter("strength", shield_strength + shield_flash * 2.0)


func _ideal_foot(i: int) -> Vector3:
	var a := i * TAU / 3.0
	var d := global_transform.basis * Vector3(sin(a), 0, cos(a))
	d.y = 0.0
	var spread := REACH * (1.0 + collapse * 1.2)
	return Vector3(global_position.x, 0, global_position.z) + d.normalized() * spread


func _update_feet(delta: float, vel: Vector3) -> void:
	var lead := Vector3(vel.x, 0, vel.z) * 0.45
	var busy := false
	for i in 3:
		if _leg_t[i] >= 0.0:
			_leg_t[i] += delta / 0.75
			var k := minf(_leg_t[i], 1.0)
			feet[i] = _from[i].lerp(_to[i], k) + Vector3(0, sin(k * PI) * 4.0, 0)
			if _leg_t[i] >= 1.0:
				feet[i] = _to[i]
				_leg_t[i] = -1.0
			elif _leg_t[i] < 0.5:
				busy = true
	var worst := -1
	var wd := 6.0
	for i in 3:
		if _leg_t[i] < 0.0:
			var d := feet[i].distance_to(_ideal_foot(i))
			if d > wd and (not busy or d > 14.0):
				wd = d
				worst = i
	if worst >= 0:
		_leg_t[worst] = 0.0
		_from[worst] = feet[worst]
		_to[worst] = _ideal_foot(worst) + lead


func _draw_legs() -> void:
	for i in 3:
		var a := i * TAU / 3.0
		var hip := body.global_transform * Vector3(sin(a) * 1.0, -6.4, cos(a) * 1.0)
		var foot := feet[i]
		var v := foot - hip
		var d := v.length()
		var mid := (hip + foot) * 0.5
		var perp := Vector3.UP - v.normalized() * v.normalized().dot(Vector3.UP)
		if perp.length() < 0.01:
			perp = Vector3.RIGHT
		var bend := sqrt(maxf(SEG * SEG - d * d * 0.25, 1.0))
		var knee := mid + perp.normalized() * bend
		_segment(_upper[i], hip, knee, 0.3)
		_segment(_lower[i], knee, foot, 0.24)
		for r in 4:
			var ring := _rings[i * 4 + r]
			if r < 2:
				_segment(ring, hip.lerp(knee, 0.3 + r * 0.35), hip.lerp(knee, 0.33 + r * 0.35), 0.45)
			else:
				_segment(ring, knee.lerp(foot, 0.25 + (r - 2) * 0.4), knee.lerp(foot, 0.28 + (r - 2) * 0.4), 0.38)
		_knees[i].global_position = knee
		_feet_m[i].global_transform = Transform3D(Basis.IDENTITY, foot + Vector3(0, 0.4, 0))


func _draw_tentacles(_delta: float) -> void:
	for k in _tent.size():
		var chain: Array = _tent[k]
		var base := body.global_transform * Vector3((k - 1.5) * 0.9, -6.6, -0.5 + (k % 2) * 1.0)
		var pts: Array[Vector3] = [base]
		var p := base
		for s in chain.size():
			var sway := Vector3(sin(_t * 1.7 + k * 1.3 + s * 0.6), 0, cos(_t * 1.3 + k + s * 0.5)) * (0.25 + s * 0.12)
			p = p + (Vector3.DOWN + sway).normalized() * 2.2
			pts.append(p)
		if grab_t >= 0.0 and k < 2:
			var reach := sin(clampf(grab_t, 0.0, 1.0) * PI)
			var end := pts[pts.size() - 1].lerp(grab_point, reach)
			for s in range(1, pts.size()):
				var u := float(s) / (pts.size() - 1)
				pts[s] = base.lerp(end, u) + Vector3(0, -sin(u * PI) * 3.0 * (1.0 - reach * 0.5), 0) + Vector3(sin(_t * 8.0 + s), 0, 0) * 0.3 * (k * 2 - 1)
		for s in chain.size():
			_segment(chain[s], pts[s], pts[s + 1], 0.22 - s * 0.025)


# ---------------------------------------------------------------- helpers

func _segment(mi: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var y := d / len
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.global_transform = Transform3D(Basis(x * r, y * len, z * r), (a + b) * 0.5)


func _local_segment(mi: MeshInstance3D, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var len := d.length()
	var y := d / len
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x * r, y * len, z * r), (a + b) * 0.5)


func _world_mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.top_level = true
	add_child(mi)
	return mi


func _mesh(m: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _mat(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m


static func _emit(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


static func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 12
	return m


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m
