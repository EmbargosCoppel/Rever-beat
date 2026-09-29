extends Node2D

class NoteHitData:
	var beat_time: float
	var type: Enums.HitType
	var error: float

	@warning_ignore("shadowed_variable")
	func _init(beat_time: float, type: Enums.HitType, error: float) -> void:
		self.beat_time = beat_time
		self.type = type
		self.error = error

const JUDGMENT_TEXTS: Dictionary = {
	Enums.HitType.MISS_EARLY: "Miss...",
	Enums.HitType.GOOD_EARLY: "Good!",
	Enums.HitType.PERFECT: "Perfect!!",
	Enums.HitType.GOOD_LATE: "Good!",
	Enums.HitType.MISS_LATE: "Miss...",
}

const JUDGMENT_COLORS: Dictionary = {
	Enums.HitType.MISS_EARLY: Color(0.85, 0.25, 0.25),
	Enums.HitType.GOOD_EARLY: Color.DEEP_SKY_BLUE,
	Enums.HitType.PERFECT: Color.GOLD,
	Enums.HitType.GOOD_LATE: Color.DEEP_SKY_BLUE,
	Enums.HitType.MISS_LATE: Color(0.85, 0.25, 0.25),
}

## Time window (in seconds) shown by the playback-position error graph.
const TIME_GRAPH_WINDOW := 6.0
## Error range (in milliseconds) mapped to the full height of the error graphs.
const ERROR_GRAPH_MAX_MS := 40.0
## Maximum number of samples kept for the error graph.
const ERROR_GRAPH_MAX_SAMPLES := 360

var _judgment_tween: Tween
var _hit_data: Array[NoteHitData] = []

# Time graph history, as (timestamp in seconds, error in milliseconds) samples.
var _error_samples: Array[Vector2] = []

@onready var video_background: VideoStreamPlayer = $VideoStreamPlayer
@onready var score_label: Label = $Control/ScoreLabel
@onready var combo_label: Label = $Control/ComboLabel
@onready var accuracy_label: Label = $Control/AccuracyLabel
@onready var progress_bar: ProgressBar = $Control/ProgressBar
@onready var char_portrait: TextureRect = $Control/CharPortrait

## Nodos de depuración/ajustes, ocultos durante la partida (F1 los muestra).
const DEBUG_NODES := ["TutorialLabel", "SettingsVBox", "StatsVBox", "ChartVBox", "ErrorGraphVBox"]

var _score: int = 0
var _combo: int = 0
var _stats: PlayStats
var _debug_visible: bool = false
var _score_mult: float = 1.0
var _combo_shield: bool = false
var _char_tween: Tween

func _enter_tree() -> void:
	$Notes.chart = GlobalSettings.selected_chart


func _ready() -> void:
	_apply_selected_song()
	$Player.bus = &"Music"
	$Metronome.bus = &"SFX"
	BackgroundVideo.apply($VideoStreamPlayer, $BgOverlay)
	_setup_character()
	_setup_hud()
	%ResumeButton.pressed.connect(_on_resume_pressed)
	%RestartButton.pressed.connect(_on_restart_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	$Control/SettingsVBox/UseFilteredCheckBox.button_pressed = GlobalSettings.use_filtered_playback
	$Control/SettingsVBox/ShowOffsetCheckBox.button_pressed = GlobalSettings.show_offsets
	$Control/SettingsVBox/MetronomeCheckBox.button_pressed = GlobalSettings.enable_metronome
	$Control/SettingsVBox/InputLatencyHBox/SpinBox.value = GlobalSettings.input_latency_ms
	$Control/SettingsVBox/ScrollSpeedHBox/CenterContainer/HSlider.value = GlobalSettings.scroll_speed
	$Control/ChartVBox/OptionButton.selected = GlobalSettings.selected_chart
	$Control/JudgmentHBox/LJudgmentLabel.modulate.a = 0
	$Control/JudgmentHBox/RJudgmentLabel.modulate.a = 0

	
	var latency_line_edit: LineEdit = $Control/SettingsVBox/InputLatencyHBox/SpinBox.get_line_edit()
	latency_line_edit.text_submitted.connect(
		func(_text: String) -> void:
			latency_line_edit.release_focus())

	$Notes.time_type = (
			Enums.TimeType.FILTERED if GlobalSettings.use_filtered_playback
			else Enums.TimeType.RAW)

	await get_tree().create_timer(0.5).timeout

	$Conductor.play()
	$Metronome.start()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"restart"):
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed(&"toggle_debug"):
		_toggle_debug()
	_update_progress()
	if _debug_visible:
		_sample_error_graph()
		$Control/ErrorGraphVBox/CenterContainer/TimeGraph.queue_redraw()


func _apply_selected_song() -> void:
	if not GlobalSettings.use_custom_song or GlobalSettings.custom_song_path.is_empty():
		return

	var stream: AudioStream = SongLibrary.load_stream(GlobalSettings.custom_song_path)
	if stream == null:
		push_error("No se pudo cargar la cancion: %s" % GlobalSettings.custom_song_path)
		return

	$Conductor.player.stream = stream

	var chart := SongLibrary.load_custom_chart(GlobalSettings.custom_song_path)
	if chart.has("bpm"):
		$Conductor.bpm = float(chart["bpm"])
		$Conductor.first_beat_offset_ms = int(
				chart.get("offset_ms", GlobalSettings.custom_song_offset_ms))
	else:
		$Conductor.bpm = GlobalSettings.custom_song_bpm
		$Conductor.first_beat_offset_ms = GlobalSettings.custom_song_offset_ms


