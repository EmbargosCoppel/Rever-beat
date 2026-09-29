## Efectos de sonido generados en código (no requieren archivos de audio).
## Se registra como autoload "Sfx". Uso: Sfx.play("hit").
extends Node

const MIX_RATE := 22050
const VOICES := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	_ensure_buses()

	_streams["perfect"] = _make_tone(1320.0, 0.07, 0.5, "sine")
	_streams["hit"] = _make_tone(880.0, 0.06, 0.45, "sine")
	_streams["miss"] = _make_tone(150.0, 0.16, 0.5, "square")
	_streams["click"] = _make_tone(660.0, 0.035, 0.35, "sine")

	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)

	apply_volumes()


## Crea los buses "Music" y "SFX" si no existen todavía.
func _ensure_buses() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


## Aplica los volúmenes guardados a los buses.
func apply_volumes() -> void:
	_set_bus_volume("Master", GlobalSettings.master_volume)
	_set_bus_volume("Music", GlobalSettings.music_volume)
	_set_bus_volume("SFX", GlobalSettings.sfx_volume)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))


## Reproduce un efecto por nombre ("perfect", "hit", "miss", "click").
func play(sound: StringName) -> void:
	if not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.play()


## Crea un tono corto con envolvente de caída, en formato WAV 16-bit mono.
func _make_tone(frequency: float, duration: float, volume: float, waveform: String) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var time := float(i) / MIX_RATE
		var envelope := 1.0 - float(i) / sample_count
		var sample := 0.0
		if waveform == "square":
			sample = 1.0 if fmod(frequency * time, 1.0) < 0.5 else -1.0
		else:
			sample = sin(TAU * frequency * time)
		var value := int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
