extends Node3D
class_name OfficeAgent

## Um funcionário-bot. O status acima da cabeça mostra literalmente a
## tarefa em execução — vinda do backend (online) ou do team.json (offline).
## Movimento só quando significa algo: entregar trabalho na mesa de alguém.

signal task_changed(agent: OfficeAgent, text: String)

enum State { WORKING, WALKING, HANDOFF }

const STATE_EMOJI := {
	State.WORKING: "💻",
	State.WALKING: "🚶",
	State.HANDOFF: "🤝",
}

var agent_name := "Agente"
var role := "Dev"
var color := Color.WHITE
var is_human := false
var local_lines_enabled := true
var work_spot := Vector3.ZERO
var desk_look := Vector3.ZERO
var work_lines: Array = []

var state := State.WORKING
var next_state := State.WORKING
var target := Vector3.ZERO
var speed := 2.4
var task_text := ""

var _override_text := ""
var _handoff_timer := 0.0
var _pending_pause := 3.0
var _look_target := Vector3.ZERO
var _line_timer := 2.0
var _body: Node3D
var _status: Label3D
var _select_disk: MeshInstance3D
var _bob_t := 0.0


func setup(data: Dictionary, stand: Vector3, look: Vector3) -> void:
	agent_name = data.get("name", "Agente")
	role = data.get("role", "Dev")
	color = Color.html(data.get("color", "#ffffff"))
	is_human = data.get("human", false)
	work_lines = data.get("lines", [])
	work_spot = stand
	desk_look = look
	position = stand


func _ready() -> void:
	_build_visuals()
	_face(desk_look)
	_line_timer = randf_range(1.0, 6.0)
	_refresh_status()


func _build_visuals() -> void:
	_body = Node3D.new()
	add_child(_body)

	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.1
	torso.mesh = cap
	torso.position.y = 0.75
	torso.material_override = _mat(color.darkened(0.15), 0.3, 0.45)
	_body.add_child(torso)

	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	head.mesh = sph
	head.position.y = 1.52
	if is_human:
		head.material_override = _mat(Color(0.95, 0.8, 0.65))
	else:
		head.material_override = _mat(color.lightened(0.2), 0.3, 0.4)
	_body.add_child(head)

	for sx in [-0.08, 0.08]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.035
		es.height = 0.07
		eye.mesh = es
		eye.position = Vector3(sx, 1.56, 0.19)
		if is_human:
			eye.material_override = _mat(Color(0.1, 0.1, 0.12))
		else:
			eye.material_override = _glow_mat(Color(0.6, 0.95, 1.0), 3.0)
		_body.add_child(eye)

	if is_human:
		# o único humano do time: boné dourado, sem luzes de bot
		var cap_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.24
		cyl.height = 0.1
		cap_mesh.mesh = cyl
		cap_mesh.position.y = 1.74
		cap_mesh.material_override = _mat(Color(1.0, 0.84, 0.0), 0.5, 0.4)
		_body.add_child(cap_mesh)
	else:
		# identidade de bot: núcleo no peito, anel de energia, antena
		var core := MeshInstance3D.new()
		var core_mesh := BoxMesh.new()
		core_mesh.size = Vector3(0.3, 0.12, 0.06)
		core.mesh = core_mesh
		core.position = Vector3(0, 0.95, 0.26)
		core.material_override = _glow_mat(color, 2.5)
		_body.add_child(core)

		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.36
		torus.outer_radius = 0.44
		ring.mesh = torus
		ring.position.y = 0.04
		ring.material_override = _glow_mat(color, 1.8)
		_body.add_child(ring)

		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.015
		mast_mesh.bottom_radius = 0.015
		mast_mesh.height = 0.22
		mast.mesh = mast_mesh
		mast.position.y = 1.82
		mast.material_override = _mat(Color(0.25, 0.26, 0.3), 0.6, 0.4)
		_body.add_child(mast)

		var tip := MeshInstance3D.new()
		var tip_mesh := SphereMesh.new()
		tip_mesh.radius = 0.045
		tip_mesh.height = 0.09
		tip.mesh = tip_mesh
		tip.position.y = 1.95
		tip.material_override = _glow_mat(color, 3.0)
		_body.add_child(tip)

	var emoji_font := SystemFont.new()
	emoji_font.font_names = ["Segoe UI Emoji"]
	var label_font := SystemFont.new()
	label_font.font_names = ["Segoe UI", "Arial"]
	label_font.fallbacks = [emoji_font]

	var tag := Label3D.new()
	tag.text = "%s · %s" % [agent_name, role]
	if is_human:
		tag.text = "⭐ " + tag.text
	tag.font = label_font
	tag.font_size = 40
	tag.pixel_size = 0.006
	tag.outline_size = 12
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 2.0
	add_child(tag)

	_status = Label3D.new()
	_status.font = label_font
	_status.font_size = 36
	_status.pixel_size = 0.006
	_status.outline_size = 10
	_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status.position.y = 2.4
	_status.width = 340
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	# corpo clicável (raycast do mouse)
	var click_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cap_shape := CapsuleShape3D.new()
	cap_shape.radius = 0.45
	cap_shape.height = 2.2
	shape.shape = cap_shape
	shape.position.y = 1.0
	click_body.add_child(shape)
	add_child(click_body)

	# disco de seleção
	_select_disk = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.6
	disk.bottom_radius = 0.6
	disk.height = 0.03
	_select_disk.mesh = disk
	_select_disk.position.y = 0.015
	_select_disk.material_override = _glow_mat(Color(1, 1, 1), 1.6)
	_select_disk.visible = false
	add_child(_select_disk)


