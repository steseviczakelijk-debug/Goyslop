extends Node
## Plays sound effects from a small pool of players, and the looping music.
## Rapid-fire sounds are throttled so a big battle does not turn into noise.

const NAMES := ["shoot", "hit", "kill", "lost", "grow", "gate_good", "gate_bad", "stomp", "boss_dead", "coin", "click", "win", "lose"]
const VOICES := 10

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var last_played := {}
var music: AudioStreamPlayer
var clock := 0.0


func _ready() -> void:
	for bus in ["Music", "SFX"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for n in NAMES:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	var track: AudioStreamWAV = load("res://assets/audio/music.wav")
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = int(track.get_length() * track.mix_rate)
	music = AudioStreamPlayer.new()
	music.stream = track
	music.bus = "Music"
	music.volume_db = -16.0
	add_child(music)


func _process(dt: float) -> void:
	clock += dt


## Plays `sound` unless it was played less than `gap` seconds ago.
func play(sound: String, volume_db := 0.0, gap := 0.0, pitch_spread := 0.08) -> void:
	if clock - float(last_played.get(sound, -10.0)) < gap:
		return
	last_played[sound] = clock
	var p := players[next_voice]
	next_voice = (next_voice + 1) % VOICES
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.play()


func start_music() -> void:
	if not music.playing:
		music.play()
	music.volume_db = -16.0


## Lowers the music so a win or lose jingle can be heard over it.
func duck_music() -> void:
	music.volume_db = -30.0


## Volumes run from 0 (silent) to 1 (full).
func set_volumes(music_volume: float, sfx_volume: float) -> void:
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func _set_bus(bus: String, volume: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(idx, volume <= 0.01)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.01)))
