## Helpers for the multi-lane note field (3 to 5 lanes by difficulty).
class_name Lanes

## Maximum number of lanes (and input actions) supported.
const MAX_LANES := 5
## Horizontal distance (in pixels) between lane centers.
const SPACING := 140.0

## Physical keys used for each lane count.
const LANE_KEYS := {
	3: [KEY_F, KEY_G, KEY_H],
	4: [KEY_D, KEY_F, KEY_J, KEY_K],
	5: [KEY_D, KEY_F, KEY_SPACE, KEY_J, KEY_K],
}

## Difficulty names and the lane count each one uses.
const DIFFICULTY_NAMES := ["Facil", "Normal", "Dificil"]
const DIFFICULTY_LANES := [3, 4, 5]


## Input action name for a (0-based) lane.
static func action_name(lane: int) -> StringName:
	return StringName("lane_%d" % (lane + 1))


## (Re)binds lane_1..lane_N to the keys of the given difficulty (o a los atajos
## personalizados del jugador, si los hay).
static func setup_input(lane_count: int) -> void:
	var keys: Array = LANE_KEYS.get(lane_count, LANE_KEYS[5])
	for lane in range(MAX_LANES):
		var action := action_name(lane)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		if lane >= keys.size():
			continue
		var keycode: int = int(keys[lane])
		var custom_key := "%d_%d" % [lane_count, lane]
		if GlobalSettings.lane_bindings.has(custom_key):
			keycode = int(GlobalSettings.lane_bindings[custom_key])
		if keycode == 0:
			continue
		var event := InputEventKey.new()
		event.physical_keycode = keycode as Key
		InputMap.action_add_event(action, event)


## X offset (relative to the field center) of a lane, for a given lane count.
static func lane_offset(lane: int, lane_count: int) -> float:
	return (lane - (lane_count - 1) / 2.0) * SPACING


## Human-readable key names for the current lane count (e.g. "D  F  Space").
static func key_labels(lane_count: int) -> PackedStringArray:
	var keys: Array = LANE_KEYS.get(lane_count, LANE_KEYS[5])
	var labels := PackedStringArray()
	for key: Key in keys:
		labels.append(OS.get_keycode_string(key))
	return labels
