## Editor de charts: graba las notas pulsando las teclas de carril al ritmo de
## la canción y las guarda por canción. El juego usa ese chart al reproducirla.
extends Control

const SELECT_SCENE := "res://scenes/song_select/song_select.tscn"

@onready var conductor: Conductor = $Conductor
@onready var player: AudioStreamPlayer = $Player
@onready var song_label: Label = %SongLabel
@onready var bpm_spin: SpinBox = %BpmSpin
@onready var offset_spin: SpinBox = %OffsetSpin
@onready var beat_label: Label = %BeatLabel
@onready var info_label: Label = %InfoLabel
@onready var lane_box: HBoxContainer = %LaneBox
@onready var timeline: Control = %Timeline

var _song_path: String = ""
var _lane_count: int = 4
var _recording: bool = false
var _notes: Array = []  # [[beat, lane (1-based)], ...]


func _ready() -> void:
	player.bus = &"Music"
	_song_path = GlobalSettings.custom_song_path
	if _song_path.is_empty():
		var songs := SongLibrary.get_songs()
		if not songs.is_empty():
			_song_path = str(songs[0]["path"])

	_lane_count = clampi(GlobalSettings.lane_count, 3, Lanes.MAX_LANES)
	Lanes.setup_input(_lane_count)
	_build_lane_buttons()

	var stream: AudioStream = SongLibrary.load_stream(_song_path)
	if stream:
		player.stream = stream

	# Timing: del chart guardado, si no del ajuste de la canción, si no por defecto.
	var default_bpm: float = SongLibrary.DEFAULT_BPM
	var default_offset: int = SongLibrary.DEFAULT_OFFSET_MS
	for entry: Dictionary in SongLibrary.get_songs():
		if str(entry["path"]) == _song_path:
			default_bpm = float(entry["bpm"])
			default_offset = int(entry["offset_ms"])
			break

	var chart := SongLibrary.load_custom_chart(_song_path)
	if chart.has("notes"):
		_notes = (chart["notes"] as Array).duplicate()
		bpm_spin.value = float(chart.get("bpm", default_bpm))
		offset_spin.value = float(int(chart.get("offset_ms", default_offset)))
	else:
		bpm_spin.value = default_bpm
		offset_spin.value = float(default_offset)

	song_label.text = "Cancion: %s" % _song_path.get_file().get_basename()
	_apply_timing()
	bpm_spin.value_changed.connect(_on_timing_changed)
	offset_spin.value_changed.connect(_on_timing_changed)

	%RecButton.pressed.connect(_start_recording)
	%StopButton.pressed.connect(_stop_recording)
	%UndoButton.pressed.connect(_undo)
	%ClearButton.pressed.connect(_clear)
	%SaveButton.pressed.connect(_save)
	%BackButton.pressed.connect(_go_back)

	timeline.draw.connect(_draw_timeline)
	_update_info()


func _exit_tree() -> void:
	player.stop()


func _process(_delta: float) -> void:
	beat_label.text = "Beat: %.2f" % conductor.get_current_beat()
	if _recording:
		for lane in range(_lane_count):
			if Input.is_action_just_pressed(Lanes.action_name(lane)):
				_record_lane(lane)
	timeline.queue_redraw()


func _build_lane_buttons() -> void:
	var labels := Lanes.key_labels(_lane_count)
	for lane in range(_lane_count):
		var button := Button.new()
		button.text = labels[lane]
		button.custom_minimum_size = Vector2(72, 44)
		button.pressed.connect(_record_lane.bind(lane))
		lane_box.add_child(button)


func _apply_timing() -> void:
	conductor.bpm = bpm_spin.value
	conductor.first_beat_offset_ms = int(offset_spin.value)


func _on_timing_changed(_value: float) -> void:
	_apply_timing()


func _start_recording() -> void:
	player.stop()
	_apply_timing()
	conductor.play()
	_recording = true
	_update_info()


func _stop_recording() -> void:
	_recording = false
	conductor.stop()
	_update_info()


func _record_lane(lane: int) -> void:
	if not _recording:
		return
	# Se graba el beat real (puede ser negativo durante el count-in).
	var beat: float = conductor.get_current_beat()
	_notes.append([snappedf(beat, 0.001), lane + 1])
	_update_info()


func _undo() -> void:
	if _notes.is_empty():
		return
	_notes.pop_back()
	_update_info()


func _clear() -> void:
	_notes.clear()
	_update_info()


func _save() -> void:
	var ok: bool = SongLibrary.save_custom_chart(
			_song_path, bpm_spin.value, int(offset_spin.value), _notes)
	if not ok:
		info_label.text = "Error al guardar"
	elif _notes.is_empty():
		info_label.text = "Chart borrado (se usara el del demo)"
	else:
		info_label.text = "Guardado: %d notas" % _notes.size()


func _go_back() -> void:
	player.stop()
	get_tree().change_scene_to_file(SELECT_SCENE)


func _update_info() -> void:
	info_label.text = "Notas: %d%s" % [_notes.size(), "   ·   GRABANDO" if _recording else ""]


func _total_beats() -> float:
	var last := 0.0
	for entry: Array in _notes:
		last = maxf(last, float(entry[0]))
	return maxf(last + 4.0, 32.0)


func _lane_color(lane: int) -> Color:
	var hue: float = float(lane) / float(Lanes.MAX_LANES)
	return Color.from_hsv(hue, 0.75, 1.0)


func _draw_timeline() -> void:
	var track_size: Vector2 = timeline.size
	timeline.draw_rect(Rect2(Vector2.ZERO, track_size), Color(0, 0, 0, 0.35), true)
	var total: float = _total_beats()
	for entry: Array in _notes:
		var x: float = clampf(float(entry[0]) / total, 0.0, 1.0) * track_size.x
		timeline.draw_line(
				Vector2(x, 0), Vector2(x, track_size.y), _lane_color(int(entry[1]) - 1), 2.0)
	var playhead_x: float = clampf(conductor.get_current_beat() / total, 0.0, 1.0) * track_size.x
	timeline.draw_line(
			Vector2(playhead_x, 0), Vector2(playhead_x, track_size.y), Color(1, 1, 1, 0.9), 2.0)
