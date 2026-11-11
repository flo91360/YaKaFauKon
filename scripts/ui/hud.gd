extends Control
## Interface permanente, volontairement épurée : jauges, argent, heure, 3 boutons.

signal skills_pressed
signal career_pressed
signal pause_pressed
signal mission_pressed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")

var _bars := {}
var _fills := {}
var _rows := {}
var _money: Label
var _clock: Label
var _status: Label
var _toast_box: VBoxContainer
var _mission_button: Button
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Jauges (en haut à gauche)
	var needs_panel := PanelContainer.new()
	needs_panel.position = Vector2(16, 16)
	add_child(needs_panel)
	var needs_box := VBoxContainer.new()
	needs_box.add_theme_constant_override("separation", 6)
	needs_panel.add_child(needs_box)
	for n in Data.NEED_ORDER:
		var row := HBoxContainer.new()
		needs_box.add_child(row)
		var l := UiTheme.label(Data.NEEDS[n]["label"], 20)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size = Vector2(130, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(170, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(10)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		_bars[n] = bar
		_fills[n] = fill
		_rows[n] = row

	# Argent, heure et boutons (en haut à droite)
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_left = -16
	right.offset_right = -16
	right.offset_top = 16
	add_child(right)
	var info_panel := PanelContainer.new()
	right.add_child(info_panel)
	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info_panel.add_child(info)
	_money = UiTheme.label("", 24)
	_money.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(_money)
	_clock = UiTheme.label("", 24)
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(_clock)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(buttons)
	var b_skills := UiTheme.button("Compétences", UiTheme.COL_ACCENT, 20)
	b_skills.focus_mode = Control.FOCUS_NONE
	b_skills.pressed.connect(func(): skills_pressed.emit())
	buttons.add_child(b_skills)
	var b_career := UiTheme.button("Travail", Color(0.95, 0.6, 0.35), 20)
	b_career.focus_mode = Control.FOCUS_NONE
	b_career.pressed.connect(func(): career_pressed.emit())
	buttons.add_child(b_career)
	var b_pause := UiTheme.button("II", Color(0.6, 0.62, 0.68), 20)
	b_pause.tooltip_text = "Pause"
	b_pause.focus_mode = Control.FOCUS_NONE
	b_pause.pressed.connect(func(): pause_pressed.emit())
	buttons.add_child(b_pause)
	_mission_button = UiTheme.button("Nouvelle mission !", Color(0.95, 0.5, 0.45), 22)
	_mission_button.focus_mode = Control.FOCUS_NONE
	_mission_button.visible = false
	_mission_button.pressed.connect(func(): mission_pressed.emit())
	right.add_child(_mission_button)

	# Ce que fait le personnage (en bas à gauche)
	_status = UiTheme.label("", 22, Color.WHITE)
	_status.add_theme_color_override("font_outline_color", Color(0.15, 0.18, 0.3))
	_status.add_theme_constant_override("outline_size", 8)
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_left = 20
	_status.offset_top = -50
	_status.offset_right = 420
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)

	# Messages (en haut au centre)
	_toast_box = VBoxContainer.new()
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_left = -260
	_toast_box.offset_right = 260
	_toast_box.offset_top = 16
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)


func update_display(profile: Dictionary, status_text: String) -> void:
	_time += get_process_delta_time()
	for n in _bars:
		var v: float = profile["needs"][n]
		_bars[n].value = v
		_fills[n].bg_color = UiTheme.need_color(v)
		# La ligne clignote doucement quand la jauge est dans le rouge.
		_rows[n].modulate.a = 0.55 + 0.45 * absf(sin(_time * 4.0)) if v < Data.RED_THRESHOLD else 1.0
	_money.text = "%d pièces" % int(profile["money"])
	var minutes := int(profile["game_minutes"])
	_clock.text = "  Jour %d · %02d:%02d" % [minutes / 1440 + 1, (minutes % 1440) / 60, minutes % 60]
	_status.text = status_text


func set_mission_available(on: bool) -> void:
	_mission_button.visible = on


func toast(text: String, color := UiTheme.COL_ACCENT, seconds := 3.5) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(text, 22, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(l)
	_toast_box.add_child(panel)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).free()
	var tween := panel.create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)
