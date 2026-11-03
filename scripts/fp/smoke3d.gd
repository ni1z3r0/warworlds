class_name Smoke3D
extends Node3D
## Wells' black smoke: a heavy, low, poisonous cloud that spreads and lingers.

const MAX_R := 22.0
const LIFE := 25.0
var t := 0.0
var _p: CPUParticles3D


func _ready() -> void:
	_p = CPUParticles3D.new()
	_p.amount = 70
	_p.lifetime = 6.0
	_p.preprocess = 0.0
	_p.mesh = Fire3D.quad(false)
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_p.emission_sphere_radius = 4.0
	_p.direction = Vector3(1, 0.15, 0)
	_p.spread = 180.0
	_p.gravity = Vector3(0, -0.2, 0)
	_p.initial_velocity_min = 2.0
	_p.initial_velocity_max = 5.0
	_p.damping_min = 0.6
	_p.damping_max = 1.0
	_p.scale_amount_min = 8.0
	_p.scale_amount_max = 16.0
	_p.color_ramp = Fire3D.ramp([Color(0.02, 0.02, 0.02, 0.0), Color(0.02, 0.02, 0.025, 0.85), Color(0.03, 0.03, 0.03, 0.75), Color(0.03, 0.03, 0.03, 0.0)])
	add_child(_p)


func radius() -> float:
	return MAX_R * clampf(t / 4.0, 0.0, 1.0) * clampf((LIFE - t) / 5.0, 0.3, 1.0)


func _process(delta: float) -> void:
	t += delta
	_p.emission_sphere_radius = 4.0 + radius() * 0.6
	if t > LIFE - 6.0:
		_p.emitting = false
	if t > LIFE:
		queue_free()