# --- HUD --------------------------------------------------------------------

func _setup_hud() -> void:
	for node_name: String in DEBUG_NODES:
		$Control.get_node(node_name).visible = false
	score_label.text = "0"
	combo_label.text = ""
	accuracy_label.text = "100.0%"
	progress_bar.value = 0.0
	_update_pause_label()


func _setup_character() -> void:
	var character: Dictionary = Characters.get_selected()
	_score_mult = float(character["score_mult"])
	_combo_shield = bool(character["combo_shield"])
	char_portrait.texture = Characters.load_texture(str(character["texture"]))
	char_portrait.pivot_offset = char_portrait.custom_minimum_size * 0.5


func _react_character(hit_type: Enums.HitType) -> void:
	var perfect: bool = hit_type == Enums.HitType.PERFECT
	var missed: bool = (
			hit_type == Enums.HitType.MISS_EARLY or hit_type == Enums.HitType.MISS_LATE)
	char_portrait.modulate = (
			Color.GOLD if perfect else (Color(1.0, 0.45, 0.45) if missed else Color.WHITE))
	if _char_tween:
		_char_tween.kill()
	char_portrait.scale = Vector2(0.85, 0.85) if missed else Vector2(1.18, 1.18)
	_char_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_char_tween.tween_property(char_portrait, ^"scale", Vector2.ONE, 0.25)


func _toggle_debug() -> void:
	_debug_visible = not _debug_visible
	for node_name: String in DEBUG_NODES:
		$Control.get_node(node_name).visible = _debug_visible


func _update_pause_label() -> void:
	var keys: String = " ".join(Lanes.key_labels(GlobalSettings.lane_count))
	$Control/PauseLabel.text = "PAUSA\n\nTeclas: %s" % keys
	%KeysLabel.text = "Teclas: %s" % keys


func _on_resume_pressed() -> void:
	get_tree().paused = false
	$Control/PauseMenu.visible = false


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://control.tscn")


func _update_score(hit_type: Enums.HitType) -> void:
	match hit_type:
		Enums.HitType.PERFECT:
			_score += int(300 * _score_mult)
			_combo += 1
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			_score += int(100 * _score_mult)
			_combo += 1
		_:
			if not _combo_shield:
				_combo = 0
	score_label.text = str(_score)
	combo_label.text = ("%d" % _combo) if _combo >= 2 else ""


func _update_accuracy() -> void:
	if _stats == null:
		return
	var total: int = _stats.perfect_count + _stats.good_count + _stats.miss_count
	if total <= 0:
		accuracy_label.text = "100.0%"
		return
	var accuracy: float = (_stats.perfect_count + _stats.good_count * 0.6) / float(total)
	accuracy_label.text = "%.1f%%" % (accuracy * 100.0)


func _update_progress() -> void:
	var total_beats: float = _get_total_beats()
	if total_beats <= 0.0:
		return
	var beat: float = $Conductor.get_current_beat()
	progress_bar.value = clampf(beat / total_beats * 100.0, 0.0, 100.0)


# --- Settings ---------------------------------------------------------------

func _on_use_filtered_check_box_toggled(button_pressed: bool) -> void:
	GlobalSettings.use_filtered_playback = button_pressed
	$Notes.time_type = (
			Enums.TimeType.FILTERED if button_pressed else Enums.TimeType.RAW)
	GlobalSettings.save_settings()


func _on_metronome_check_box_toggled(button_pressed: bool) -> void:
	GlobalSettings.enable_metronome = button_pressed
	GlobalSettings.save_settings()


func _on_input_latency_spin_box_value_changed(value: float) -> void:
	GlobalSettings.input_latency_ms = int(value)
	GlobalSettings.save_settings()


func _on_scroll_speed_h_slider_value_changed(value: float) -> void:
	GlobalSettings.scroll_speed = value
	$Control/SettingsVBox/ScrollSpeedHBox/Label.text = str(int(value))
	GlobalSettings.save_settings()


func _on_show_offset_check_box_toggled(button_pressed: bool) -> void:
	GlobalSettings.show_offsets = button_pressed
	GlobalSettings.save_settings()


func _on_chart_option_button_item_selected(index: int) -> void:
	GlobalSettings.selected_chart = index as ChartData.Chart
	GlobalSettings.save_settings()
	get_tree().reload_current_scene()


# --- Play feedback ----------------------------------------------------------

