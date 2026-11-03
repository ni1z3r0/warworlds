extends Node
## Campaign progress (autoload "Progress"). Plays the novel's chapters in
## order, remembers where you are, and saves to user://campaign.json.

const SAVE := "user://campaign.json"

var current := 0          # index into Story.CHAPTERS
var completed := {}       # index -> true
var active := false       # true while a chapter was launched from the story


func _ready() -> void:
	_load()


## Launch chapter `i`: a story scene, an action mode, or (if nothing is
## playable) just the storybook page.
func play(i: int) -> void:
	current = i
	_save()
	var c: Dictionary = Story.CHAPTERS[i]
	active = true
	if c.has("story"):
		get_tree().change_scene_to_file("res://scenes/story_scene.tscn")
	elif c.get("scene", "") != "":
		get_tree().change_scene_to_file(c.scene)
	else:
		active = false


## Called by a chapter when the player finishes it. Opens the storybook at
## the next chapter.
func complete() -> void:
	completed[current] = true
	if current < Story.CHAPTERS.size() - 1:
		current += 1
	active = false
	_save()
	get_tree().change_scene_to_file("res://scenes/campaign.tscn")


func story_id() -> String:
	return Story.CHAPTERS[current].get("story", "")


func is_done(i: int) -> bool:
	return completed.has(i)


func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"current": current, "completed": completed.keys()}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		current = clampi(int(d.get("current", 0)), 0, 999)
		for k in d.get("completed", []):
			completed[int(k)] = true
