## Menú de opciones: controles (teclas), sonido (volúmenes) y características.
extends Control

const MENU_SCENE := "res://control.tscn"

const DEFAULT_SCROLL_SPEED := 400.0
const DEFAULT_LATENCY := 20
const DEFAULT_LANE_COUNT := 4

@onready var tabs: TabContainer = %Tabs

var _controles_tab: VBoxContainer
var _sonido_tab: VBoxContainer
var _juego_tab: VBoxContainer

var _listening_action: StringName = &""
var _listening_kind: String = ""
var _listening_lane: int = -1


func _ready() -> void:
	_controles_tab = tabs.get_node("Controles")
	_sonido_tab = tabs.get_node("Sonido")
	_juego_tab = tabs.get_node("Juego")
	%BackButton.pressed.connect(_go_back)
	%ResetButton.pressed.connect(_reset_defaults)
	_refresh_all()


func _go_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Construcción de las pestañas -------------------------------------------

func _refresh_all() -> void:
	_build_controls_tab()
	_build_sound_tab()
	_build_game_tab()


func _clear_tab(tab: VBoxContainer) -> void:
	for child: Node in tab.get_children():
		tab.remove_child(child)
		child.queue_free()


func _make_row(label_text: String, label_width: float = 300.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(label_width, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


# --- Pestaña CONTROLES -------------------------------------------------------

func _build_controls_tab() -> void:
	_clear_tab(_controles_tab)
	for lane in range(GlobalSettings.lane_count):
		_add_rebind_row("Carril %d" % (lane + 1), Lanes.action_name(lane), "lane", lane)
	_add_rebind_row("Pausa", &"pause", "pause", -1)
	_add_rebind_row("Reiniciar", &"restart", "restart", -1)
	var hint := Label.new()
	hint.text = "Pulsa el boton de una tecla y luego la tecla nueva (Esc cancela)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controles_tab.add_child(hint)


func _add_rebind_row(label_text: String, action: StringName, kind: String, lane: int) -> void:
	var row := _make_row(label_text, 220.0)
	var button := Button.new()
	button.custom_minimum_size = Vector2(240, 0)
	button.text = _action_key_text(action)
	button.pressed.connect(_start_listening.bind(action, button, kind, lane))
	row.add_child(button)
	_controles_tab.add_child(row)


func _action_keycode(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			return key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	return 0


func _action_key_text(action: StringName) -> String:
	var keycode := _action_keycode(action)
	return "(sin tecla)" if keycode == 0 else OS.get_keycode_string(keycode)


func _start_listening(action: StringName, button: Button, kind: String, lane: int) -> void:
	_listening_action = action
	_listening_kind = kind
	_listening_lane = lane
	button.text = "Pulsa una tecla..."


func _input(event: InputEvent) -> void:
	if _listening_action == &"":
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var keycode: int = key_event.physical_keycode
	if keycode == 0:
		keycode = key_event.keycode
	if keycode == KEY_ESCAPE:
		_listening_action = &""
		_refresh_all()
		get_viewport().set_input_as_handled()
		return
	_apply_binding(_listening_kind, _listening_lane, keycode)
	_listening_action = &""
	_refresh_all()
	get_viewport().set_input_as_handled()


func _apply_binding(kind: String, lane: int, keycode: int) -> void:
	match kind:
		"lane":
			var key := "%d_%d" % [GlobalSettings.lane_count, lane]
			GlobalSettings.lane_bindings[key] = keycode
			Lanes.setup_input(GlobalSettings.lane_count)
		"pause":
			GlobalSettings.pause_key = keycode
			GlobalSettings.bind_action(&"pause", keycode)
		"restart":
			GlobalSettings.restart_key = keycode
			GlobalSettings.bind_action(&"restart", keycode)
	GlobalSettings.save_settings()


# --- Pestaña SONIDO ----------------------------------------------------------

func _build_sound_tab() -> void:
	_clear_tab(_sonido_tab)
	_add_volume_row("Volumen general", "master", GlobalSettings.master_volume)
	_add_volume_row("Musica", "music", GlobalSettings.music_volume)
	_add_volume_row("Efectos", "sfx", GlobalSettings.sfx_volume)


func _add_volume_row(label_text: String, which: String, value: float) -> void:
	var row := _make_row(label_text, 220.0)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(360, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(70, 0)
	value_label.text = "%d%%" % roundi(value * 100.0)
	slider.value_changed.connect(func(new_value: float) -> void:
		_set_volume(which, new_value)
		value_label.text = "%d%%" % roundi(new_value * 100.0))
	row.add_child(slider)
	row.add_child(value_label)
	_sonido_tab.add_child(row)


func _set_volume(which: String, value: float) -> void:
	match which:
		"master":
			GlobalSettings.master_volume = value
		"music":
			GlobalSettings.music_volume = value
		"sfx":
			GlobalSettings.sfx_volume = value
	Sfx.apply_volumes()
	GlobalSettings.save_settings()


# --- Pestaña JUEGO -----------------------------------------------------------

func _build_game_tab() -> void:
	_clear_tab(_juego_tab)

	var speed_row := _make_row("Velocidad de scroll", 300.0)
	var speed_slider := HSlider.new()
	speed_slider.custom_minimum_size = Vector2(320, 0)
	speed_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed_slider.min_value = 200.0
	speed_slider.max_value = 1000.0
	speed_slider.step = 50.0
	speed_slider.value = GlobalSettings.scroll_speed
	var speed_label := Label.new()
	speed_label.custom_minimum_size = Vector2(70, 0)
	speed_label.text = str(int(GlobalSettings.scroll_speed))
	speed_slider.value_changed.connect(func(new_value: float) -> void:
		GlobalSettings.scroll_speed = new_value
		speed_label.text = str(int(new_value))
		GlobalSettings.save_settings())
	speed_row.add_child(speed_slider)
	speed_row.add_child(speed_label)
	_juego_tab.add_child(speed_row)

	var latency_row := _make_row("Latencia de entrada (ms)", 300.0)
	var latency_spin := SpinBox.new()
	latency_spin.min_value = -100.0
	latency_spin.max_value = 1000.0
	latency_spin.rounded = true
	latency_spin.value = GlobalSettings.input_latency_ms
	latency_spin.value_changed.connect(func(new_value: float) -> void:
		GlobalSettings.input_latency_ms = int(new_value)
		GlobalSettings.save_settings())
	latency_row.add_child(latency_spin)
	_juego_tab.add_child(latency_row)

	_add_check_row("Metronomo", GlobalSettings.enable_metronome, func(pressed: bool) -> void:
		GlobalSettings.enable_metronome = pressed
		GlobalSettings.save_settings())
	_add_check_row("Suavizar posicion (filtro)", GlobalSettings.use_filtered_playback, func(pressed: bool) -> void:
		GlobalSettings.use_filtered_playback = pressed
		GlobalSettings.save_settings())
	_add_check_row("Mostrar offset al juzgar", GlobalSettings.show_offsets, func(pressed: bool) -> void:
		GlobalSettings.show_offsets = pressed
		GlobalSettings.save_settings())

	var difficulty_row := _make_row("Dificultad (n.o de carriles)", 300.0)
	var difficulty_option := OptionButton.new()
	difficulty_option.custom_minimum_size = Vector2(200, 0)
	for difficulty_name: String in Lanes.DIFFICULTY_NAMES:
		difficulty_option.add_item(difficulty_name)
	var index: int = Lanes.DIFFICULTY_LANES.find(GlobalSettings.lane_count)
	difficulty_option.selected = index if index >= 0 else 1
	difficulty_option.item_selected.connect(func(selected: int) -> void:
		GlobalSettings.lane_count = Lanes.DIFFICULTY_LANES[selected]
		GlobalSettings.save_settings()
		_refresh_all())
	difficulty_row.add_child(difficulty_option)
	_juego_tab.add_child(difficulty_row)


func _add_check_row(label_text: String, pressed: bool, on_change: Callable) -> void:
	var row := _make_row(label_text, 300.0)
	var check := CheckBox.new()
	check.button_pressed = pressed
	check.toggled.connect(on_change)
	row.add_child(check)
	_juego_tab.add_child(row)


# --- Restablecer -------------------------------------------------------------

func _reset_defaults() -> void:
	GlobalSettings.scroll_speed = DEFAULT_SCROLL_SPEED
	GlobalSettings.input_latency_ms = DEFAULT_LATENCY
	GlobalSettings.enable_metronome = false
	GlobalSettings.use_filtered_playback = true
	GlobalSettings.show_offsets = false
	GlobalSettings.lane_count = DEFAULT_LANE_COUNT
	GlobalSettings.master_volume = 1.0
	GlobalSettings.music_volume = 1.0
	GlobalSettings.sfx_volume = 1.0
	GlobalSettings.lane_bindings.clear()
	GlobalSettings.restore_default_events()
	Lanes.setup_input(GlobalSettings.lane_count)
	Sfx.apply_volumes()
	GlobalSettings.save_settings()
	_refresh_all()