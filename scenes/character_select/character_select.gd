## Pantalla para elegir personaje. Cada uno cambia cómo se juega.
extends Control

const MENU_SCENE := "res://control.tscn"

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var effect_label: Label = %EffectLabel
@onready var index_label: Label = %IndexLabel

var _index: int = 0


func _ready() -> void:
	_index = clampi(GlobalSettings.selected_character, 0, Characters.count() - 1)
	%PrevButton.pressed.connect(_prev)
	%NextButton.pressed.connect(_next)
	%BackButton.pressed.connect(_go_back)
	_update()


func _prev() -> void:
	_index = wrapi(_index - 1, 0, Characters.count())
	_update()


func _next() -> void:
	_index = wrapi(_index + 1, 0, Characters.count())
	_update()


func _update() -> void:
	GlobalSettings.selected_character = _index
	var character: Dictionary = Characters.get_character(_index)
	portrait.texture = Characters.load_texture(str(character["texture"]))
	name_label.text = str(character["name"])
	desc_label.text = str(character["desc"])
	effect_label.text = str(character["effect"])
	index_label.text = "%d / %d" % [_index + 1, Characters.count()]
	GlobalSettings.save_settings()


func _go_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
