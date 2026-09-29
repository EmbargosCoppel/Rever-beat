extends Node

signal scroll_speed_changed(speed: float)

@export var use_filtered_playback: bool = true

@export var enable_metronome: bool = false
@export var input_latency_ms: int = 20

@export var scroll_speed: float = 400:
	set(value):
		if scroll_speed != value:
			scroll_speed = value
			scroll_speed_changed.emit(value)
@export var show_offsets: bool = false

@export var selected_chart: ChartData.Chart = ChartData.Chart.THE_COMEBACK

# Número de carriles/pulsadores (3, 4 o 5) según la dificultad elegida.
@export var lane_count: int = 4

# Índice del personaje elegido (ver Characters.LIST).
@export var selected_character: int = 0

# Canción elegida en el selector de canciones (res:// o user://).
@export var custom_song_path: String = ""
@export var use_custom_song: bool = false
# Tempo/offset usados para la canción elegida (las subidas usan el valor por defecto).
@export var custom_song_bpm: float = 116.052
@export var custom_song_offset_ms: int = 8283

# Volúmenes (0.0 a 1.0) de los buses Master / Music / SFX.
@export var master_volume: float = 1.0
@export var music_volume: float = 1.0
@export var sfx_volume: float = 1.0

# Atajos personalizados. lane_bindings: "<n_carriles>_<carril>" -> keycode.
# pause_key / restart_key a 0 = usar los valores por defecto del proyecto.
var lane_bindings: Dictionary = {}
var pause_key: int = 0
var restart_key: int = 0

var _default_pause_events: Array[InputEvent] = []
var _default_restart_events: Array[InputEvent] = []

const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	_capture_default_events()
	load_settings()
	_apply_extra_bindings()


# --- Atajos ------------------------------------------------------------------

## Guarda una copia de los eventos por defecto de pausa/reiniciar (para poder
## restaurarlos con "Restablecer").
func _capture_default_events() -> void:
	_default_pause_events = _copy_events(&"pause")
	_default_restart_events = _copy_events(&"restart")


func _copy_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	if InputMap.has_action(action):
		for event: InputEvent in InputMap.action_get_events(action):
			events.append(event.duplicate())
	return events


## Aplica los atajos personalizados de pausa/reiniciar guardados.
func _apply_extra_bindings() -> void:
	if pause_key != 0:
		bind_action(&"pause", pause_key)
	if restart_key != 0:
		bind_action(&"restart", restart_key)


## Deja una acción con una única tecla (keycode físico).
func bind_action(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	if keycode == 0:
		return
	var event := InputEventKey.new()
	event.physical_keycode = keycode as Key
	InputMap.action_add_event(action, event)


## Restaura los atajos de pausa/reiniciar por defecto.
func restore_default_events() -> void:
	pause_key = 0
	restart_key = 0
	_replace_events(&"pause", _default_pause_events)
	_replace_events(&"restart", _default_restart_events)


func _replace_events(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


## Carga las preferencias guardadas entre sesiones.
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	use_filtered_playback = config.get_value("game", "use_filtered_playback", use_filtered_playback)
	enable_metronome = config.get_value("game", "enable_metronome", enable_metronome)
	input_latency_ms = int(config.get_value("game", "input_latency_ms", input_latency_ms))
	scroll_speed = float(config.get_value("game", "scroll_speed", scroll_speed))
	show_offsets = config.get_value("game", "show_offsets", show_offsets)
	selected_chart = (
			int(config.get_value("game", "selected_chart", int(selected_chart)))
			as ChartData.Chart)
	lane_count = int(config.get_value("game", "lane_count", lane_count))
	selected_character = int(config.get_value("game", "selected_character", selected_character))
	custom_song_path = str(config.get_value("song", "path", custom_song_path))
	use_custom_song = bool(config.get_value("song", "use_custom", use_custom_song))
	custom_song_bpm = float(config.get_value("song", "bpm", custom_song_bpm))
	custom_song_offset_ms = int(config.get_value("song", "offset_ms", custom_song_offset_ms))
	master_volume = float(config.get_value("audio", "master", master_volume))
	music_volume = float(config.get_value("audio", "music", music_volume))
	sfx_volume = float(config.get_value("audio", "sfx", sfx_volume))
	lane_bindings = config.get_value("input", "lane_bindings", lane_bindings)
	pause_key = int(config.get_value("input", "pause_key", pause_key))
	restart_key = int(config.get_value("input", "restart_key", restart_key))


## Guarda las preferencias en user:// para la próxima sesión.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "use_filtered_playback", use_filtered_playback)
	config.set_value("game", "enable_metronome", enable_metronome)
	config.set_value("game", "input_latency_ms", input_latency_ms)
	config.set_value("game", "scroll_speed", scroll_speed)
	config.set_value("game", "show_offsets", show_offsets)
	config.set_value("game", "selected_chart", int(selected_chart))
	config.set_value("game", "lane_count", lane_count)
	config.set_value("game", "selected_character", selected_character)
	config.set_value("song", "path", custom_song_path)
	config.set_value("song", "use_custom", use_custom_song)
	config.set_value("song", "bpm", custom_song_bpm)
	config.set_value("song", "offset_ms", custom_song_offset_ms)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("input", "lane_bindings", lane_bindings)
	config.set_value("input", "pause_key", pause_key)
	config.set_value("input", "restart_key", restart_key)
	config.save(SETTINGS_PATH)