func _mat(c: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	return m


func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _process(delta: float) -> void:
	_bob_t += delta
	match state:
		State.WALKING:
			var dir := target - position
			dir.y = 0.0
			if dir.length() < 0.12:
				_arrive()
			else:
				position = position.move_toward(target, speed * delta)
				rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 10.0 * delta)
				_body.position.y = absf(sin(_bob_t * 9.0)) * 0.06
		State.HANDOFF:
			_body.position.y = sin(_bob_t * 2.0) * 0.02
			_handoff_timer -= delta
			if _handoff_timer <= 0.0:
				_walk_to(work_spot, State.WORKING, desk_look)
		State.WORKING:
			_body.position.y = sin(_bob_t * 2.0) * 0.02
			if local_lines_enabled and not work_lines.is_empty():
				_line_timer -= delta
				if _line_timer <= 0.0:
					_line_timer = randf_range(10.0, 20.0)
					set_task(work_lines.pick_random())


# ---------- API chamada pelo main (mensagens do backend) ----------

func set_task(text: String) -> void:
	task_text = text
	_refresh_status()
	task_changed.emit(self, text)


func deliver_to(spot: Vector3, look: Vector3, text: String, pause := 3.0) -> void:
	_override_text = text
	_pending_pause = pause
	_walk_to(spot, State.HANDOFF, look)
	task_changed.emit(self, text)


func current_text() -> String:
	return _override_text if _override_text != "" else task_text


func set_selected(on: bool) -> void:
	if _select_disk:
		_select_disk.visible = on


# ---------- interno ----------

func _walk_to(point: Vector3, after: State, look: Vector3) -> void:
	target = Vector3(point.x, 0, point.z)
	next_state = after
	_look_target = look
	state = State.WALKING
	_refresh_status()


func _arrive() -> void:
	position = target
	state = next_state
	_face(_look_target)
	if state == State.HANDOFF:
		_handoff_timer = _pending_pause
	elif state == State.WORKING:
		_override_text = ""
	_refresh_status()


func _face(point: Vector3) -> void:
	var dir := point - position
	dir.y = 0.0
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)


func _refresh_status() -> void:
	if _status == null:
		return
	var emoji: String = STATE_EMOJI[state]
	var text := _override_text if _override_text != "" else task_text
	_status.text = emoji if text == "" else "%s %s" % [emoji, text]
