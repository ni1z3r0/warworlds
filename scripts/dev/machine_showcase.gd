extends Node3D
## Dev tool: a fighting-machine walking in circles with an orbiting camera.
## Run: godot res://scenes/dev/machine_showcase.tscn  (add -- --shots=/dir to save stills)

var machine: Tripod3D
var cam: Camera3D
var t := 0.0
var _shots := ""
var _taken := 0


func _ready() -> void:
	add_child(Countryside3D.new())
	machine = Tripod3D.new()
	machine.position = Vector3(-20, 0, 40)
	add_child(machine)
	machine.set_captives(3)
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots = a.substr(8)


func _process(delta: float) -> void:
	t += delta
	var a := t * 0.25
	machine.position = Vector3(-20, 0, 40) + Vector3(cos(a * 0.6), 0, sin(a * 0.6)) * 25.0
	machine.rotation.y = -a * 0.6
	machine.charge = 0.5 + 0.5 * sin(t * 2.0)
	machine.grab_t = fmod(t * 0.4, 1.0)
	machine.grab_point = machine.global_position + machine.forward() * 12.0 + Vector3(0, 1, 0)
	var orbit := [Vector3(0, 6, -45), Vector3(40, 18, -20), Vector3(-35, 2, 25)]
	var k := mini(int(t / 3.0), orbit.size() - 1)
	var o: Vector3 = orbit[k]
	cam.global_position = machine.global_position + machine.global_basis * o
	cam.look_at(machine.body_pos() + Vector3(0, -6, 0), Vector3.UP)
	if _shots != "" and t > 2.5 + _taken * 3.0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/machine_%d.png" % [_shots, _taken])
		_taken += 1
		if _taken >= orbit.size():
			get_tree().quit()