func _on_note_hit(beat: float, hit_type: Enums.HitType, hit_error: float) -> void:
	_hit_data.append(NoteHitData.new(beat, hit_type, hit_error))
	_update_score(hit_type)
	_react_character(hit_type)
	match hit_type:
		Enums.HitType.PERFECT:
			Sfx.play(&"perfect")
		Enums.HitType.GOOD_EARLY, Enums.HitType.GOOD_LATE:
			Sfx.play(&"hit")
		_:
			Sfx.play(&"miss")

	var text: String = JUDGMENT_TEXTS[hit_type]
	if GlobalSettings.show_offsets:
		text += " %+.0f ms" % (hit_error * 1000.0)

	var color: Color = JUDGMENT_COLORS[hit_type]

	var left_label: Label = $Control/JudgmentHBox/LJudgmentLabel
	var right_label: Label = $Control/JudgmentHBox/RJudgmentLabel
	left_label.text = text
	right_label.text = text
	left_label.modulate = color
	right_label.modulate = color

	if _judgment_tween:
		_judgment_tween.kill()
	_judgment_tween = create_tween().set_parallel(true)
	_judgment_tween.tween_property(left_label, ^"modulate:a", 0.0, 0.6)
	_judgment_tween.tween_property(right_label, ^"modulate:a", 0.0, 0.6)

	$Control/ErrorGraphVBox/CenterContainer/JudgmentsGraph.queue_redraw()


func _on_play_stats_updated(play_stats: PlayStats) -> void:
	_stats = play_stats
	_update_accuracy()
	$Control/StatsVBox/PerfectLabel.text = "Perfect: %d" % play_stats.perfect_count
	$Control/StatsVBox/GoodLabel.text = "Good: %d" % play_stats.good_count
	$Control/StatsVBox/MissLabel.text = "Miss: %d" % play_stats.miss_count
	$Control/StatsVBox/HitErrorLabel.text = (
			"Avg Hit Offset: %+.1f ms" % (play_stats.mean_hit_error * 1000.0))


func _on_song_finished(_play_stats: PlayStats) -> void:
	$Control/SongCompleteLabel.visible = true
	$Control/ErrorGraphVBox/CenterContainer/JudgmentsGraph.queue_redraw()


# --- Graphs -----------------------------------------------------------------

func _sample_error_graph() -> void:
	var conductor: Conductor = $Conductor
	var filtered_beat: float = conductor.get_current_beat()
	var raw_beat: float = conductor.get_current_beat_raw()
	var error_ms: float = (
			(filtered_beat - raw_beat) * conductor.get_beat_duration() * 1000.0)
	_error_samples.append(Vector2(Time.get_ticks_msec() / 1000.0, error_ms))
	while _error_samples.size() > ERROR_GRAPH_MAX_SAMPLES:
		_error_samples.remove_at(0)


func _on_time_graph_draw() -> void:
	var graph: Control = $Control/ErrorGraphVBox/CenterContainer/TimeGraph
	var graph_size: Vector2 = graph.size
	if graph_size.x <= 0.0 or graph_size.y <= 0.0:
		return

	var mid_y: float = graph_size.y * 0.5
	graph.draw_line(
			Vector2(0, mid_y), Vector2(graph_size.x, mid_y),
			Color(1, 1, 1, 0.2), 1.0)

	if _error_samples.size() < 2:
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	var start_time: float = now - TIME_GRAPH_WINDOW

	var points := PackedVector2Array()
	for sample: Vector2 in _error_samples:
		if sample.x < start_time:
			continue
		var x: float = (sample.x - start_time) / TIME_GRAPH_WINDOW * graph_size.x
		points.append(Vector2(x, _error_to_y(sample.y, mid_y)))

	if points.size() >= 2:
		graph.draw_polyline(points, Color(1.0, 0.85, 0.3), 2.0, true)


func _on_judgments_graph_draw() -> void:
	var graph: Control = $Control/ErrorGraphVBox/CenterContainer/JudgmentsGraph
	var graph_size: Vector2 = graph.size
	if graph_size.x <= 0.0 or graph_size.y <= 0.0:
		return

	var mid_y: float = graph_size.y * 0.5
	graph.draw_line(
			Vector2(0, mid_y), Vector2(graph_size.x, mid_y),
			Color(1, 1, 1, 0.2), 1.0)

	if _hit_data.is_empty():
		return

	var total_beats: float = maxf(_get_total_beats(), 1.0)

	for hit: NoteHitData in _hit_data:
		var x: float = clampf(hit.beat_time / total_beats, 0.0, 1.0) * graph_size.x
		var y: float = _error_to_y(hit.error * 1000.0, mid_y)
		graph.draw_circle(Vector2(x, y), 2.0, JUDGMENT_COLORS[hit.type])


func _error_to_y(error_ms: float, mid_y: float) -> float:
	var clamped: float = clampf(error_ms, -ERROR_GRAPH_MAX_MS, ERROR_GRAPH_MAX_MS)
	return mid_y - clamped / ERROR_GRAPH_MAX_MS * mid_y


func _get_total_beats() -> float:
	if GlobalSettings.use_custom_song and SongLibrary.has_custom_chart(GlobalSettings.custom_song_path):
		return maxf(SongLibrary.custom_chart_last_beat(GlobalSettings.custom_song_path) + 4.0, 1.0)
	var chart_data: Array[Array] = ChartData.get_chart_data(GlobalSettings.selected_chart)
	return chart_data.size() * 4.0
