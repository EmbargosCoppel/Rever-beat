## Lists the available songs (built-in + user-imported) and loads their audio.
class_name SongLibrary

## Folder where user-imported songs are copied so they persist between runs.
const USER_SONG_DIR := "user://songs"
## Audio file extensions we know how to play.
const AUDIO_EXTENSIONS := ["ogg", "mp3", "wav"]

## Songs that ship with the game. bpm/offset_ms describe the chart timing.
const BUILTIN_SONGS: Array[Dictionary] = [
	{
		"name": "The Comeback",
		"path": "res://music/the_comeback2.ogg",
		"bpm": 116.052,
		"offset_ms": 8283,
	},
]

## Fallback timing for user songs (which have no beatmap) so they still play.
const DEFAULT_BPM := 116.052
const DEFAULT_OFFSET_MS := 8283

## Where per-song BPM/offset tweaks set by the player are persisted.
const SETTINGS_PATH := "user://song_settings.cfg"


## Returns every available song as a dictionary:
## { name: String, path: String, bpm: float, offset_ms: int, builtin: bool }.
static func get_songs() -> Array[Dictionary]:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)

	var songs: Array[Dictionary] = []

	for builtin: Dictionary in BUILTIN_SONGS:
		var builtin_entry: Dictionary = builtin.duplicate()
		builtin_entry["builtin"] = true
		_apply_saved_timing(builtin_entry, config)
		songs.append(builtin_entry)

	DirAccess.make_dir_recursive_absolute(USER_SONG_DIR)
	var file_names := DirAccess.get_files_at(USER_SONG_DIR)
	file_names.sort()
	for file_name: String in file_names:
		if not AUDIO_EXTENSIONS.has(file_name.get_extension().to_lower()):
			continue
		var user_entry: Dictionary = {
			"name": file_name.get_basename(),
			"path": USER_SONG_DIR.path_join(file_name),
			"bpm": DEFAULT_BPM,
			"offset_ms": DEFAULT_OFFSET_MS,
			"builtin": false,
		}
		_apply_saved_timing(user_entry, config)
		songs.append(user_entry)

	return songs


## Overwrites a song entry's bpm/offset with values the player saved earlier.
static func _apply_saved_timing(entry: Dictionary, config: ConfigFile) -> void:
	var path: String = entry["path"]
	if not config.has_section(path):
		return
	entry["bpm"] = float(config.get_value(path, "bpm", entry["bpm"]))
	entry["offset_ms"] = int(config.get_value(path, "offset_ms", entry["offset_ms"]))


## Persists the BPM/offset the player set for a song in the selector.
static func save_song_timing(path: String, bpm: float, offset_ms: int) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(path, "bpm", bpm)
	config.set_value(path, "offset_ms", offset_ms)
	config.save(SETTINGS_PATH)


## Copies a song chosen by the player into the persistent user folder.
## Returns the destination path, or "" on failure.
static func import_song(source_path: String) -> String:
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		push_error("SongLibrary: el archivo no existe: %s" % source_path)
		return ""

	DirAccess.make_dir_recursive_absolute(USER_SONG_DIR)
	var destination := USER_SONG_DIR.path_join(source_path.get_file())
	var err := DirAccess.copy_absolute(source_path, destination)
	if err != OK:
		push_error("SongLibrary: no se pudo copiar %s (error %d)" % [source_path, err])
		return ""

	return destination


## Loads an AudioStream from a res:// or user:// path. Returns null on failure.
static func load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null

	if path.begins_with("res://"):
		var resource: Resource = ResourceLoader.load(path)
		if resource is AudioStream:
			return resource as AudioStream

	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
		_:
			push_error("SongLibrary: formato de audio no soportado: %s" % path)
			return null


# --- Charts personalizados ---------------------------------------------------

## Carpeta donde se guardan los charts creados por el jugador.
const USER_CHART_DIR := "user://charts"


## Ruta del archivo de chart para una canción.
static func chart_path(song_path: String) -> String:
	var id: String = song_path.get_file().get_basename().validate_filename()
	return USER_CHART_DIR.path_join(id + ".json")


## ¿Existe un chart personalizado para esta canción?
static func has_custom_chart(song_path: String) -> bool:
	return not song_path.is_empty() and FileAccess.file_exists(chart_path(song_path))


## Carga el chart personalizado: { bpm, offset_ms, notes: [[beat, lane], ...] }.
static func load_custom_chart(song_path: String) -> Dictionary:
	if not has_custom_chart(song_path):
		return {}
	var file: FileAccess = FileAccess.open(chart_path(song_path), FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}


## Guarda el chart. Si [param notes] está vacío, borra el chart (vuelve al demo).
static func save_custom_chart(song_path: String, bpm: float, offset_ms: int, notes: Array) -> bool:
	if notes.is_empty():
		return delete_custom_chart(song_path)
	DirAccess.make_dir_recursive_absolute(USER_CHART_DIR)
	var file: FileAccess = FileAccess.open(chart_path(song_path), FileAccess.WRITE)
	if file == null:
		push_error("SongLibrary: no se pudo guardar el chart de %s" % song_path)
		return false
	file.store_string(JSON.stringify({"bpm": bpm, "offset_ms": offset_ms, "notes": notes}))
	return true


## Borra el chart personalizado de una canción.
static func delete_custom_chart(song_path: String) -> bool:
	var path := chart_path(song_path)
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path) == OK
	return true


## Último beat de un chart personalizado (o 0 si no hay).
static func custom_chart_last_beat(song_path: String) -> float:
	var chart := load_custom_chart(song_path)
	if not chart.has("notes"):
		return 0.0
	var last := 0.0
	for entry: Array in chart["notes"]:
		last = maxf(last, float(entry[0]))
	return last
