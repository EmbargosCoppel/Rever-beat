## Personajes jugables. Cada uno da una característica especial al jugar.
class_name Characters

## Modificadores:
##  scroll_mult     -> multiplica la velocidad de las notas
##  hit_window_mult -> multiplica la ventana de acierto (>1 = más fácil)
##  score_mult      -> multiplica la puntuación
##  combo_shield    -> si es true, un fallo no rompe el combo
const LIST: Array[Dictionary] = [
	{
		"id": "kira",
		"name": "KIRA",
		"desc": "Equilibrada. Sin modificadores.",
		"effect": "Estilo neutro",
		"texture": "res://assets/generated/char_kira.png",
		"scroll_mult": 1.0,
		"hit_window_mult": 1.0,
		"score_mult": 1.0,
		"combo_shield": false,
	},
	{
		"id": "nova",
		"name": "NOVA",
		"desc": "Velocidad y puntos.",
		"effect": "+25% velocidad  ·  x1.3 puntos  ·  ventana -15%",
		"texture": "res://assets/generated/char_nova.png",
		"scroll_mult": 1.25,
		"hit_window_mult": 0.85,
		"score_mult": 1.3,
		"combo_shield": false,
	},
	{
		"id": "zen",
		"name": "ZEN",
		"desc": "Precisión.",
		"effect": "Ventana de acierto +40%  ·  x0.9 puntos",
		"texture": "res://assets/generated/char_zen.png",
		"scroll_mult": 1.0,
		"hit_window_mult": 1.4,
		"score_mult": 0.9,
		"combo_shield": false,
	},
	{
		"id": "blaze",
		"name": "BLAZE",
		"desc": "Nunca pierde el combo.",
		"effect": "Escudo de combo  ·  x0.8 puntos",
		"texture": "res://assets/generated/char_blaze.png",
		"scroll_mult": 1.0,
		"hit_window_mult": 1.0,
		"score_mult": 0.8,
		"combo_shield": true,
	},
	{
		"id": "pixel",
		"name": "PIXEL",
		"desc": "Relajado.",
		"effect": "Ventana de acierto +25%  ·  x0.85 puntos",
		"texture": "res://assets/generated/char_pixel.png",
		"scroll_mult": 0.9,
		"hit_window_mult": 1.25,
		"score_mult": 0.85,
		"combo_shield": false,
	},
]


## Devuelve los datos de un personaje (índice acotado al rango válido).
static func get_character(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]


## Datos del personaje actualmente elegido.
static func get_selected() -> Dictionary:
	return get_character(GlobalSettings.selected_character)


static func count() -> int:
	return LIST.size()


## Carga la textura del personaje. Si el recurso todavía no está importado por
## el editor (p. ej. un PNG recién generado), lo carga directamente del archivo.
static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)
		if resource is Texture2D:
			return resource
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	return null
