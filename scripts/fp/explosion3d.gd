class_name Explosion3D
extends Node3D
## A one-shot flash and burst of sparks.

var color := Color(1.0, 0.6, 0.2)
var size := 4.0
var _t := 0.0
var _light: OmniLight3D


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = size * 8.0
	_light.light_energy = 8.0
	add_child(_light)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 30
	p.lifetime = 0.8
	p.mesh = Fire3D.quad(true)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, -6, 0)
	p.initial_velocity_min = size * 1.5
	p.initial_velocity_max = size * 4.0
	p.scale_amount_min = size * 0.15
	p.scale_amount_max = size * 0.45
	p.color_ramp = Fire3D.ramp([Color(1, 1, 0.8, 1), color, Color(0.2, 0.05, 0.0, 0.0)])
	p.emitting = true
	add_child(p)


func _process(delta: float) -> void:
	_t += delta
	_light.light_energy = maxf(0.0, 8.0 * (1.0 - _t / 0.5))
	if _t > 1.5:
		queue_free()
