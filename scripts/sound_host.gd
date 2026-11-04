extends Node
## Holds the game's audio players (see Sound). It also takes over quitting:
## Godot only frees a stopped sound on a later frame, so on quit we silence
## everything and let a few frames pass first. Otherwise Godot reports the
## sounds as leaked resources when the game closes.

var _quitting := false


func _ready() -> void:
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_soon()


func quit_soon(code := 0) -> void:
	if _quitting:
		return
	_quitting = true
	for p in get_children():
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).stop()
			(p as AudioStreamPlayer).stream = null
	Sound.forget()
	# wait in real time (not game time) for the mixer to let them go
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 150:
		await get_tree().process_frame
	get_tree().quit(code)
