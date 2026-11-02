extends Node3D

## Monta o escritório e espelha a operação real da empresa.
## Status acima de cada bot = tarefa em execução (vinda do backend).
## Clicar num agente abre o modal de operações: dossiê + CRM com o
## client journey de cada lead. Sem backend: tarefas locais do team.json.

const TEAM_PATH := "res://data/team.json"
const COMPANY := "NullPointer Inc."
const ACCENT := Color(0.3, 0.9, 1.0)

const DESK_POSITIONS: Array[Vector3] = [
	Vector3(-8.5, 0, -4), Vector3(-5, 0, -4), Vector3(-1.5, 0, -4), Vector3(2, 0, -4),
	Vector3(-8.5, 0, 1), Vector3(-5, 0, 1), Vector3(-1.5, 0, 1), Vector3(2, 0, 1),
]

const JOURNEY_STAGES := ["PROSPECTADO", "CONTACTADO", "RESPONDEU", "BRIEFING", "NEGOCIAÇÃO"]
const STAGE_INDEX := {
	"prospectado": 0,
	"contactado": 1,
	"interessado": 2,
	"recusado": 2,
	"briefing_entregue": 3,
	"em_negociacao": 4,
	"fechado": 4,
	"perdido": 4,
}

var agents: Array[OfficeAgent] = []
var ws: WsClient
var feed_lines: Array[String] = []
var wall_lines: Array[String] = []
var feed_label: RichTextLabel
var title_label: Label
var wall_screen: Label3D
var histories: Dictionary = {}
var roster_rows: Dictionary = {}
var selected_agent: OfficeAgent
var crm_clients: Array = []
var stats: Dictionary = {}

var modal_root: Control
var modal_title: Label
var modal_role: Label
var modal_status: Label
var modal_history: RichTextLabel
var modal_avatar_label: Label
var modal_avatar_style: StyleBoxFlat
var modal_chip: Label
var modal_accent: ColorRect
var crm_list: VBoxContainer

var font_ui: SystemFont
var font_bold: SystemFont
var font_mono: SystemFont

var sim_minutes := 9 * 60
var clock_accum := 0.0
var _pulse_dot: Label
var _pulse_t := 0.0
var _press_pos := Vector2.ZERO


func _ready() -> void:
	randomize()
	_make_fonts()
	_build_environment()
	_build_office()
	_spawn_team()
	_build_hud()
	_connect_backend()
	_log_system("☀️ Dia 1 — a operação começou!")


func _process(delta: float) -> void:
	clock_accum += delta
	if clock_accum >= 1.0:
		clock_accum -= 1.0
		sim_minutes += 1
		_update_title()
	if modal_root and modal_root.visible and _pulse_dot:
		_pulse_t += delta
		_pulse_dot.modulate.a = 0.55 + 0.45 * sin(_pulse_t * 4.0)


func _sim_day() -> int:
	return 1 + sim_minutes / (24 * 60)


func _sim_hour() -> int:
	return (sim_minutes / 60) % 24


# ---------- fontes (com fallback de emoji) ----------

func _make_fonts() -> void:
	var emoji := SystemFont.new()
	emoji.font_names = ["Segoe UI Emoji"]
	font_ui = SystemFont.new()
	font_ui.font_names = ["Segoe UI", "Arial"]
	font_ui.fallbacks = [emoji]
	font_bold = SystemFont.new()
	font_bold.font_names = ["Segoe UI", "Arial"]
	font_bold.font_weight = 700
	font_bold.fallbacks = [emoji]
	font_mono = SystemFont.new()
	font_mono.font_names = ["Consolas", "Courier New"]
	font_mono.fallbacks = [emoji]


