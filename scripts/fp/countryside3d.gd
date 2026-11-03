class_name Countryside3D
extends Node3D
## The 3D Surrey countryside around Horsell Common at night: red sky, fog,
## a village, woods, a river, burning farms and the pit with its cylinder.
## 1 unit = 1 metre. Ground is flat at y = 0.

const HALF := 400.0
const RIVER_Z := 130.0
const PIT := Vector3(150, 0, -150)

var houses: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var _brick: Array[StandardMaterial3D] = []
var _roof: StandardMaterial3D
var _window: StandardMaterial3D


func _ready() -> void:
	rng.seed = 1898
	_environment()
	_ground()
	_river()
	_roads()
	_brick = [Tripod3D._mat(Color(0.42, 0.2, 0.14), 0.0, 0.9), Tripod3D._mat(Color(0.5, 0.42, 0.32), 0.0, 0.9), Tripod3D._mat(Color(0.35, 0.16, 0.12), 0.0, 0.9)]
	_roof = Tripod3D._mat(Color(0.14, 0.11, 0.11), 0.1, 0.7)
	_window = Tripod3D._emit(Color(1.0, 0.62, 0.25), 2.5)
	# Horsell village
	for i in 26:
		var a := rng.randf() * TAU
		var d := 18.0 + sqrt(rng.randf()) * 75.0
		_try_house(Vector3(-70 + cos(a) * d, 0, -30 + sin(a) * d))
	# hamlet by the river
	for i in 9:
		_try_house(Vector3(70 + rng.randf_range(-35, 35), 0, 90 + rng.randf_range(-20, 15)))
	# farms near the pit
	for p in [Vector3(95, 0, -120), Vector3(190, 0, -95), Vector3(120, 0, -210)]:
		var h := _try_house(p)
		if not h.is_empty():
			ignite(h)
	_woods(Vector3(40, 0, -10), 45.0)
	_woods(Vector3(-160, 0, 60), 50.0)
	_woods(Vector3(180, 0, 40), 40.0)
	_woods(Vector3(-40, 0, -150), 35.0)
	_woods(Vector3(-120, 0, 220), 60.0)
	_pit()
	add_fire(PIT + Vector3(-30, 0, 20), 3.0, -1.0)
	# Woking burning on the horizon
	for p in [Vector3(-330, 0, -320), Vector3(-260, 0, -360), Vector3(330, 0, 300), Vector3(360, 0, -250)]:
		add_fire(p, 6.0, -1.0)
	add_fire(PIT + Vector3(25, 0, 35), 2.5, -1.0)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.05, 0.0, 0.015)
	sm.sky_horizon_color = Color(0.9, 0.3, 0.06)
	sm.sky_curve = 0.09
	sm.ground_bottom_color = Color(0.05, 0.01, 0.01)
	sm.ground_horizon_color = Color(0.6, 0.18, 0.05)
	sm.sun_angle_max = 8.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.12, 0.1)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.07, 0.03)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.4, 0.22)
	sun.light_energy = 0.38
	sun.rotation_degrees = Vector3(-14, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)


func _ground() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(HALF * 3, 2, HALF * 3)
	cs.shape = bs
	cs.position = Vector3(0, -1, 0)
	body.add_child(cs)
	add_child(body)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF * 3, HALF * 3)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 4
	nt.noise = fn
	nt.seamless = true
	nt.width = 512
	nt.height = 512
	nt.color_ramp = Fire3D.ramp([Color(0.09, 0.05, 0.03), Color(0.2, 0.11, 0.06), Color(0.14, 0.1, 0.05)])
	m.albedo_texture = nt
	m.uv1_scale = Vector3(30, 30, 1)
	m.roughness = 1.0
	mi.material_override = m
	add_child(mi)


func _river() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF * 3, 28)
	mi.mesh = pm
	mi.position = Vector3(0, 0.06, RIVER_Z)
	var m := Tripod3D._mat(Color(0.2, 0.03, 0.03), 0.6, 0.06)
	mi.material_override = m
	add_child(mi)
	for bx in [-40.0, 80.0]:
		var b := _static_box(Vector3(bx, 0.6, RIVER_Z), Vector3(7, 1.2, 36), Tripod3D._mat(Color(0.3, 0.2, 0.13), 0.0, 0.9))
		b.name = "Bridge"


func _roads() -> void:
	var road := Tripod3D._mat(Color(0.42, 0.28, 0.17), 0.0, 1.0)
	var lines := [
		[Vector3(-300, 0, -40), Vector3(-70, 0, -30), Vector3(60, 0, -60), Vector3(150, 0, -120), Vector3(320, 0, -160)],
		[Vector3(-70, 0, -150), Vector3(-70, 0, -30), Vector3(-40, 0, 110), Vector3(-40, 0, 150), Vector3(-60, 0, 330)],
		[Vector3(60, 0, -60), Vector3(80, 0, 110), Vector3(80, 0, 150), Vector3(120, 0, 330)],
	]
	for line in lines:
		for i in range(line.size() - 1):
			var a: Vector3 = line[i]
			var b: Vector3 = line[i + 1]
			var mi := MeshInstance3D.new()
			mi.mesh = Tripod3D._box(Vector3(6, 0.08, a.distance_to(b) + 6))
			mi.material_override = road
			mi.position = (a + b) * 0.5 + Vector3(0, 0.04, 0)
			mi.rotation.y = atan2(b.x - a.x, b.z - a.z)
			add_child(mi)


