extends Control
## Création du personnage : prénom, puis apparence détaillée par onglets
## (corps, visage, yeux, cheveux, tenue) avec un aperçu en 3D.
## Sert aussi à changer de look en cours de jeu (edit_mode = true, via le miroir).

signal created(child_name: String, appearance: Dictionary)
signal back

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Character = preload("res://scripts/world/character.gd")

## Onglets : [titre, pictogramme, vue rapprochée du visage ?, lignes [clé, libellé, noms ou couleurs]]
const TABS := [
	["Corps", "perso", false, [
		["body", "Je suis", Data.BODIES], ["height", "Taille", Data.HEIGHTS],
		["build", "Corpulence", Data.BUILDS], ["skin", "Peau", Data.SKIN_COLORS]]],
	["Visage", "coeur", true, [
		["face", "Forme", Data.FACES], ["cheeks", "Joues", Data.CHEEKS], ["blush", "Joues roses", Data.BLUSHES],
		["nose", "Nez", Data.NOSES], ["mouth", "Bouche", Data.MOUTHS], ["freckles", "Taches de rousseur", Data.FRECKLES]]],
	["Yeux", "miroir", true, [
		["eye_color", "Couleur", Data.EYE_COLORS], ["eye_shape", "Forme", Data.EYE_SHAPES],
		["brows", "Sourcils", Data.BROWS], ["glasses", "Lunettes", Data.GLASSES]]],
	["Cheveux", "etoile", true, [
		["hair_style", "Coiffure", Data.HAIR_STYLES], ["hair", "Couleur", Data.HAIR_COLORS], ["beard", "Barbe", Data.BEARDS]]],
	["Tenue", "creativite", false, [
		["outfit_style", "Vêtement", Data.OUTFIT_STYLES], ["outfit", "Couleur du haut", Data.OUTFIT_COLORS],
		["bottom", "Couleur du bas", Data.BOTTOM_COLORS], ["shoes", "Chaussures", Data.SHOE_COLORS]]],
]

var appearance: Dictionary = {}
var edit_mode := false

var _name_edit: LineEdit
var _preview_character
var _camera: Camera3D
var _message: Label
var _tab_buttons: Array = []
var _tab_box: VBoxContainer
var _tab := 0
var _option_buttons := {} # clé → [{button, color}]
var _time := 0.0
var _close_up := false
var _spin := 200.0


