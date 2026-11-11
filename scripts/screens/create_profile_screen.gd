extends Control
## Création d'un joueur : prénom + quelques choix d'apparence, avec aperçu en 3D.

signal created(child_name: String, appearance: Dictionary)
signal back

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Character = preload("res://scripts/world/character.gd")

var appearance := {"skin": 0, "hair": 1, "hair_style": 0, "outfit": 0}
var _name_edit: LineEdit
var _preview_character
var _message: Label
var _rows := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.86, 0.92, 0.98)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	panel.add_child(columns)

	# Aperçu 3D
	var view_container := SubViewportContainer.new()
	view_container.custom_minimum_size = Vector2(300, 460)
	view_container.stretch = true
	columns.add_child(view_container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	view_container.add_child(viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 0.8
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.97, 0.92)
	env.environment.ambient_light_energy = 0.45
	viewport.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 3.1)
	cam.fov = 40
	viewport.add_child(cam)
	_preview_character = Character.new()
	viewport.add_child(_preview_character)
	_preview_character.rotation_degrees.y = 200

	# Choix
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	columns.add_child(box)
	box.add_child(UiTheme.label("Crée ton personnage", 34))
	box.add_child(UiTheme.label("Ton prénom :", 22))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 15
	_name_edit.add_theme_font_size_override("font_size", 30)
	_name_edit.placeholder_text = "Prénom"
	box.add_child(_name_edit)
	_add_color_row(box, "Peau", "skin", Data.SKIN_COLORS)
	_add_color_row(box, "Cheveux", "hair", Data.HAIR_COLORS)
	_add_text_row(box, "Coiffure", "hair_style", Data.HAIR_STYLES)
	_add_color_row(box, "Tenue", "outfit", Data.OUTFIT_COLORS)
	_message = UiTheme.label("", 20, UiTheme.COL_BAD)
	box.add_child(_message)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var back_button := UiTheme.button("Retour", Color(0.6, 0.62, 0.68))
	back_button.pressed.connect(func(): back.emit())
	buttons.add_child(back_button)
	var go := UiTheme.button("C'est parti !", UiTheme.COL_GOOD)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(_validate)
	buttons.add_child(go)
	_name_edit.text_submitted.connect(func(_t): _validate())
	_refresh()
	_name_edit.grab_focus()


func _process(delta: float) -> void:
	if _preview_character != null:
		_preview_character.rotation_degrees.y += delta * 20.0


func _add_color_row(box: VBoxContainer, label: String, key: String, colors: Array) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := UiTheme.label(label, 22)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	var buttons := []
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(54, 54)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s %d" % [label, i + 1]
		b.pressed.connect(func():
			appearance[key] = i
			_refresh())
		row.add_child(b)
		buttons.append({"button": b, "color": colors[i]})
	_rows[key] = buttons


func _add_text_row(box: VBoxContainer, label: String, key: String, names: Array) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := UiTheme.label(label, 22)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	var buttons := []
	for i in names.size():
		var b := UiTheme.button(names[i], UiTheme.COL_ACCENT, 20)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			appearance[key] = i
			_refresh())
		row.add_child(b)
		buttons.append({"button": b, "color": null})
	_rows[key] = buttons


func _refresh() -> void:
	for key in _rows:
		for i in _rows[key].size():
			var entry: Dictionary = _rows[key][i]
			var selected: bool = appearance[key] == i
			var style := StyleBoxFlat.new()
			style.set_corner_radius_all(27 if entry["color"] != null else 16)
			style.bg_color = entry["color"] if entry["color"] != null else (UiTheme.COL_ACCENT.darkened(0.25) if selected else UiTheme.COL_ACCENT.lightened(0.3))
			style.border_color = UiTheme.COL_TEXT
			style.set_border_width_all(4 if selected else 0)
			style.content_margin_left = 16
			style.content_margin_right = 16
			for state in ["normal", "hover", "pressed"]:
				entry["button"].add_theme_stylebox_override(state, style)
	_preview_character.build(appearance)


func _validate() -> void:
	var child_name := _name_edit.text.strip_edges()
	if child_name == "":
		_message.text = "Écris ton prénom pour commencer."
		_name_edit.grab_focus()
		return
	created.emit(child_name, appearance.duplicate())
