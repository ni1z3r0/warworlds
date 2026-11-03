class_name CampaignState
extends RefCounted
## Campaign progress: plays the novel's chapters in order, remembers where
## you are, and saves to user://campaign.json.
##
## Static, so it works without registering an autoload in project.godot.

const SAVE := "user://campaign.json"

static var current := 0          # index into Story.CHAPTERS
static var completed := {}       # index -> true
static var active := false       # true while a chapter was launched from the story
static var _loaded := false


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _ensure() -> void:
	if not _loaded:
		_loaded = true
		_load()


static func get_current() -> int:
	_ensure()
	return current


## Launch chapter `i`: a story scene, an action mode, or nothing (read only).
static func play(i: int) -> void:
	_ensure()
	current = i
	_save()
	var c: Dictionary = Story.CHAPTERS[i]
	active = true
	if c.has("story"):
		_tree().change_scene_to_file("res://scenes/story_scene.tscn")
	elif c.get("scene", "") != "":
		_tree().change_scene_to_file(c.scene)
	else:
		active = false


## Called when the player finishes a chapter: opens the storybook at the next one.
static func complete() -> void:
	_ensure()
	completed[current] = true
	if current < Story.CHAPTERS.size() - 1:
		current += 1
	active = false
	_save()
	_tree().change_scene_to_file("res://scenes/campaign.tscn")


static func story_id() -> String:
	_ensure()
	return Story.CHAPTERS[clampi(current, 0, Story.CHAPTERS.size() - 1)].get("story", "")


static func is_done(i: int) -> bool:
	_ensure()
	return completed.has(i)


static func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"current": current, "completed": completed.keys()}))


static func _load() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		current = clampi(int(d.get("current", 0)), 0, Story.CHAPTERS.size() - 1)
		for k in d.get("completed", []):
			completed[int(k)] = true
