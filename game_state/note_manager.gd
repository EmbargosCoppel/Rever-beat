class_name NoteManager
extends Node2D

signal play_stats_updated(play_stats: PlayStats)
signal note_hit(beat: float, hit_type: Enums.HitType, hit_error: float)
signal song_finished(play_stats: PlayStats)

const NOTE_SCENE = preload("res://objects/note/note.tscn")
const GUIDE_SCENE = preload("res://objects/guide/guide.tscn")
const HIT_MARGIN_PERFECT = 0.050
const HIT_MARGIN_GOOD = 0.150
const HIT_MARGIN_MISS = 0.300

@export var conductor: Conductor
@export var time_type: Enums.TimeType = Enums.TimeType.FILTERED
@export var chart: ChartData.Chart = ChartData.Chart.THE_COMEBACK

var _notes: Array[Note] = []
var _guides: Array[Guide] = []
var _lane_count: int = 4
var _last_touch_ms: int = 0
var _margin_perfect: float = HIT_MARGIN_PERFECT
var _margin_good: float = HIT_MARGIN_GOOD
var _margin_miss: float = HIT_MARGIN_MISS

var _play_stats: PlayStats
var _hit_error_acc: float = 0.0
var _hit_count: int = 0


func _ready() -> void:
	_play_stats = PlayStats.new()
	_play_stats.changed.connect(
			func() -> void:
				play_stats_updated.emit(_play_stats)
				)

	_lane_count = clampi(GlobalSettings.lane_count, 3, Lanes.MAX_LANES)
	Lanes.setup_input(_lane_count)
	_create_guides()

	# El personaje elegido puede ampliar o reducir la ventana de acierto.
	var window_mult: float = float(Characters.get_selected()["hit_window_mult"])
	_margin_perfect = HIT_MARGIN_PERFECT * window_mult
	_margin_good = HIT_MARGIN_GOOD * window_mult
	_margin_miss = HIT_MARGIN_MISS * window_mult

	var custom_chart := {}
	if GlobalSettings.use_custom_song:
		custom_chart = SongLibrary.load_custom_chart(GlobalSettings.custom_song_path)
	if custom_chart.has("notes"):
		_build_notes_from_custom(custom_chart["notes"])
	else:
		_build_notes_from_chart_data()


func _process(_delta: float) -> void:
	if _notes.is_empty():
		return

	var curr_beat := _get_curr_beat()
	for i in range(_notes.size()):
		_notes[i].update_beat(curr_beat)

	_miss_old_notes()

	for lane in range(_lane_count):
		if Input.is_action_just_pressed(Lanes.action_name(lane)):
			_handle_lane_press(lane)

	if _notes.is_empty():
		_finish_song()


func _miss_old_notes() -> void:
	while not _notes.is_empty():
		var note := _notes[0] as Note
		var note_delta := _get_note_delta(note)

		if note_delta > _margin_good:
			# Time is past the note's hit window, miss.
			note.miss(false)
			_notes.remove_at(0)
			_play_stats.miss_count += 1
			note_hit.emit(note.beat, Enums.HitType.MISS_LATE, note_delta)
		else:
			# Note is still hittable, so stop checking rest of the (later)
			# notes.
			break


func _create_guides() -> void:
	for lane in range(_lane_count):
		var guide := GUIDE_SCENE.instantiate() as Guide
		guide.position = Vector2(Lanes.lane_offset(lane, _lane_count), 0)
		guide.action = Lanes.action_name(lane)
		guide.z_index = -1
		add_child(guide)
		_guides.append(guide)