func _ready() -> void:
	appearance = Data.complete_appearance(appearance)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, Color(0.78, 0.88, 0.98))
	gradient.gradient.set_color(1, Color(0.99, 0.93, 0.84))
	gradient.fill_from = Vector2(0, 0)
	gradient.fill_to = Vector2(0, 1)
	bg.texture = gradient
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	panel.add_child(columns)

	# --- Aperçu 3D ---
	var view_card := UiTheme.card(Color(0.86, 0.92, 0.98), 6)
	columns.add_child(view_card)
	var view_container := SubViewportContainer.new()
	view_container.custom_minimum_size = Vector2(330, 590)
	view_container.stretch = true
	view_card.add_child(view_container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view_container.add_child(viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.97, 0.92)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(env)
	_camera = Camera3D.new()
	_camera.fov = 32
	viewport.add_child(_camera)
	var floor_disc := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.66
	disc.height = 0.06
	floor_disc.mesh = disc
	floor_disc.position.y = -0.03
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.72, 0.7, 0.66)
	floor_disc.material_override = disc_mat
	viewport.add_child(floor_disc)
	_preview_character = Character.new()
	viewport.add_child(_preview_character)
	_place_camera(1.0)

	# --- Choix ---
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 10)
	columns.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.label("Change de look" if edit_mode else "Crée ton personnage", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var random := UiTheme.icon_button("de", "Au hasard", UiTheme.COL_PURPLE, 20)
	random.focus_mode = Control.FOCUS_NONE
	random.pressed.connect(func():
		appearance = Data.random_appearance()
		_refresh())
	head.add_child(random)
	if not edit_mode:
		var name_row := HBoxContainer.new()
		box.add_child(name_row)
		var name_label := UiTheme.label("Ton prénom :", 22)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_row.add_child(name_label)
		_name_edit = LineEdit.new()
		_name_edit.max_length = 15
		_name_edit.add_theme_font_size_override("font_size", 26)
		_name_edit.placeholder_text = "Prénom"
		_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_edit.text_submitted.connect(func(_t): _validate())
		name_row.add_child(_name_edit)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for i in TABS.size():
		var b := UiTheme.icon_button(TABS[i][1], TABS[i][0], UiTheme.COL_ACCENT, 19)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _show_tab(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var tab_card := UiTheme.card(UiTheme.COL_SOFT, 16)
	tab_card.custom_minimum_size = Vector2(0, 360)
	box.add_child(tab_card)
	_tab_box = VBoxContainer.new()
	_tab_box.add_theme_constant_override("separation", 9)
	tab_card.add_child(_tab_box)

	_message = UiTheme.label("", 19, UiTheme.COL_BAD)
	box.add_child(_message)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var back_button := UiTheme.button("Retour", UiTheme.COL_GREY)
	back_button.pressed.connect(func(): back.emit())
	buttons.add_child(back_button)
	var go := UiTheme.icon_button("coche", "Valider" if edit_mode else "C'est parti !", UiTheme.COL_GOOD, 24)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(_validate)
	buttons.add_child(go)
	_show_tab(0)
	if _name_edit != null:
		_name_edit.grab_focus()


func _process(delta: float) -> void:
	_time += delta
	if _preview_character == null:
		return
	# Vue du corps : le personnage tourne lentement. Vue du visage : il reste de face.
	if _close_up:
		_spin = lerp_angle(deg_to_rad(_spin), deg_to_rad(180.0 + sin(_time * 0.9) * 28.0), 1.0 - exp(-delta * 4.0))
		_spin = rad_to_deg(_spin)
	else:
		_spin += delta * 24.0
	_preview_character.rotation_degrees.y = _spin
	_place_camera(1.0 - exp(-delta * 5.0))


func _place_camera(k: float) -> void:
	var s: float = Data.HEIGHT_SCALES[appearance.get("height", 2)]
	var target := Vector3(0, 1.5 * s, 1.75) if _close_up else Vector3(0, 0.98 * s, 3.9)
	_camera.position = _camera.position.lerp(target, k)


func _show_tab(index: int) -> void:
	_tab = index
	_close_up = TABS[index][2]
	for c in _tab_box.get_children():
		c.queue_free()
	_option_buttons.clear()
	for row_def in TABS[index][3]:
		var key: String = row_def[0]
		var values: Array = row_def[2]
		var row := HBoxContainer.new()
		_tab_box.add_child(row)
		var l := UiTheme.label(row_def[1], 19)
		l.custom_minimum_size = Vector2(150, 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		row.add_child(flow)
		var entries := []
		for i in values.size():
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			var is_color: bool = values[i] is Color
			if is_color:
				b.custom_minimum_size = Vector2(44, 44)
				b.tooltip_text = "%s %d" % [row_def[1], i + 1]
			else:
				b.text = values[i]
				b.add_theme_font_size_override("font_size", 18)
			b.pressed.connect(func():
				appearance[key] = i
				_refresh())
			flow.add_child(b)
			entries.append({"button": b, "color": values[i] if is_color else null})
		_option_buttons[key] = entries
	_refresh()


func _refresh() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = Color(1, 1, 1) if i == _tab else Color(1, 1, 1, 0.55)
	for key in _option_buttons:
		for i in _option_buttons[key].size():
			var entry: Dictionary = _option_buttons[key][i]
			var selected: bool = appearance[key] == i
			var style := StyleBoxFlat.new()
			style.anti_aliasing = true
			if entry["color"] != null:
				style.set_corner_radius_all(22)
				style.bg_color = entry["color"]
				style.border_color = UiTheme.COL_TEXT if selected else Color(1, 1, 1)
				style.set_border_width_all(5 if selected else 3)
			else:
				style.set_corner_radius_all(14)
				style.bg_color = UiTheme.COL_ACCENT if selected else Color(1, 1, 1)
				style.border_color = UiTheme.COL_ACCENT.darkened(0.2) if selected else Color(0.78, 0.82, 0.9)
				style.set_border_width_all(2)
				style.border_width_bottom = 4
				style.content_margin_left = 14
				style.content_margin_right = 14
				style.content_margin_top = 6
				style.content_margin_bottom = 6
				var font_color := Color.WHITE if selected else UiTheme.COL_TEXT
				for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
					entry["button"].add_theme_color_override(c, font_color)
			for state in ["normal", "hover", "pressed"]:
				entry["button"].add_theme_stylebox_override(state, style)
	_preview_character.build(appearance)


func _validate() -> void:
	if edit_mode:
		created.emit("", appearance.duplicate())
		return
	var child_name := _name_edit.text.strip_edges()
	if child_name == "":
		_message.text = "Écris ton prénom pour commencer."
		_name_edit.grab_focus()
		return
	created.emit(child_name, appearance.duplicate())
