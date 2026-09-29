## Pantalla de selección de canción con vista previa al pasar el cursor.
extends Control

const GAME_SCENE_PATH := "res://scenes/main/main.tscn"
const MENU_SCENE_PATH := "res://control.tscn"
const EDITOR_SCENE_PATH := "res://scenes/chart_editor/chart_editor.tscn"

@onready var song_list: ItemList = %SongsList
@onready var preview_player: AudioStreamPlayer = %PreviewPlayer
@onready var file_dialog: FileDialog = %FileDialog
@onready var now_playing_label: Label = %NowPlayingLabel
@onready var bpm_spin: SpinBox = %BpmSpin
@onready var offset_spin: SpinBox = %OffsetSpin
@onready var difficulty_option: OptionButton = %DifficultyOption
@onready var keys_label: Label = %KeysLabel
@onready var tap_button: Button = %TapButton

## Vista previa: se empieza a esta altura (segundos) para saltar intros largas.
const PREVIEW_START_SECONDS := 30.0

var _songs: Array[Dictionary] = []
var _hovered_index: int = -1
var _selected_index: int = -1
var _updating_timing: bool = false
var _tap_times: PackedFloat64Array = []


func _ready() -> void:
	preview_player.bus = &"Music"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.mp3, *.ogg, *.wav ; Archivos de Audio", "Audio")
	file_dialog.file_selected.connect(_on_audio_file_selected)

	song_list.item_selected.connect(_on_song_selected)
	song_list.item_activated.connect(_on_song_activated)

	%PlayButton.pressed.connect(_on_play_pressed)
	%AddButton.pressed.connect(_on_add_pressed)
	%EditButton.pressed.connect(_on_edit_pressed)
	%BackButton.pressed.connect(_on_back_pressed)

	bpm_spin.value_changed.connect(_on_timing_changed)
	offset_spin.value_changed.connect(_on_timing_changed)
	tap_button.pressed.connect(_on_tap_pressed)

	difficulty_option.item_selected.connect(_on_difficulty_selected)
	_populate_difficulty()

	BackgroundVideo.apply($VideoStreamPlayer, $Background)

	_populate()


func _populate_difficulty() -> void:
	for difficulty_name: String in Lanes.DIFFICULTY_NAMES:
		difficulty_option.add_item(difficulty_name)
	var index: int = Lanes.DIFFICULTY_LANES.find(GlobalSettings.lane_count)
	difficulty_option.selected = index if index >= 0 else 1
	_update_keys_label()


func _on_difficulty_selected(index: int) -> void:
	GlobalSettings.lane_count = Lanes.DIFFICULTY_LANES[index]
	_update_keys_label()
	GlobalSettings.save_settings()


func _update_keys_label() -> void:
	keys_label.text = "Teclas: " + " ".join(Lanes.key_labels(GlobalSettings.lane_count))


func _process(_delta: float) -> void:
	# Si la ventana no tiene el foco, ignoramos el hover: así no se reproducen
	# muestras al pasar el cursor por encima de otras ventanas.
	if not get_window().has_focus():
		if _hovered_index != -1:
			_hovered_index = -1
			preview_player.stop()
			_restore_selection_label()
		return

	# ItemList no emite señales de hover, así que detectamos el cambio a mano.
	# get_item_at_position con exact=true devuelve -1 si el cursor no está sobre
	# ningún ítem (o está fuera del control).
	var mouse_pos: Vector2 = song_list.get_local_mouse_position()
	var index: int = song_list.get_item_at_position(mouse_pos, true)
	if index != _hovered_index:
		_hovered_index = index
		_update_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_hovered_index = -1
		if is_instance_valid(preview_player):
			preview_player.stop()
		if is_instance_valid(now_playing_label):
			_restore_selection_label()


func _populate() -> void:
	_songs = SongLibrary.get_songs()
	song_list.clear()
	for song: Dictionary in _songs:
		var label: String = str(song["name"])
		if not bool(song["builtin"]):
			label += "   (subida)"
		song_list.add_item(label)

	# Preselecciona la canción configurada actualmente, si la hay.
	_selected_index = -1
	for i in range(_songs.size()):
		if str(_songs[i]["path"]) == GlobalSettings.custom_song_path:
			_selected_index = i
			break

	if _selected_index >= 0:
		song_list.select(_selected_index)
		_restore_selection_label()
	else:
		now_playing_label.text = "Elige una cancion y pulsa JUGAR."


