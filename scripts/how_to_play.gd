extends Control
## The menu's HOW TO PLAY page: every mode's card, one after another.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.02, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var h := HowTo.new()
	h.modal = false
	h.pages = HowTo.ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="):
			h.page = int(a.substr(7))
	h.on_close = func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn")
	add_child(h)
	Touch.layout({"buttons": []})
	# the first-time cards will show again
	HowTo.reset_seen()
	_shots()


func _shots() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			for k in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(a.substr(8) + "/how_to_play.png")
			get_tree().quit()