# ---------- cenário ----------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.06, 0.1, 0.22)
	sky_mat.sky_horizon_color = Color(0.5, 0.3, 0.35)
	sky_mat.ground_bottom_color = Color(0.04, 0.04, 0.06)
	sky_mat.ground_horizon_color = Color(0.4, 0.25, 0.3)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.ssao_enabled = true

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, 150, 0)
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 1.0
	key.shadow_enabled = true
	add_child(key)

	for pos in [Vector3(-7, 2.7, -4), Vector3(-1, 2.7, -4), Vector3(-7, 2.7, 1), Vector3(-1, 2.7, 1), Vector3(7, 2.7, 0)]:
		var lamp := OmniLight3D.new()
		lamp.position = pos
		lamp.light_color = Color(1.0, 0.93, 0.8)
		lamp.light_energy = 1.6
		lamp.omni_range = 8.0
		add_child(lamp)

	add_child(OrbitCamera.new())


func _build_office() -> void:
	# piso claro e fosco
	var floor_mesh := _box(Vector3(22, 0.2, 16), Vector3(0, -0.1, 0), Color(0.58, 0.56, 0.52))
	var fm: StandardMaterial3D = floor_mesh.material_override
	fm.roughness = 0.65

	# parede dos fundos = vidro, cidade lá fora
	var glass := _box(Vector3(22.6, 3, 0.1), Vector3(0, 1.5, -8.1), Color(0.6, 0.8, 1.0, 0.08))
	var gm: StandardMaterial3D = glass.material_override
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.05
	gm.metallic = 0.4
	for fx in [-11.3, -5.65, 0.0, 5.65, 11.3]:
		_box(Vector3(0.12, 3, 0.14), Vector3(fx, 1.5, -8.1), Color(0.1, 0.1, 0.12))
	_box(Vector3(22.6, 0.1, 0.14), Vector3(0, 2.95, -8.1), Color(0.1, 0.1, 0.12))

	_build_city()

	# paredes laterais claras
	_box(Vector3(0.3, 3, 16), Vector3(-11.15, 1.5, 0), Color(0.5, 0.51, 0.55))
	_box(Vector3(0.3, 3, 16), Vector3(11.15, 1.5, 0), Color(0.5, 0.51, 0.55))

	# logo na parede esquerda (descolado — sem z-fighting)
	var logo := Label3D.new()
	logo.text = COMPANY.to_upper()
	logo.font = font_ui
	logo.font_size = 150
	logo.pixel_size = 0.009
	logo.outline_size = 0
	logo.modulate = Color(0.55, 0.92, 1.0)
	logo.position = Vector3(-10.93, 2.25, 2.5)
	logo.rotation_degrees.y = 90
	add_child(logo)
	var underline := _box(Vector3(0.05, 0.04, 4.6), Vector3(-11.05, 1.95, 2.5), ACCENT)
	_make_glow(underline, ACCENT, 2.5)

	# faixas de luz no teto
	for strip_z in [-4.0, 1.0]:
		var strip := _box(Vector3(12.5, 0.05, 0.3), Vector3(-3.25, 2.92, strip_z), Color(1.0, 0.95, 0.85))
		_make_glow(strip, Color(1.0, 0.95, 0.85), 1.6)

	for desk in DESK_POSITIONS:
		_build_desk(desk)

	_rug(Vector3(7, 0, 3.5), 2.6, Color(0.16, 0.25, 0.38))
	_round_table(Vector3(7, 0, 3.5), 1.4)

	_build_wall_screen()

	for p in [Vector3(10.2, 0, 7.2), Vector3(-10.2, 0, 7.2), Vector3(-10.2, 0, -7.2)]:
		_build_plant(p)


