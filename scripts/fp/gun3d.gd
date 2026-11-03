class_name FieldGun3D
extends Node3D
## A 12-pounder field gun on a wheeled carriage. The carriage turns (yaw);
## the barrel elevates (pitch). Used as enemy batteries in pilot mode and as
## the player's gun in soldier mode.

var carriage: Node3D
var barrel_pivot: Node3D
var alive := true
var silenced := false
var heat := 0.0
var reload := 0.0
var crew: Array[MeshInstance3D] = []
var _flash: OmniLight3D
var _flash_t := 0.0


func _ready() -> void:
	var wood := Tripod3D._mat(Color(0.38, 0.24, 0.13), 0.0, 0.85)
	var iron := Tripod3D._mat(Color(0.18, 0.18, 0.19), 0.85, 0.35)
	carriage = Node3D.new()
	add_child(carriage)
	var trail := MeshInstance3D.new()
	trail.mesh = Tripod3D._box(Vector3(0.35, 0.3, 3.2))
	trail.material_override = wood
	trail.position = Vector3(0, 0.45, 1.5)
	trail.rotation.x = -0.18
	carriage.add_child(trail)
	var axle := MeshInstance3D.new()
	axle.mesh = Tripod3D._box(Vector3(1.9, 0.2, 0.2))
	axle.material_override = iron
	axle.position = Vector3(0, 0.75, 0)
	carriage.add_child(axle)
	for side in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		wheel.mesh = Tripod3D._cyl(0.75, 0.75, 0.12)
		wheel.material_override = wood
		wheel.rotation.z = PI / 2
		wheel.position = Vector3(side * 0.95, 0.75, 0)
		carriage.add_child(wheel)
		var hub := MeshInstance3D.new()
		hub.mesh = Tripod3D._cyl(0.18, 0.18, 0.2)
		hub.material_override = iron
		hub.rotation.z = PI / 2
		hub.position = Vector3(side * 1.0, 0.75, 0)
		carriage.add_child(hub)
	var shield_plate := MeshInstance3D.new()
	shield_plate.mesh = Tripod3D._box(Vector3(1.6, 0.9, 0.06))
	shield_plate.material_override = iron
	shield_plate.position = Vector3(0, 1.25, -0.35)
	carriage.add_child(shield_plate)
	barrel_pivot = Node3D.new()
	barrel_pivot.position = Vector3(0, 1.05, 0)
	carriage.add_child(barrel_pivot)
	var barrel := MeshInstance3D.new()
	barrel.mesh = Tripod3D._cyl(0.09, 0.16, 2.4)
	barrel.material_override = iron
	barrel.rotation.x = PI / 2
	barrel.position = Vector3(0, 0, -1.0)
	barrel_pivot.add_child(barrel)
	var breech := MeshInstance3D.new()
	breech.mesh = Tripod3D._cyl(0.2, 0.2, 0.5)
	breech.material_override = iron
	breech.rotation.x = PI / 2
	breech.position = Vector3(0, 0, 0.3)
	barrel_pivot.add_child(breech)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1, 0.7, 0.3)
	_flash.omni_range = 18.0
	_flash.light_energy = 0.0
	_flash.position = Vector3(0, 0, -2.6)
	barrel_pivot.add_child(_flash)


func add_crew(n: int) -> void:
	var spots := [Vector3(-1.2, 0, 0.9), Vector3(1.2, 0, 0.9), Vector3(0.4, 0, 2.4)]
	for i in n:
		var c := MeshInstance3D.new()
		c.mesh = Tripod3D._capsule(0.3, 1.75)
		c.material_override = Tripod3D._mat(Color(0.12, 0.13, 0.3), 0.0, 0.85)
		c.position = spots[i] + Vector3(0, 0.88, 0)
		carriage.add_child(c)
		crew.append(c)


func _process(delta: float) -> void:
	_flash_t = maxf(0.0, _flash_t - delta)
	_flash.light_energy = _flash_t * 30.0
	reload = maxf(0.0, reload - delta)


func muzzle() -> Vector3:
	return barrel_pivot.global_transform * Vector3(0, 0, -2.3)


func barrel_dir() -> Vector3:
	return -barrel_pivot.global_transform.basis.z.normalized()


func aim_yaw_at(p: Vector3) -> void:
	var d := p - global_position
	carriage.rotation.y = atan2(-d.x, -d.z) - rotation.y


func flash() -> void:
	_flash_t = 0.25


func wreck() -> void:
	alive = false
	carriage.rotation.z = 0.5
	barrel_pivot.rotation.x = -0.3
	for c in crew:
		c.visible = false


func silence() -> void:
	silenced = true
	for c in crew:
		c.rotation.x = PI / 2
		c.position.y = 0.3
