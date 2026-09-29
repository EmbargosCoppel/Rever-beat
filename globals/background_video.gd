## Coloca el vídeo de fondo (.ogv) si el archivo existe; si no, deja el
## VideoStreamPlayer oculto. Nota: este Godot solo reproduce Theora (.ogv),
## no WebM. Convierte tu vídeo a .ogv y déjalo en una de las rutas de abajo.
class_name BackgroundVideo

## Rutas que se buscan, en orden.
const SEARCH_PATHS := [
	"res://assets/background.ogv",
	"res://background.ogv",
]


static func apply(player: VideoStreamPlayer, overlay: ColorRect = null) -> void:
	var stream := _find_stream()
	if stream != null:
		player.stream = stream
		player.visible = true
		player.play()
		if overlay:
			overlay.modulate.a = 0.55
		return

	player.stop()
	player.visible = false
	if overlay:
		overlay.modulate.a = 1.0


## Busca el vídeo: primero como recurso importado y, si aún no está importado,
## lo carga directamente del archivo .ogv (Theora).
static func _find_stream() -> VideoStream:
	for path: String in SEARCH_PATHS:
		if ResourceLoader.exists(path):
			var resource: Resource = ResourceLoader.load(path)
			if resource is VideoStream:
				return resource as VideoStream
		if FileAccess.file_exists(path):
			var theora := VideoStreamTheora.new()
			theora.set_file(path)
			return theora
	return null