func _build_city() -> void:
	var windows := MultiMesh.new()
	windows.transform_format = MultiMesh.TRANSFORM_3D
	var win_mesh := BoxMesh.new()
	win_mesh.size = Vector3(0.4, 0.55, 0.08)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(1.0, 0.85, 0.55)
	wmat.emission_enabled = true
	wmat.emission = Color(1.0, 0.8, 0.45)
	wmat.emission_energy_multiplier = 2.2
	win_mesh.material = wmat
	windows.mesh = win_mesh

	var transforms: Array[Transform3D] = []
	for i in 16:
		var bw := randf_range(3.0, 6.5)
		var bh := randf_range(6.0, 19.0)
		var bx := randf_range(-34.0, 34.0)
		var bz := randf_range(-31.0, -13.0)
		_box(Vector3(bw, bh, bw), Vector3(bx, bh * 0.5 - 0.5, bz), Color(0.04, 0.05, 0.09))
		var cols := int(bw / 0.9)
		var rows := int(bh / 1.1)
		for c in cols:
			for r in rows:
				if randf() < 0.4:
					var wx := bx - bw * 0.5 + 0.7 + c * 0.9
					var wy := 0.6 + r * 1.1
					var wz := bz + bw * 0.5 + 0.05
					transforms.append(Transform3D(Basis.IDENTITY, Vector3(wx, wy, wz)))
	windows.instance_count = transforms.size()
	for i in transforms.size():
		windows.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = windows
	add_child(mmi)


func _build_wall_screen() -> void:
	_box(Vector3(0.14, 2.4, 7.4), Vector3(11.05, 1.6, -2), Color(0.07, 0.07, 0.09))
	var screen := _box(Vector3(0.06, 2.1, 7.0), Vector3(10.95, 1.6, -2), Color(0.02, 0.05, 0.08))
	_make_glow(screen, Color(0.04, 0.12, 0.18), 1.2)

	wall_screen = Label3D.new()
	wall_screen.font = font_mono
	wall_screen.position = Vector3(10.88, 2.45, -2)
	wall_screen.rotation_degrees.y = -90
	wall_screen.font_size = 44
	wall_screen.pixel_size = 0.0042
	wall_screen.modulate = Color(0.55, 1.6, 1.8)
	wall_screen.outline_size = 0
	wall_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	wall_screen.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	wall_screen.width = 1560
	wall_screen.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(wall_screen)
	_update_wall_screen()


func _build_desk(pos: Vector3) -> void:
	var top := Color(0.42, 0.4, 0.38)
	var dark := Color(0.18, 0.18, 0.21)
	var tampo := _box(Vector3(1.8, 0.08, 0.9), pos + Vector3(0, 0.95, 0), top)
	var tm: StandardMaterial3D = tampo.material_override
	tm.metallic = 0.3
	tm.roughness = 0.4
	_box(Vector3(0.08, 0.95, 0.8), pos + Vector3(-0.82, 0.475, 0), dark)
	_box(Vector3(0.08, 0.95, 0.8), pos + Vector3(0.82, 0.475, 0), dark)
	var monitor := _box(Vector3(0.68, 0.42, 0.05), pos + Vector3(0, 1.3, -0.25), Color(0.08, 0.09, 0.11))
	_make_glow(monitor, Color(0.3, 0.6, 0.95), 1.5)
	_box(Vector3(0.1, 0.25, 0.08), pos + Vector3(0, 1.05, -0.28), dark)


func _rug(center: Vector3, radius: float, color: Color) -> void:
	var rug := _cylinder(radius, radius, 0.02, center + Vector3(0, 0.01, 0), color)
	rug.material_override.roughness = 1.0


func _round_table(center: Vector3, top_radius: float) -> void:
	_cylinder(0.15, 0.25, 0.74, center + Vector3(0, 0.37, 0), Color(0.2, 0.2, 0.22))
	_cylinder(top_radius, top_radius, 0.08, center + Vector3(0, 0.78, 0), Color(0.55, 0.42, 0.29))


