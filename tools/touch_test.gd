extends SceneTree
## Feeds real touch events into Chapter I and checks the touch controls work:
##   godot --headless --fixed-fps 60 -s tools/touch_test.gd -- --story=b1_01 --touch

var t := 0.0
var stage := 0
var scene: Node
var x0 := 0.0
var fails := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/story_scene.tscn")


func touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = root.get_final_transform() * p   # game coordinates -> window pixels
	e.pressed = down
	Input.parse_input_event(e)


func drag(i: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = root.get_final_transform() * p
	Input.parse_input_event(e)


func shot(name: String) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(a.substr(8) + "/" + name + ".png")


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _process(delta: float) -> bool:
	t += delta
	scene = current_scene
	if scene == null:
		return false
	match stage:
		0:
			if t > 1.0:
				check(scene.busy.get("kind", "") == "narr", "chapter opens on narration")
				touch(0, Vector2(800, 400), true); touch(0, Vector2(800, 400), false)
				stage = 1
		1:
			if t > 1.5:
				touch(0, Vector2(800, 400), true); touch(0, Vector2(800, 400), false)
				stage = 2
		2:
			if t > 2.0:
				check(scene.busy.is_empty(), "tapping reads on through the narration")
				check(scene.goal_target() != Vector2.INF, "gold marker has a target")
				check(scene.tip().contains("MOVE stick"), "touch tutorial tip shown")
				shot("touch_story_tip")
				var og: Vector2 = scene.npcs["ogilvy"].position
				touch(0, og, true); touch(0, og, false)
				stage = 3
		3:
			if t > 9.0:
				check(scene.step_i >= 2, "tapping Ogilvy walks over and talks to him (step %d)" % scene.step_i)
				# read on through whatever he says
				for k in 4:
					touch(0, Vector2(800, 400), true); touch(0, Vector2(800, 400), false)
				stage = 4
		4:
			if t > 10.0:
				x0 = scene.player.position.x
				touch(1, Vector2(190, 800), true)
				drag(1, Vector2(150, 800))
				stage = 5
		5:
			if t > 11.0:
				shot("touch_story_stick")
				check(scene.player.position.x < x0 - 30.0, "MOVE stick walks the player (%.0f -> %.0f)" % [x0, scene.player.position.x])
				touch(1, Vector2(150, 800), false)
				# the MENU button goes back to the storybook / menu
				touch(2, Vector2(1550, 50), true)
				stage = 6
		6:
			if t > 11.2:
				check(not Input.is_key_pressed(KEY_A), "letting go of the stick stops walking")
				touch(2, Vector2(1550, 50), false)
				stage = 7
		7:
			if t > 12.0:
				check(current_scene != null and current_scene.scene_file_path.ends_with("campaign.tscn"), "MENU button leaves the chapter (%s)" % (current_scene.scene_file_path if current_scene else "none"))
				print("touch test: %d failed" % fails)
				Sound.quit_game(1 if fails > 0 else 0)
				stage = 8
	return false
