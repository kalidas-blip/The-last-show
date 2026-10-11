extends Node
# Autoload "Sfx": sound loading, one-shot and looping players, shared font, haptics.
const NAMES := ["ambience", "musicbox", "heart", "sob", "step", "sting", "scream", "laugh", "stab", "boom", "shing", "click", "pop", "keys", "gate", "riser", "spring"]
const LOOPS := ["ambience", "musicbox", "heart", "sob"]
var snd := {}
var font: Font
var vibe := true

func _ready() -> void:
	font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://bold.ttf"):
		font = load("res://bold.ttf")
	for n in NAMES:
		var s: AudioStreamWAV = load("res://%s.wav" % n)
		if n in LOOPS:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.data.size() * 0.5)
		snd[n] = s

func play(n: String, db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = snd[n]
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p

func play3d(n: String, pos: Vector3, db: float = 0.0, pitch: float = 1.0, unit: float = 8.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = snd[n]
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = unit
	p.max_distance = 140.0
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p

func loop2d(n: String, db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = snd[n]
	p.volume_db = db
	add_child(p)
	p.play()
	return p

func loop3d(n: String, parent: Node3D, db: float = 0.0, unit: float = 8.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = snd[n]
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 90.0
	parent.add_child(p)
	p.play()
	return p

func buzz(ms: int) -> void:
	if vibe:
		Input.vibrate_handheld(ms)