func _cylinder(top_r: float, bottom_r: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _flat_mat(color)
	add_child(mi)
	return mi


func _build_plant(pos: Vector3) -> void:
	_cylinder(0.28, 0.2, 0.4, pos + Vector3(0, 0.2, 0), Color(0.65, 0.4, 0.3))
	var leaves := MeshInstance3D.new()
	var leaves_mesh := SphereMesh.new()
	leaves_mesh.radius = 0.45
	leaves_mesh.height = 0.9
	leaves.mesh = leaves_mesh
	leaves.position = pos + Vector3(0, 0.78, 0)
	leaves.material_override = _flat_mat(Color(0.25, 0.55, 0.3))
	add_child(leaves)


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _flat_mat(color)
	mi.position = pos
	add_child(mi)
	return mi


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _make_glow(mi: MeshInstance3D, c: Color, energy: float) -> void:
	var m: StandardMaterial3D = mi.material_override
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy


# ---------- time ----------

func _spawn_team() -> void:
	var txt := FileAccess.get_file_as_string(TEAM_PATH)
	var team: Array = JSON.parse_string(txt)
	for i in team.size():
		var data: Dictionary = team[i]
		var desk: Vector3 = DESK_POSITIONS[i % DESK_POSITIONS.size()]
		var agent := OfficeAgent.new()
		agent.setup(data, desk + Vector3(0, 0, 1.1), desk)
		agent.task_changed.connect(_on_agent_task)
		add_child(agent)
		agents.append(agent)
		histories[agent.agent_name] = []


func _on_agent_task(agent: OfficeAgent, text: String) -> void:
	var h: Array = histories[agent.agent_name]
	h.append("[color=#8899aa]%02d:%02d[/color]  %s" % [_sim_hour(), sim_minutes % 60, text])
	if h.size() > 24:
		histories[agent.agent_name] = h.slice(h.size() - 24)
	_refresh_roster_row(agent)
	if agent == selected_agent and modal_root and modal_root.visible:
		modal_status.text = agent.current_text()
		_refresh_history()


func _agent_by_name(n: String) -> OfficeAgent:
	for a in agents:
		if a.agent_name == n:
			return a
	return null


# ---------- seleção por clique ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_deselect()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_N:
		ws.send_message({"type": "new_day"})
		_log_system("🌅 Novo dia solicitado — Rui vai prospectar")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
		elif event.position.distance_to(_press_pos) < 8.0:
			_try_pick(event.position)


func _try_pick(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var node: Node = hit.collider
	while node and not node is OfficeAgent:
		node = node.get_parent()
	if node is OfficeAgent:
		_select_agent(node)


func _select_agent(agent: OfficeAgent) -> void:
	selected_agent = agent
	for a in agents:
		a.set_selected(a == agent)
	modal_root.visible = true
	_refresh_modal()


func _deselect() -> void:
	selected_agent = null
	for a in agents:
		a.set_selected(false)
	if modal_root:
		modal_root.visible = false


# ---------- backend ----------

func _connect_backend() -> void:
	ws = WsClient.new()
	var names: PackedStringArray = []
	for a in agents:
		names.append(a.agent_name)
	ws.agent_names = names
	ws.message_received.connect(_on_ws_message)
	ws.connection_changed.connect(_on_ws_connection)
	add_child(ws)


func _on_ws_message(data: Dictionary) -> void:
	match str(data.get("type", "")):
		"status":
			var a := _agent_by_name(str(data.get("agent", "")))
			if a:
				a.set_task(str(data.get("text", "")))
		"feed":
			_log_system(str(data.get("text", "")))
		"deliver":
			var from_a := _agent_by_name(str(data.get("from", "")))
			var to_a := _agent_by_name(str(data.get("to", "")))
			if from_a and to_a:
				var spot := to_a.work_spot + Vector3(1.0, 0, 0.4)
				from_a.deliver_to(spot, to_a.work_spot, str(data.get("text", "")))
		"crm":
			crm_clients = data.get("clients", [])
			if modal_root and modal_root.visible:
				_rebuild_crm()
		"stats":
			stats = data
			_update_wall_screen()


func _on_ws_connection(ok: bool) -> void:
	for a in agents:
		a.local_lines_enabled = not ok
	_log_system("🧠 Operação conectada!" if ok else "🔌 Backend offline — tarefas locais")


# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(16, 16)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.add_theme_font_override("font", font_bold)
	title_label.add_theme_font_size_override("font_size", 19)
	title_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	vbox.add_child(title_label)

	var live := Label.new()
	live.text = "● AO VIVO — operação autônoma, humano só em vendas"
	live.add_theme_font_override("font", font_ui)
	live.add_theme_font_size_override("font_size", 12)
	live.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	vbox.add_child(live)

	feed_label = RichTextLabel.new()
	feed_label.bbcode_enabled = true
	feed_label.scroll_active = false
	feed_label.add_theme_font_override("normal_font", font_ui)
	feed_label.add_theme_font_size_override("normal_font_size", 13)
	feed_label.custom_minimum_size = Vector2(440, 190)
	vbox.add_child(feed_label)

	var hint := Label.new()
	hint.text = "arraste: girar · scroll: zoom · R: órbita · N: novo dia · clique: operações"
	hint.add_theme_font_override("font", font_ui)
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

	_build_roster(layer)
	_build_modal(layer)
	_update_title()


func _build_roster(layer: CanvasLayer) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.offset_left = -420.0
	col.offset_right = -16.0
	col.offset_top = 16.0
	layer.add_child(col)

	var roster_panel := PanelContainer.new()
	roster_panel.add_theme_stylebox_override("panel", _panel_style())
	col.add_child(roster_panel)
	var rv := VBoxContainer.new()
	roster_panel.add_child(rv)

	var rt := Label.new()
	rt.text = "EQUIPE — TEMPO REAL"
	rt.add_theme_font_override("font", font_bold)
	rt.add_theme_font_size_override("font_size", 14)
	rt.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	rv.add_child(rt)

	for a in agents:
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_override("font", font_ui)
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", a.color.lightened(0.3))
		row.add_theme_color_override("font_hover_color", a.color.lightened(0.55))
		row.pressed.connect(_select_agent.bind(a))
		rv.add_child(row)
		roster_rows[a.agent_name] = row
		_refresh_roster_row(a)


# ---------- modal de operações ----------

func _build_modal(layer: CanvasLayer) -> void:
	modal_root = Control.new()
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.visible = false
	layer.add_child(modal_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	modal_root.add_child(dim)

	var window := PanelContainer.new()
	var ws_style := StyleBoxFlat.new()
	ws_style.bg_color = Color(0.055, 0.065, 0.1, 0.99)
	ws_style.border_color = Color(1, 1, 1, 0.1)
	ws_style.set_border_width_all(1)
	ws_style.set_corner_radius_all(16)
	ws_style.set_content_margin_all(0)
	window.add_theme_stylebox_override("panel", ws_style)
	window.clip_contents = true
	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.offset_left = 110.0
	window.offset_right = -110.0
	window.offset_top = 60.0
	window.offset_bottom = -60.0
	modal_root.add_child(window)

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 0)
	window.add_child(card)

	modal_accent = ColorRect.new()
	modal_accent.custom_minimum_size = Vector2(0, 5)
	card.add_child(modal_accent)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 22)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 18)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(pad)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	pad.add_child(inner)

	# cabeçalho
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	inner.add_child(header)

	var avatar := PanelContainer.new()
	modal_avatar_style = StyleBoxFlat.new()
	modal_avatar_style.bg_color = Color(0.3, 0.3, 0.3)
	modal_avatar_style.set_corner_radius_all(99)
	avatar.add_theme_stylebox_override("panel", modal_avatar_style)
	avatar.custom_minimum_size = Vector2(52, 52)
	header.add_child(avatar)
	modal_avatar_label = Label.new()
	modal_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	modal_avatar_label.add_theme_font_override("font", font_bold)
	modal_avatar_label.add_theme_font_size_override("font_size", 22)
	modal_avatar_label.add_theme_color_override("font_color", Color(0.04, 0.05, 0.08))
	avatar.add_child(modal_avatar_label)

	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_box)
	modal_title = Label.new()
	modal_title.add_theme_font_override("font", font_bold)
	modal_title.add_theme_font_size_override("font_size", 22)
	modal_title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	name_box.add_child(modal_title)
	modal_role = Label.new()
	modal_role.add_theme_font_override("font", font_ui)
	modal_role.add_theme_font_size_override("font_size", 13)
	name_box.add_child(modal_role)

	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(1, 1, 1, 0.08)
	chip_style.set_corner_radius_all(8)
	chip_style.content_margin_left = 10
	chip_style.content_margin_right = 10
	chip_style.content_margin_top = 4
	chip_style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(chip)
	modal_chip = Label.new()
	modal_chip.add_theme_font_override("font", font_bold)
	modal_chip.add_theme_font_size_override("font_size", 11)
	chip.add_child(modal_chip)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_btn.pressed.connect(_deselect)
	header.add_child(close_btn)

	inner.add_child(_divider())

	# colunas
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(cols)

	# esquerda: execução + histórico
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size = Vector2(380, 0)
	cols.add_child(left)

	left.add_child(_caption("EM EXECUÇÃO"))
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	left.add_child(status_row)
	_pulse_dot = Label.new()
	_pulse_dot.text = "●"
	_pulse_dot.add_theme_font_size_override("font_size", 13)
	status_row.add_child(_pulse_dot)
	modal_status = Label.new()
	modal_status.add_theme_font_override("font", font_ui)
	modal_status.add_theme_font_size_override("font_size", 14)
	modal_status.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	modal_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(modal_status)

	left.add_child(_caption("HISTÓRICO"))
	var scroll_l := ScrollContainer.new()
	scroll_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll_l)
	modal_history = RichTextLabel.new()
	modal_history.bbcode_enabled = true
	modal_history.fit_content = true
	modal_history.add_theme_font_override("normal_font", font_mono)
	modal_history.add_theme_font_size_override("normal_font_size", 12)
	modal_history.add_theme_constant_override("line_separation", 5)
	modal_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_history.custom_minimum_size = Vector2(360, 0)
	scroll_l.add_child(modal_history)

	# direita: CRM / client journey
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	right.add_child(_caption("CLIENT JOURNEY — CRM"))
	var scroll_r := ScrollContainer.new()
	scroll_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll_r)
	crm_list = VBoxContainer.new()
	crm_list.add_theme_constant_override("separation", 10)
	crm_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_r.add_child(crm_list)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_deselect()


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	return l