func _on_song_selected(index: int) -> void:
	if index < 0 or index >= _songs.size():
		return
	_selected_index = index

	# Cargamos en los controles el BPM/offset guardados de esta canción.
	_tap_times.clear()
	var song: Dictionary = _songs[index]
	_updating_timing = true
	bpm_spin.value = float(song["bpm"])
	offset_spin.value = float(song["offset_ms"])
	_updating_timing = false

	# No tocamos la etiqueta aquí: mientras el cursor esté encima mostrará
	# "Escuchando: ..." y al salir se restaurará el texto de selección.
	if _hovered_index < 0:
		_restore_selection_label()


func _on_timing_changed(_value: float) -> void:
	if _updating_timing or _selected_index < 0 or _selected_index >= _songs.size():
		return
	var song: Dictionary = _songs[_selected_index]
	song["bpm"] = bpm_spin.value
	song["offset_ms"] = int(offset_spin.value)
	SongLibrary.save_song_timing(str(song["path"]), float(song["bpm"]), int(song["offset_ms"]))
	GlobalSettings.save_settings()


## Estima el BPM a partir de toques repetidos (tap-tempo).
func _on_tap_pressed() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	# Reinicia el conteo si pasa mucho tiempo entre toques.
	if not _tap_times.is_empty() and now - _tap_times[-1] > 2.0:
		_tap_times.clear()
	_tap_times.append(now)
	while _tap_times.size() > 9:
		_tap_times.remove_at(0)
	if _tap_times.size() < 2:
		return
	var average_interval: float = (_tap_times[-1] - _tap_times[0]) / (_tap_times.size() - 1)
	if average_interval <= 0.0:
		return
	bpm_spin.value = snappedf(60.0 / average_interval, 0.001)


func _on_song_activated(index: int) -> void:
	_selected_index = index
	_start_game()


func _update_preview() -> void:
	preview_player.stop()
	if _hovered_index < 0 or _hovered_index >= _songs.size():
		_restore_selection_label()
		return
	var stream: AudioStream = SongLibrary.load_stream(str(_songs[_hovered_index]["path"]))
	if stream == null:
		_restore_selection_label()
		return
	preview_player.stream = stream
	var start_pos: float = minf(PREVIEW_START_SECONDS, stream.get_length() * 0.5)
	preview_player.play(start_pos)
	now_playing_label.text = "Escuchando: %s" % _short_name(str(_songs[_hovered_index]["name"]))


func _restore_selection_label() -> void:
	if _selected_index >= 0 and _selected_index < _songs.size():
		now_playing_label.text = "Seleccionada: %s" % _short_name(
				str(_songs[_selected_index]["name"]))
	else:
		now_playing_label.text = "Elige una cancion y pulsa JUGAR."


## Recorta nombres largos para que la etiqueta nunca cambie de tamaño.
func _short_name(song_name: String) -> String:
	const MAX_LENGTH := 46
	if song_name.length() <= MAX_LENGTH:
		return song_name
	return song_name.substr(0, MAX_LENGTH - 1) + "…"


func _on_play_pressed() -> void:
	_start_game()


func _on_add_pressed() -> void:
	file_dialog.popup_centered(Vector2(800, 500))


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _on_audio_file_selected(path: String) -> void:
	var destination: String = SongLibrary.import_song(path)
	if destination.is_empty():
		now_playing_label.text = "No se pudo anadir la cancion."
		return
	GlobalSettings.custom_song_path = destination
	GlobalSettings.use_custom_song = true
	GlobalSettings.save_settings()
	_populate()
	now_playing_label.text = "Cancion anadida: %s" % _short_name(destination.get_file().get_basename())


func _on_edit_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _songs.size():
		now_playing_label.text = "Elige una cancion primero."
		return
	var song: Dictionary = _songs[_selected_index]
	GlobalSettings.custom_song_path = str(song["path"])
	GlobalSettings.use_custom_song = true
	GlobalSettings.custom_song_bpm = float(song["bpm"])
	GlobalSettings.custom_song_offset_ms = int(song["offset_ms"])
	GlobalSettings.save_settings()
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)


func _start_game() -> void:
	if _selected_index < 0 or _selected_index >= _songs.size():
		now_playing_label.text = "Elige una cancion primero."
		return
	var song: Dictionary = _songs[_selected_index]
	GlobalSettings.custom_song_path = str(song["path"])
	GlobalSettings.use_custom_song = true
	GlobalSettings.custom_song_bpm = float(song["bpm"])
	GlobalSettings.custom_song_offset_ms = int(song["offset_ms"])
	GlobalSettings.save_settings()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _exit_tree() -> void:
	preview_player.stop()
