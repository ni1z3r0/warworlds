class_name Sound
extends RefCounted
## All the game's audio, as static functions so no autoload is needed (the
## editor can drop autoloads when it rewrites project.godot).
##
##   Sound.play("gun_boom")              one-shot effect (audio/sfx/*.ogg)
##   Sound.loop("rain_loop", true)        start / stop a looping ambience
##   Sound.music("egmont")                cross-fade to a music track (audio/music/*.ogg)
##   Sound.music_for("b1_04")             the music for a chapter (by story id or scene)
##
## The players live on a node parented to the root, so they survive scene
## changes and music carries over between the menu and the storybook.

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const SETTINGS := "user://settings.json"
const FADE := 1.6

static var music_volume := 0.7
static var sfx_volume := 0.9
static var _host: Node
static var _music_a: AudioStreamPlayer
static var _music_b: AudioStreamPlayer
static var _music_id := ""
static var _loops := {}
static var _streams := {}
static var _playing := {}
static var _loaded := false
static var _closing := false
## Our own random numbers, so that playing sounds never disturbs the game's
## random sequence (the autotests depend on it).
static var _rng := RandomNumberGenerator.new()


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _ensure() -> Node:
	if _host != null and is_instance_valid(_host):
		return _host
	_load_settings()
	_make_buses()
	_host = (load("res://scripts/sound_host.gd") as GDScript).new()
	_host.name = "SoundHost"
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _player("Music")
	_music_b = _player("Music")
	_tree().root.add_child.call_deferred(_host)
	return _host


## Quit the game cleanly: silence everything, let the audio server free its
## playbacks over a few frames, then quit. Use instead of get_tree().quit().
static func quit_game(code := 0) -> void:
	if _host == null or not is_instance_valid(_host) or not _host.is_inside_tree():
		_tree().quit(code)
		return
	_host.call("quit_soon", code)


static func is_quitting() -> bool:
	return _closing


## Drop cached streams (called by the host when quitting).
static func forget() -> void:
	_closing = true
	_streams.clear()
	_loops.clear()


static func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	_host.add_child(p)
	return p


static func _make_buses() -> void:
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	_apply_volumes()


static func _apply_volumes() -> void:
	var m := AudioServer.get_bus_index("Music")
	var s := AudioServer.get_bus_index("SFX")
	if m >= 0:
		AudioServer.set_bus_volume_db(m, linear_to_db(maxf(music_volume, 0.0001)))
		AudioServer.set_bus_mute(m, music_volume <= 0.001)
	if s >= 0:
		AudioServer.set_bus_volume_db(s, linear_to_db(maxf(sfx_volume, 0.0001)))
		AudioServer.set_bus_mute(s, sfx_volume <= 0.001)


static func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	_streams[path] = s
	return s


## Start a player once it is in the tree (the host is added deferred).
static func _start(p: AudioStreamPlayer, from := 0.0) -> void:
	if p.is_inside_tree():
		p.play(from)
	else:
		p.play.call_deferred(from)


# ------------------------------------------------------------------ effects

## Random helpers for choosing sounds, on Sound's own generator.
static func chance(p: float) -> bool:
	return _rng.randf() < p


static func rand(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


static func pick(names: Array) -> String:
	return String(names[_rng.randi() % names.size()])


## Play a one-shot effect. `vary` randomises the pitch by up to that fraction.
static func play(sname: String, volume_db := 0.0, vary := 0.06) -> void:
	if _closing:
		return
	_ensure()
	var s := _stream(SFX_DIR + sname + ".ogg")
	if s == null:
		return
	if int(_playing.get(sname, 0)) >= 4:   # don't stack the same sound endlessly
		return
	var p := _player("SFX")
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-vary, vary)
	_playing[sname] = int(_playing.get(sname, 0)) + 1
	p.finished.connect(func() -> void:
		_playing[sname] = maxi(int(_playing.get(sname, 1)) - 1, 0)
		p.queue_free())
	_start(p)


## A one-shot heard from `dist` metres/pixels away: quieter with distance.
static func play_far(sname: String, dist: float, volume_db := 0.0, falloff := 40.0) -> void:
	play(sname, volume_db - clampf(dist / falloff, 0.0, 30.0) * 1.0)


## Play one of several numbered variants: "step_grass" -> step_grass_1 / _2.
static func play_any(base: String, count: int, volume_db := 0.0) -> void:
	play("%s_%d" % [base, _rng.randi_range(1, count)], volume_db, 0.1)


## Start or stop a looping ambience, fading in and out.
static func loop(sname: String, on: bool, volume_db := 0.0) -> void:
	if _closing:
		return
	_ensure()
	if on:
		if _loops.has(sname):
			var q: AudioStreamPlayer = _loops[sname]
			if is_instance_valid(q):
				_fade(q, volume_db, 0.5)
				return
		var s := _stream(SFX_DIR + sname + ".ogg")
		if s == null:
			return
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		var p := _player("SFX")
		p.stream = s
		p.volume_db = -40.0
		_loops[sname] = p
		_start(p, _rng.randf() * maxf(s.get_length() - 0.1, 0.0))
		_fade(p, volume_db, 0.8)
	elif _loops.has(sname):
		var p: AudioStreamPlayer = _loops[sname]
		_loops.erase(sname)
		if is_instance_valid(p):
			_fade(p, -40.0, 0.8, true)


static func loop_volume(sname: String, volume_db: float) -> void:
	if _loops.has(sname) and is_instance_valid(_loops[sname]):
		(_loops[sname] as AudioStreamPlayer).volume_db = volume_db


static func stop_loops() -> void:
	for k in _loops.keys():
		loop(k, false)


static func _fade(p: AudioStreamPlayer, to_db: float, t: float, free_after := false) -> void:
	var tw := _tree().create_tween()
	tw.tween_property(p, "volume_db", to_db, t)
	if free_after:
		tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ music

## Cross-fade to a music track; "" fades the music out.
static func music(id: String) -> void:
	if _closing:
		return
	_ensure()
	if id == _music_id:
		return
	_music_id = id
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_fade(old, -50.0, FADE)
	var tw_stop := _tree().create_tween()
	tw_stop.tween_interval(FADE)
	tw_stop.tween_callback(func() -> void:
		if old != _music_a:
			old.stop())
	if id == "":
		return
	var s := _stream(MUSIC_DIR + id + ".ogg")
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_music_a.stream = s
	_music_a.volume_db = -50.0
	_start(_music_a)
	_fade(_music_a, 0.0, FADE)


static func current_music() -> String:
	return _music_id


## Play the music for a chapter, found by its story id ("b1_04") or scene
## path ("res://scenes/main.tscn"). In the campaign, the current chapter wins
## (several chapters share a scene).
static func music_for(key: String) -> void:
	if CampaignState.active:
		var cur: Dictionary = Story.CHAPTERS[CampaignState.current]
		if cur.get("story", "") == key or cur.get("scene", "") == key:
			music(String(cur.get("music", "")))
			return
	for ch in Story.CHAPTERS:
		if ch.get("story", "") == key or ch.get("scene", "") == key:
			music(String(ch.get("music", "")))
			return


# ------------------------------------------------------------------ settings

static func set_volumes(m: float, s: float) -> void:
	music_volume = clampf(m, 0.0, 1.0)
	sfx_volume = clampf(s, 0.0, 1.0)
	_apply_volumes()
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"music": music_volume, "sfx": sfx_volume}))


static func _load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SETTINGS):
		return
	var f := FileAccess.open(SETTINGS, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		music_volume = float((d as Dictionary).get("music", music_volume))
		sfx_volume = float((d as Dictionary).get("sfx", sfx_volume))