func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(1, 1, 1, 0.08)
	d.custom_minimum_size = Vector2(0, 1)
	return d


func _refresh_modal() -> void:
	if selected_agent == null:
		return
	var c := selected_agent.color
	modal_accent.color = c
	modal_avatar_style.bg_color = c.lightened(0.15)
	modal_avatar_label.text = selected_agent.agent_name.substr(0, 1).to_upper()
	modal_title.text = selected_agent.agent_name
	modal_role.text = selected_agent.role
	modal_role.add_theme_color_override("font_color", c.lightened(0.35))
	modal_chip.text = "⭐ HUMANO" if selected_agent.is_human else "BOT"
	modal_chip.add_theme_color_override(
		"font_color",
		Color(1.0, 0.85, 0.3) if selected_agent.is_human else Color(0.55, 0.9, 1.0)
	)
	_pulse_dot.add_theme_color_override("font_color", c.lightened(0.3))
	modal_status.text = selected_agent.current_text()
	_refresh_history()
	_rebuild_crm()


func _refresh_history() -> void:
	if selected_agent == null:
		return
	var h: Array = histories[selected_agent.agent_name]
	var lines: Array[String] = []
	for i in range(h.size() - 1, -1, -1):  # mais recente primeiro
		lines.append(h[i])
	modal_history.text = "\n".join(lines)


