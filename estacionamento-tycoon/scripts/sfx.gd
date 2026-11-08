extends Node
## Sons do jogo (autoload "Sfx"): efeitos curtos e ambiente da cidade em loop.

const SOUNDS := {
	"click": "res://assets/sounds/toggle.ogg",
	"buy": "res://assets/sounds/placement-a.ogg",
	"build": "res://assets/sounds/placement-b.ogg",
	"remove": "res://assets/sounds/removal-a.ogg",
	"coin": "res://assets/sounds/coin.ogg",
	"skid": "res://assets/sounds/skid.ogg",
}
const SETTINGS_PATH := "user://settings.json"

var enabled := true
var _streams := {}
var _pool: Array = []
var _ambience: AudioStreamPlayer
var _last_play := {}


func _ready() -> void:
	_load_settings()
	for k in SOUNDS.keys():
		var st = load(SOUNDS[k])
		if st != null:
			_streams[k] = st
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambience = AudioStreamPlayer.new()
	var amb = load("res://assets/sounds/ambience.ogg")
	if amb is AudioStreamOggVorbis:
		amb.loop = true
	_ambience.stream = amb
	_ambience.volume_db = -14.0
	add_child(_ambience)
	_apply()


## Toca um efeito. `min_gap` evita repetir o mesmo som muitas vezes seguidas.
func play(key: String, volume_db: float = -6.0, min_gap: float = 0.08, pitch_jitter: float = 0.08) -> void:
	if not enabled or not _streams.has(key):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(key, -10.0)) < min_gap:
		return
	_last_play[key] = now
	for p in _pool:
		if not p.playing:
			p.stream = _streams[key]
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


func toggle() -> void:
	enabled = not enabled
	_apply()
	_save_settings()


func _apply() -> void:
	if _ambience == null:
		return
	if enabled and not _ambience.playing:
		_ambience.play()
	elif not enabled:
		_ambience.stop()


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(d) == TYPE_DICTIONARY:
			enabled = bool(d.get("sound", true))


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"sound": enabled}))
