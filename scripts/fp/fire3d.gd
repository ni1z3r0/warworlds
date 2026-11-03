class_name Fire3D
extends Node3D
## A burning fire: flickering light, flames and a smoke column.

var size := 4.0
var life := -1.0       # seconds; negative burns forever
var light: OmniLight3D
var _t := 0.0
var _phase := randf() * 10.0
var _flames: CPUParticles3D
var _smoke: CPUParticles3D


func _ready() -> void:
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.omni_range = size * 6.0
	light.light_energy = 3.0
	light.position = Vector3(0, size * 0.8, 0)
	add_child(light)

	_flames = CPUParticles3D.new()
	_flames.amount = 36
	_flames.lifetime = 0.9
	_flames.mesh = quad(true)
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = size * 0.45
	_flames.direction = Vector3.UP
	_flames.spread = 15.0
	_flames.gravity = Vector3(0, 4, 0)
	_flames.initial_velocity_min = 1.5
	_flames.initial_velocity_max = 4.0
	_flames.scale_amount_min = size * 0.3
	_flames.scale_amount_max = size * 0.7
	_flames.color_ramp = ramp([Color(1, 0.8, 0.45, 0.7), Color(1, 0.4, 0.06, 0.55), Color(0.4, 0.06, 0.0, 0.0)])
	add_child(_flames)

	_smoke = CPUParticles3D.new()
	_smoke.amount = 18
	_smoke.lifetime = 7.0
	_smoke.mesh = quad(false)
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = size * 0.5
	_smoke.position = Vector3(0, size, 0)
	_smoke.direction = Vector3(0.2, 1, 0)
	_smoke.spread = 12.0
	_smoke.gravity = Vector3(0.6, 0.8, 0)
	_smoke.initial_velocity_min = 2.0
	_smoke.initial_velocity_max = 4.0
	_smoke.scale_amount_min = size * 1.0
	_smoke.scale_amount_max = size * 2.4
	_smoke.color_ramp = ramp([Color(0.08, 0.04, 0.03, 0.0), Color(0.06, 0.04, 0.03, 0.55), Color(0.05, 0.04, 0.04, 0.0)])
	add_child(_smoke)


func _process(delta: float) -> void:
	_t += delta
	var fl := 0.8 + 0.2 * sin(_t * 9.0 + _phase) * sin(_t * 4.3 + _phase * 2.0)
	var fade := 1.0
	if life > 0.0:
		life -= delta
		fade = clampf(life / 4.0, 0.0, 1.0)
		_flames.emitting = life > 2.0
		_smoke.emitting = life > 2.0
		if life <= 0.0:
			queue_free()
			return
	light.light_energy = 3.0 * fl * fade


static func quad(additive: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	m.albedo_texture = tex
	q.material = m
	return q


static func ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / (colors.size() - 1), colors[i])
	return g