func _rebuild_crm() -> void:
	for child in crm_list.get_children():
		child.queue_free()
	if crm_clients.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum cliente no funil ainda — o Rui está prospectando."
		empty.add_theme_font_override("font", font_ui)
		empty.add_theme_font_size_override("font_size", 13)
		empty.modulate = Color(1, 1, 1, 0.5)
		crm_list.add_child(empty)
		return
	for client in crm_clients:
		crm_list.add_child(_client_card(client))


func _client_card(client: Dictionary) -> Control:
	var stage := str(client.get("stage", "prospectado"))
	var idx: int = STAGE_INDEX.get(stage, 0)
	var lost := stage == "recusado" or stage == "perdido"
	var won := stage in ["briefing_entregue", "interessado", "em_negociacao", "fechado"]

	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(1, 1, 1, 0.045)
	cs.border_color = Color(1, 0.4, 0.4, 0.35) if lost else (Color(0.3, 0.9, 1.0, 0.3) if won else Color(1, 1, 1, 0.08))
	cs.set_border_width_all(1)
	cs.set_corner_radius_all(12)
	cs.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", cs)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var top_row := HBoxContainer.new()
	v.add_child(top_row)
	var name_l := Label.new()
	name_l.text = str(client.get("empresa", "?"))
	name_l.add_theme_font_override("font", font_bold)
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_l)
	var budget_l := Label.new()
	budget_l.text = "R$ %s/mês" % str(client.get("orcamento_mensal", "?"))
	budget_l.add_theme_font_override("font", font_mono)
	budget_l.add_theme_font_size_override("font_size", 12)
	budget_l.modulate = Color(1, 1, 1, 0.6)
	top_row.add_child(budget_l)

	var who := Label.new()
	who.text = "%s · %s · %s" % [client.get("contato", "?"), client.get("cargo", "?"), client.get("setor", "?")]
	who.add_theme_font_override("font", font_ui)
	who.add_theme_font_size_override("font_size", 11)
	who.modulate = Color(1, 1, 1, 0.55)
	v.add_child(who)

	var pain := Label.new()
	pain.text = "dor: %s" % str(client.get("dor", "?"))
	pain.add_theme_font_override("font", font_ui)
	pain.add_theme_font_size_override("font_size", 12)
	pain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pain.modulate = Color(1, 1, 1, 0.75)
	v.add_child(pain)

	# jornada
	var journey := HBoxContainer.new()
	journey.add_theme_constant_override("separation", 6)
	v.add_child(journey)
	for i in JOURNEY_STAGES.size():
		if i > 0:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.modulate = Color(1, 1, 1, 0.3)
			journey.add_child(arrow)
		journey.add_child(_stage_chip(JOURNEY_STAGES[i], i <= idx, lost and i == idx))
	var outcome := Label.new()
	outcome.add_theme_font_override("font", font_bold)
	outcome.add_theme_font_size_override("font_size", 11)
	if stage == "fechado":
		outcome.text = "  🏆 FECHADO — R$ 15.000"
		outcome.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	elif lost:
		outcome.text = "  ✕ PERDIDO"
		outcome.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	elif stage == "em_negociacao":
		outcome.text = "  ⏳ EM NEGOCIAÇÃO"
		outcome.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	elif stage == "briefing_entregue":
		outcome.text = "  ✓ COM O HEAD OF SALES"
		outcome.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	elif stage == "interessado":
		outcome.text = "  ✓ QUALIFICADO"
		outcome.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	journey.add_child(outcome)

	# conversa
	var thread_text := str(client.get("thread", ""))
	if thread_text != "":
		var toggle := Button.new()
		toggle.text = "▸ ver conversa"
		toggle.flat = true
		toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
		toggle.add_theme_font_override("font", font_ui)
		toggle.add_theme_font_size_override("font_size", 12)
		toggle.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
		v.add_child(toggle)
		var thread_label := RichTextLabel.new()
		thread_label.fit_content = true
		thread_label.visible = false
		thread_label.text = thread_text
		thread_label.add_theme_font_override("normal_font", font_mono)
		thread_label.add_theme_font_size_override("normal_font_size", 11)
		thread_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thread_label.modulate = Color(1, 1, 1, 0.8)
		v.add_child(thread_label)
		toggle.pressed.connect(func():
			thread_label.visible = not thread_label.visible
			toggle.text = "▾ esconder conversa" if thread_label.visible else "▸ ver conversa"
		)

	# caixa de resposta do Head of Sales (você!)
	if stage == "briefing_entregue" or stage == "em_negociacao":
		v.add_child(_caption("RESPONDER COMO HEAD OF SALES"))
		var reply_edit := TextEdit.new()
		reply_edit.custom_minimum_size = Vector2(0, 84)
		reply_edit.placeholder_text = "Escreva sua resposta para %s... (proposta, parcelamento, call)" % str(client.get("contato", "o cliente"))
		reply_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		reply_edit.add_theme_font_override("font", font_ui)
		reply_edit.add_theme_font_size_override("font_size", 13)
		v.add_child(reply_edit)
		var send_btn := Button.new()
		send_btn.text = "✉️  Enviar resposta"
		send_btn.add_theme_font_override("font", font_bold)
		send_btn.add_theme_font_size_override("font_size", 13)
		v.add_child(send_btn)
		var slug := str(client.get("slug", ""))
		send_btn.pressed.connect(func():
			var txt := reply_edit.text.strip_edges()
			if txt == "" or slug == "":
				return
			ws.send_message({"type": "reply", "slug": slug, "text": txt})
			send_btn.disabled = true
			send_btn.text = "⏳ aguardando resposta do cliente..."
			reply_edit.editable = false
		)

	return card


