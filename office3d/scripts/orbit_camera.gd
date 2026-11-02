extends Node3D
class_name OrbitCamera

## Câmera cinematográfica: zoom-in de abertura + órbita lenta automática.
## Arrastar gira, scroll aproxima, R liga/desliga a órbita.

var yaw := 0.45
var pitch := -0.48
var dist := 18.0
var auto_orbit := true

var _intro := 5.0
var _dragging := false
var _pitch_node: Node3D
var _cam: Camera3D


func _ready() -> void:
	position = Vector3(0, 1.0, 0)
	_pitch_node = Node3D.new()
	add_child(_pitch_node)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.position = Vector3(0, 0, dist)
	_pitch_node.add_child(_cam)
	_cam.current = true
	_apply()


func _apply() -> void:
	rotation.y = yaw
	_pitch_node.rotation.x = pitch
	var d := dist
	if _intro > 0.0:
		var t := clampf(_intro / 5.0, 0.0, 1.0)
		d = lerpf(dist, 32.0, ease(t, 2.0))
	_cam.position.z = d


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
				if event.pressed:
					_intro = 0.0
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					dist = clampf(dist - 1.2, 6.0, 34.0)
					_intro = 0.0
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					dist = clampf(dist + 1.2, 6.0, 34.0)
					_intro = 0.0
		_apply()
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -1.35, -0.08)
		_apply()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		auto_orbit = not auto_orbit


func _process(delta: float) -> void:
	if _intro > 0.0:
		_intro -= delta
		_apply()
	if auto_orbit and not _dragging:
		yaw += delta * 0.05
		_apply()
