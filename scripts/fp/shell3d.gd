class_name Shell3D
extends Node3D
## A ballistic shell (or smoke canister). Moves under gravity, and each frame
## asks its owner whether the segment it just travelled hit anything.
## Owner must implement: shell_probe(a, b) -> Dictionary  ({} = no hit,
## else {"point": Vector3, "what": Variant}) and shell_hit(shell, hit).

const G := Vector3(0, -9.8, 0)

var vel := Vector3.ZERO
var kind := "shell"     # or "smoke"
var owner_mode: Node
var source: Node
var age := 0.0
var _mesh: MeshInstance3D
var _trail: CPUParticles3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	if kind == "shell":
		_mesh.mesh = Tripod3D._sphere(0.25)
		_mesh.material_override = Tripod3D._emit(Color(1.0, 0.8, 0.4), 6.0)
	else:
		_mesh.mesh = Tripod3D._cyl(0.6, 0.6, 1.6)
		_mesh.material_override = Tripod3D._mat(Color(0.05, 0.05, 0.05), 0.8, 0.4)
	add_child(_mesh)
	_trail = CPUParticles3D.new()
	_trail.amount = 30
	_trail.lifetime = 0.8 if kind == "shell" else 1.6
	_trail.mesh = Fire3D.quad(kind == "shell")
	_trail.gravity = Vector3.ZERO
	_trail.initial_velocity_min = 0.0
	_trail.initial_velocity_max = 0.3
	_trail.scale_amount_min = 0.5 if kind == "shell" else 1.5
	_trail.scale_amount_max = 1.0 if kind == "shell" else 3.0
	_trail.local_coords = false
	if kind == "shell":
		_trail.color_ramp = Fire3D.ramp([Color(1, 0.8, 0.4, 0.8), Color(0.6, 0.3, 0.1, 0.0)])
	else:
		_trail.color_ramp = Fire3D.ramp([Color(0.02, 0.02, 0.02, 0.8), Color(0.03, 0.03, 0.03, 0.0)])
	add_child(_trail)


## Velocity that lands at `to` after `t` seconds.
static func launch_velocity(from: Vector3, to: Vector3, t: float) -> Vector3:
	return (to - from - 0.5 * G * t * t) / t


func _physics_process(delta: float) -> void:
	age += delta
	var a := global_position
	vel += G * delta
	var b := a + vel * delta
	var hit: Dictionary = owner_mode.shell_probe(a, b, self)
	if not hit.is_empty() or b.y < -5.0 or age > 12.0:
		if hit.is_empty():
			hit = {"point": b, "what": null}
		owner_mode.shell_hit(self, hit)
		queue_free()
		return
	global_position = b
	if vel.length() > 0.1:
		look_at(b + vel, Vector3.UP)