func _stage_chip(text: String, reached: bool, failed: bool) -> Control:
	var chip := PanelContainer.new()
	var st := StyleBoxFlat.new()
	if failed:
		st.bg_color = Color(1.0, 0.35, 0.35, 0.18)
	elif reached:
		st.bg_color = Color(0.3, 0.9, 1.0, 0.16)
	else:
		st.bg_color = Color(1, 1, 1, 0.04)
	st.set_corner_radius_all(6)
	st.content_margin_left = 7
	st.content_margin_right = 7
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold)
	l.add_theme_font_size_override("font_size", 9)
	if failed:
		l.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	elif reached:
		l.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	else:
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	chip.add_child(l)
	return chip


func _refresh_roster_row(agent: OfficeAgent) -> void:
	if not roster_rows.has(agent.agent_name):
		return
	var btn: Button = roster_rows[agent.agent_name]
	btn.text = "●  %s — %s" % [agent.agent_name, _trim(agent.current_text(), 40)]


func _trim(s: String, n: int) -> String:
	return s if s.length() <= n else s.substr(0, n - 1) + "…"


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.07, 0.9)
	sb.border_color = Color(0.3, 0.9, 1.0, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	return sb


# ---------- feed / telão ----------

func _update_title() -> void:
	if title_label == null:
		return
	title_label.text = "🏢 %s — Dia %d · %02d:%02d" % [COMPANY, _sim_day(), _sim_hour(), sim_minutes % 60]


func _log_system(text: String) -> void:
	_push_feed("[color=#ffd166]%s[/color]" % text)
	wall_lines.append("%02d:%02d  %s" % [_sim_hour(), sim_minutes % 60, text])
	if wall_lines.size() > 7:
		wall_lines = wall_lines.slice(wall_lines.size() - 7)
	_update_wall_screen()


func _update_wall_screen() -> void:
	if wall_screen == null:
		return
	var header := "◤ OPERAÇÕES — %s ◢\n" % COMPANY.to_upper()
	if not stats.is_empty():
		header += "💰 R$ %s   |   funil: %d → %d qualificados → %d fechados\n" % [
			_money(int(stats.get("receita", 0))),
			int(stats.get("prospectados", 0)),
			int(stats.get("qualificados", 0)),
			int(stats.get("fechados", 0)),
		]
	wall_screen.text = header + "\n".join(wall_lines)


func _money(v: int) -> String:
	var s := str(v)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out


func _push_feed(line: String) -> void:
	feed_lines.append("[color=#8899aa]%02d:%02d[/color]  %s" % [_sim_hour(), sim_minutes % 60, line])
	if feed_lines.size() > 9:
		feed_lines = feed_lines.slice(feed_lines.size() - 9)
	if feed_label:
		feed_label.text = "\n".join(feed_lines)