# --- Entrada táctil / ratón --------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var touch_position := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		_last_touch_ms = Time.get_ticks_msec()
		touch_position = event.position
		pressed = true
	elif (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		# En móvil un toque también genera un clic emulado: ignóralo.
		if Time.get_ticks_msec() - _last_touch_ms < 200:
			return
		touch_position = event.position
		pressed = true
	if not pressed or touch_position.y < 200.0:
		return
	var lane := _lane_from_x(touch_position.x)
	if lane >= 0:
		_handle_lane_press(lane)
		if lane < _guides.size():
			_guides[lane].flash()


## Devuelve el carril cuyo centro está más cerca de la X tocada (o -1).
func _lane_from_x(x: float) -> int:
	var best := -1
	var best_dist := INF
	for lane in range(_lane_count):
		var lane_x: float = position.x + Lanes.lane_offset(lane, _lane_count)
		var dist: float = absf(x - lane_x)
		if dist < best_dist:
			best_dist = dist
			best = lane
	if best_dist <= Lanes.SPACING * 0.75:
		return best
	return -1


## Construye las notas desde el chart del demo.
func _build_notes_from_chart_data() -> void:
	var chart_data := ChartData.get_chart_data(chart)
	for measure_i in range(chart_data.size()):
		var measure: Array = chart_data[measure_i]
		var subdivision := 1.0 / measure.size() * 4
		for note_i: int in range(measure.size()):
			var lane_value: int = measure[note_i]
			if lane_value <= 0:
				continue
			_spawn_note(measure_i * 4 + note_i * subdivision, lane_value)


## Construye las notas desde un chart personalizado: [[beat, lane], ...].
func _build_notes_from_custom(notes: Array) -> void:
	var sorted_notes := notes.duplicate()
	sorted_notes.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for entry: Array in sorted_notes:
		_spawn_note(float(entry[0]), int(entry[1]))


func _spawn_note(beat: float, lane_value: int) -> void:
	var lane := (lane_value - 1) % _lane_count
	var note := NOTE_SCENE.instantiate() as Note
	note.beat = beat
	note.lane = lane
	note.x_offset = Lanes.lane_offset(lane, _lane_count)
	note.conductor = conductor
	note.update_beat(-100)
	add_child(note)
	_notes.append(note)


## Handles a press on a given lane: judges the earliest note in that lane.
func _handle_lane_press(lane: int) -> void:
	for i in range(_notes.size()):
		var note := _notes[i]
		if note.lane != lane:
			continue
		var hit_delta := _get_note_delta(note)
		if hit_delta < -_margin_miss:
			# The earliest note in this lane is still too far away; ignore.
			return
		_judge_note(note, i, hit_delta)
		return


func _judge_note(note: Note, index: int, hit_delta: float) -> void:
	if -_margin_perfect <= hit_delta and hit_delta <= _margin_perfect:
		# Hit on time, perfect.
		note.hit_perfect()
		_notes.remove_at(index)
		_hit_error_acc += hit_delta
		_hit_count += 1
		_play_stats.perfect_count += 1
		_play_stats.mean_hit_error = _hit_error_acc / _hit_count
		note_hit.emit(note.beat, Enums.HitType.PERFECT, hit_delta)
	elif -_margin_good <= hit_delta and hit_delta <= _margin_good:
		# Hit slightly off time, good.
		note.hit_good()
		_notes.remove_at(index)
		_hit_error_acc += hit_delta
		_hit_count += 1
		_play_stats.good_count += 1
		_play_stats.mean_hit_error = _hit_error_acc / _hit_count
		if hit_delta < 0:
			note_hit.emit(note.beat, Enums.HitType.GOOD_EARLY, hit_delta)
		else:
			note_hit.emit(note.beat, Enums.HitType.GOOD_LATE, hit_delta)
	elif -_margin_miss <= hit_delta and hit_delta <= _margin_miss:
		# Hit way off time, miss.
		note.miss()
		_notes.remove_at(index)
		_hit_error_acc += hit_delta
		_hit_count += 1
		_play_stats.miss_count += 1
		_play_stats.mean_hit_error = _hit_error_acc / _hit_count
		if hit_delta < 0:
			note_hit.emit(note.beat, Enums.HitType.MISS_EARLY, hit_delta)
		else:
			note_hit.emit(note.beat, Enums.HitType.MISS_LATE, hit_delta)


func _finish_song() -> void:
	song_finished.emit(_play_stats)


func _get_note_delta(note: Note) -> float:
	var curr_beat := _get_curr_beat()
	var beat_delta := curr_beat - note.beat
	return beat_delta * conductor.get_beat_duration()


func _get_curr_beat() -> float:
	var curr_beat: float
	match time_type:
		Enums.TimeType.FILTERED:
			curr_beat = conductor.get_current_beat()
		Enums.TimeType.RAW:
			curr_beat = conductor.get_current_beat_raw()
		_:
			assert(false, "Unknown TimeType: %s" % time_type)
			curr_beat = conductor.get_current_beat()

	# Adjust the timing for input delay. While this will shift the note
	# positions such that "on time" does not line up visually with the guide
	# sprite, the resulting visual is a lot smoother compared to readjusting the
	# note position after hitting it.
	curr_beat -= GlobalSettings.input_latency_ms / 1000.0 / conductor.get_beat_duration()

	return curr_beat
