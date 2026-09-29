## Pruebas unitarias de la lógica del juego (sin depender de la UI).
extends Node


func test_lanes_difficulty_mapping() -> void:
	assert(Lanes.DIFFICULTY_LANES == [3, 4, 5], "Las dificultades deben ser 3/4/5")


func test_lanes_action_names() -> void:
	assert(Lanes.action_name(0) == &"lane_1", "El carril 0 usa lane_1")
	assert(Lanes.action_name(4) == &"lane_5", "El carril 4 usa lane_5")


func test_lanes_offsets_lane_count_3() -> void:
	assert(is_equal_approx(Lanes.lane_offset(0, 3), -140.0))
	assert(is_equal_approx(Lanes.lane_offset(1, 3), 0.0))
	assert(is_equal_approx(Lanes.lane_offset(2, 3), 140.0))


func test_lanes_offsets_lane_count_5() -> void:
	assert(is_equal_approx(Lanes.lane_offset(0, 5), -280.0))
	assert(is_equal_approx(Lanes.lane_offset(4, 5), 280.0))


func test_lanes_offsets_are_symmetric() -> void:
	for count: int in Lanes.DIFFICULTY_LANES:
		for lane in count:
			var mirror := count - 1 - lane
			assert(is_equal_approx(
					Lanes.lane_offset(lane, count), -Lanes.lane_offset(mirror, count)))


func test_characters_count_and_clamping() -> void:
	assert(Characters.count() == 5, "Deben existir 5 personajes")
	assert(Characters.get_character(-3)["id"] == "kira", "Índice bajo se acota a KIRA")
	assert(Characters.get_character(99)["id"] == "pixel", "Índice alto se acota a PIXEL")


func test_characters_modifiers_are_valid() -> void:
	for character: Dictionary in Characters.LIST:
		assert(character.has("texture"), "Falta textura en %s" % character["id"])
		assert(float(character["hit_window_mult"]) > 0.0)
		assert(float(character["score_mult"]) > 0.0)
		assert(float(character["scroll_mult"]) > 0.0)
		assert(character["combo_shield"] is bool)


func test_character_textures_exist() -> void:
	for character: Dictionary in Characters.LIST:
		var path: String = str(character["texture"])
		assert(FileAccess.file_exists(path), "No existe la textura: %s" % path)


func test_chart_data_lanes_in_range() -> void:
	for chart: int in [ChartData.Chart.THE_COMEBACK, ChartData.Chart.SYNC_TEST]:
		var data: Array[Array] = ChartData.get_chart_data(chart)
		assert(not data.is_empty(), "El chart %d está vacío" % chart)
		for measure: Array in data:
			assert(not measure.is_empty())
			for value: int in measure:
				assert(value >= 0 and value <= Lanes.MAX_LANES, "Carril fuera de rango: %d" % value)


func test_chart_data_has_notes() -> void:
	for chart: int in [ChartData.Chart.THE_COMEBACK, ChartData.Chart.SYNC_TEST]:
		var data: Array[Array] = ChartData.get_chart_data(chart)
		var notes := 0
		for measure: Array in data:
			for value: int in measure:
				if value > 0:
					notes += 1
		assert(notes > 0, "El chart %d no tiene notas" % chart)


func test_song_library_builtin_song() -> void:
	var songs: Array[Dictionary] = SongLibrary.get_songs()
	assert(songs.size() >= 1, "Debe haber al menos una canción")
	assert(songs[0]["path"] == "res://music/the_comeback2.ogg")
	assert(bool(songs[0]["builtin"]), "La primera canción es precargada")


func test_song_library_loads_builtin_stream() -> void:
	var stream: AudioStream = SongLibrary.load_stream("res://music/the_comeback2.ogg")
	assert(stream != null, "No se pudo cargar la canción precargada")


func test_custom_chart_path_is_stable() -> void:
	var path: String = SongLibrary.chart_path("res://music/the_comeback2.ogg")
	assert(path.begins_with("user://charts/"))
	assert(path.ends_with(".json"))


func test_custom_chart_roundtrip() -> void:
	var song := "user://tests_fake_song.ogg"
	var notes: Array = [[1.0, 1], [2.5, 3], [4.0, 5]]
	assert(SongLibrary.save_custom_chart(song, 123.0, 456, notes), "No se pudo guardar")
	assert(SongLibrary.has_custom_chart(song), "No se detecta el chart guardado")
	var loaded: Dictionary = SongLibrary.load_custom_chart(song)
	assert(is_equal_approx(float(loaded["bpm"]), 123.0))
	assert(int(loaded["offset_ms"]) == 456)
	assert((loaded["notes"] as Array).size() == 3)
	assert(is_equal_approx(SongLibrary.custom_chart_last_beat(song), 4.0))
	assert(SongLibrary.delete_custom_chart(song), "No se pudo borrar")
	assert(not SongLibrary.has_custom_chart(song), "El chart no se borró")


func test_character_load_texture_works() -> void:
	var texture: Texture2D = Characters.load_texture("res://assets/generated/char_kira.png")
	assert(texture != null, "No se pudo cargar la textura de KIRA")
