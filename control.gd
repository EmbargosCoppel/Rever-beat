extends Control

const SONG_SELECT_SCENE_PATH := "res://scenes/song_select/song_select.tscn"
const CHARACTER_SCENE_PATH := "res://scenes/character_select/character_select.tscn"
const OPTIONS_SCENE_PATH := "res://scenes/options/options.tscn"

func _ready() -> void:
	BackgroundVideo.apply($VideoStreamPlayer, $Background)
	$VBoxContainer/JUGAR.pressed.connect(_on_boton_jugar_pressed)
	$VBoxContainer/SideButtons/PERSONAJES.pressed.connect(_on_personajes_pressed)
	$VBoxContainer/SideButtons/OPCIONES.pressed.connect(_on_opciones_pressed)


# Abre la pantalla de selección de personaje.
func _on_personajes_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SCENE_PATH)


# Abre el menú de opciones (controles, sonido y características).
func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE_PATH)


# Abre la pantalla de selección de canción. Desde ahí se elige (con vista
# previa) o se añade una canción nueva, y luego se juega.
func _on_boton_jugar_pressed() -> void:
	get_tree().change_scene_to_file(SONG_SELECT_SCENE_PATH)
