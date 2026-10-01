# 🎮 Cómo ejecutar Rever-beat

## Requisitos previos

- **Godot Engine 4.7** o superior ([descargar](https://godotengine.org/download))
- Sistema operativo: Windows, macOS o Linux
- ~500 MB de espacio en disco

## Instalación y Ejecución

### Opción 1: Desde el Editor de Godot (Recomendado)

1. Abre **Godot Engine 4.7**
2. Haz clic en **Abrir proyecto**
3. Navega a la carpeta del proyecto `Rever-beat`
4. Selecciona `project.godot` y abre el proyecto
5. Una vez cargado, presiona **F5** o haz clic en el botón ▶️ **Play** para ejecutar el juego

### Opción 2: Desde línea de comandos

```bash
# Linux / macOS
godot --path . --run

# Windows
godot.exe --path . --run
```

## Controles del Juego

- **Carril 1**: `S` o `A`
- **Carril 2**: `D` 
- **Carril 3**: `F`
- **Carril 4**: `J`
- **Carril 5**: `K` (en dificultad máxima)
- **Pausa**: `ESC`
- **Seleccionar opciones**: Ratón o flechas del teclado

## Solución de problemas

### El juego no inicia
- Verifica que la versión de Godot sea 4.7 o superior
- Asegúrate de estar en la carpeta raíz del proyecto
- Comprueba que `project.godot` exista

### No se escucha música
- Verifica que `res://music/the_comeback2.ogg` existe
- Comprueba los niveles de volumen del sistema

### Las pruebas fallan
- Instala GUT: `godot --run addons/gut/run.gd` (si está instalado)
- O ejecuta desde el editor: **Pruebas > Ejecutar**

## Desarrollo

Para contribuir o modificar el código:

1. Abre el proyecto en Godot
2. Edita archivos `.gd` en la carpeta `scenes/` o `scripts/`
3. Presiona **F5** para ver los cambios en tiempo real
4. Ejecuta pruebas unitarias antes de confirmar cambios

## Más información

- [Documentación oficial de Godot](https://docs.godotengine.org/)
- [GDScript Reference](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
- Ver también: [README.md](README.md)
