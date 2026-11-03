class_name Person3D
extends Node3D
## A fleeing civilian. Wanders until a machine comes close, then runs.

var world: Countryside3D
var threat: Node3D          # the machine they flee from
var alive := true
var speed := 0.0
var _dir := Vector3.FORWARD
var _t := randf() * 10.0
var _mesh: MeshInstance3D

const COATS := [Color(0.35, 0.18, 0.3), Color(0.2, 0.28, 0.4), Color(0.4, 0.32, 0.18), Color(0.25, 0.25, 0.25), Color(0.45, 0.2, 0.15)]


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Tripod3D._capsule(0.3, 1.7)
	_mesh.material_override = Tripod3D._mat(COATS[randi() % COATS.size()], 0.0, 0.9)
	_mesh.position = Vector3(0, 0.85, 0)
	add_child(_mesh)
	var head := MeshInstance3D.new()
	head.mesh = Tripod3D._sphere(0.22)
	head.material_override = Tripod3D._mat(Color(0.85, 0.68, 0.55), 0.0, 0.8)
	head.position = Vector3(0, 1.0, 0)
	_mesh.add_child(head)
	_dir = Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()


func _process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	var target_speed := 1.0
	if threat and is_instance_valid(threat):
		var away := global_position - threat.global_position
		away.y = 0.0
		var d := away.length()
		if d < 110.0:
			target_speed = 6.0
			_dir = _dir.lerp(away.normalized(), delta * 2.0).normalized()
	if randf() < delta * 0.4:
		_dir = _dir.rotated(Vector3.UP, randf_range(-0.8, 0.8))
	speed = move_toward(speed, target_speed, delta * 6.0)
	var next := global_position + _dir * speed * delta
	var h := world.house_near(next, 9.0)
	if not h.is_empty():
		_dir = _dir.rotated(Vector3.UP, 1.2)
	elif absf(next.x) < Countryside3D.HALF and absf(next.z) < Countryside3D.HALF:
		global_position = next
	else:
		_dir = -_dir
	rotation.y = atan2(-_dir.x, -_dir.z)
	_mesh.position.y = 0.85 + absf(sin(_t * 12.0)) * 0.15 * (speed / 6.0)


func burn() -> void:
	if not alive:
		return
	alive = false
	_mesh.material_override = Tripod3D._mat(Color(0.05, 0.04, 0.04), 0.0, 1.0)
	_mesh.rotation.x = PI / 2
	_mesh.position.y = 0.3