func _try_house(p: Vector3) -> Dictionary:
	var size := Vector3(rng.randf_range(7, 12), rng.randf_range(5, 7), rng.randf_range(6, 9))
	if absf(p.z - RIVER_Z) < 26.0:
		return {}
	for h in houses:
		if (h.pos as Vector3).distance_to(p) < 14.0:
			return {}
	var yaw := rng.randf_range(-0.4, 0.4) + (PI / 2 if rng.randf() < 0.3 else 0.0)
	var body := StaticBody3D.new()
	body.position = p
	body.rotation.y = yaw
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size + Vector3(0, size.y * 0.5, 0)
	cs.shape = bs
	cs.position = Vector3(0, bs.size.y * 0.5, 0)
	body.add_child(cs)
	var walls := MeshInstance3D.new()
	walls.mesh = Tripod3D._box(size)
	walls.material_override = _brick[rng.randi() % _brick.size()]
	walls.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(walls)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(size.x + 0.8, size.y * 0.55, size.z + 0.6)
	roof.mesh = pr
	roof.material_override = _roof
	roof.position = Vector3(0, size.y + size.y * 0.275, 0)
	body.add_child(roof)
	var chim := MeshInstance3D.new()
	chim.mesh = Tripod3D._box(Vector3(1.0, 2.5, 1.0))
	chim.material_override = _brick[0]
	chim.position = Vector3(size.x * 0.3, size.y * 1.45, 0)
	body.add_child(chim)
	if rng.randf() < 0.6:
		for wx in [-0.25, 0.25]:
			var w := MeshInstance3D.new()
			w.mesh = Tripod3D._box(Vector3(1.1, 1.3, 0.1))
			w.material_override = _window
			w.position = Vector3(size.x * wx, size.y * 0.55, size.z * 0.5 + 0.05)
			body.add_child(w)
	var h := {"body": body, "pos": p, "size": size, "burning": false, "heat": 0.0}
	houses.append(h)
	return h


func _woods(c: Vector3, r: float) -> void:
	var n := int(r * r / 45.0)
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.mesh = Tripod3D._sphere(1.0)
	crowns.instance_count = n
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = Tripod3D._cyl(0.3, 0.45, 1.0)
	trunks.instance_count = n
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var p := c + Vector3(cos(a) * d, 0, sin(a) * d)
		var s := rng.randf_range(2.5, 4.5)
		var th := rng.randf_range(4.0, 7.0)
		trunks.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, th, 1)), p + Vector3(0, th * 0.5, 0)))
		crowns.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s * 1.3, s)), p + Vector3(0, th + s * 0.8, 0)))
	var cm := MultiMeshInstance3D.new()
	cm.multimesh = crowns
	cm.material_override = Tripod3D._mat(Color(0.1, 0.12, 0.05), 0.0, 0.95)
	add_child(cm)
	var tm := MultiMeshInstance3D.new()
	tm.multimesh = trunks
	tm.material_override = Tripod3D._mat(Color(0.12, 0.07, 0.04), 0.0, 1.0)
	add_child(tm)


func _pit() -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 14.0
	tm.outer_radius = 30.0
	ring.mesh = tm
	ring.scale = Vector3(1, 0.22, 1)
	ring.position = PIT
	ring.material_override = Tripod3D._mat(Color(0.45, 0.3, 0.17), 0.0, 1.0)
	add_child(ring)
	var cyl := MeshInstance3D.new()
	cyl.mesh = Tripod3D._cyl(6.0, 6.0, 26.0)
	cyl.rotation = Vector3(0, 0.6, PI / 2)
	cyl.position = PIT + Vector3(0, 1.5, 0)
	cyl.material_override = Tripod3D._mat(Color(0.3, 0.29, 0.27), 0.9, 0.35)
	add_child(cyl)
	var cap := MeshInstance3D.new()
	var ct := TorusMesh.new()
	ct.inner_radius = 4.0
	ct.outer_radius = 5.0
	cap.mesh = ct
	cap.material_override = Tripod3D._emit(Color(0.35, 1.0, 0.5), 3.0)
	cap.rotation = Vector3(0, 0.6, PI / 2)
	cap.position = PIT + Vector3(0, 1.5, 0) + Basis.from_euler(Vector3(0, 0.6, 0)) * Vector3(13.2, 0, 0)
	add_child(cap)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.4, 1.0, 0.5)
	gl.omni_range = 40.0
	gl.light_energy = 2.0
	gl.position = PIT + Vector3(0, 6, 0)
	add_child(gl)


func _static_box(p: Vector3, s: Vector3, m: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = p
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = s
	cs.shape = bs
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = Tripod3D._box(s)
	mi.material_override = m
	body.add_child(mi)
	add_child(body)
	return body


# ---------------------------------------------------------------- API

func add_fire(p: Vector3, size: float, life: float) -> Fire3D:
	var f := Fire3D.new()
	f.size = size
	f.life = life
	f.position = p
	add_child(f)
	return f


func explosion(p: Vector3, c: Color, size: float) -> void:
	var e := Explosion3D.new()
	e.color = c
	e.size = size
	e.position = p
	add_child(e)


func ignite(h: Dictionary) -> void:
	if h.burning:
		return
	h.burning = true
	var size: Vector3 = h.size
	add_fire(h.pos + Vector3(0, size.y * 0.8, 0), maxf(size.x, size.z) * 0.45, -1.0)
	for c in (h.body as Node3D).get_children():
		if c is MeshInstance3D and c.material_override == _window:
			c.visible = false


func house_near(p: Vector3, r: float) -> Dictionary:
	var best := {}
	var bd := r
	for h in houses:
		var d := Vector2(p.x - h.pos.x, p.z - h.pos.z).length()
		if d < bd:
			bd = d
			best = h
	return best


func ray(from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(q)
