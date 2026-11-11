extends Control
## Panneau de frappe : l'enfant recopie un texte modèle pour déclencher une action.
## Émet `finished(result)` avec result.status = "ok", "timeout" ou "cancel".

signal finished(result: Dictionary)

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const TypingCheck = preload("res://scripts/core/typing_check.gd")
const Progression = preload("res://scripts/core/progression.gd")

var model_text := ""
var timed := false
var time_limit := 0.0

var _title: Label
var _model: Label
var _input: LineEdit
var _feedback: Label
var _timer_bar: ProgressBar
var _timer_label: Label
var _validate: Button
var _cancel: Button
var _elapsed := 0.0
var _first_key_time := -1.0
var _active := false
var _closing := false
var _open_id := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -330
	panel.offset_bottom = -24
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	_title = UiTheme.label("", 22, UiTheme.COL_TEXT.lightened(0.25))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	top.add_child(UiTheme.speak_button(func(): return model_text))

	var model_box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.COL_SOFT
	style.set_corner_radius_all(16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	model_box.add_theme_stylebox_override("panel", style)
	vbox.add_child(model_box)
	_model = UiTheme.label("", 46)
	_model.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	model_box.add_child(_model)

	_input = LineEdit.new()
	_input.add_theme_font_size_override("font_size", 40)
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.placeholder_text = "Écris ici…"
	_input.context_menu_enabled = false
	_input.text_submitted.connect(func(_t): _submit())
	_input.text_changed.connect(_on_text_changed)
	vbox.add_child(_input)

	var timer_row := HBoxContainer.new()
	vbox.add_child(timer_row)
	_timer_label = UiTheme.label("⏱", 22)
	timer_row.add_child(_timer_label)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 18)
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer_bar.add_theme_stylebox_override("fill", _fill(UiTheme.COL_ACCENT))
	timer_row.add_child(_timer_bar)
	timer_row.name = "TimerRow"

	_feedback = UiTheme.label("", 22)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_feedback)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)
	_cancel = UiTheme.button("Annuler", Color(0.6, 0.62, 0.68), 22)
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.pressed.connect(func(): _close({"status": "cancel"}))
	buttons.add_child(_cancel)
	_validate = UiTheme.button("Valider (Entrée)", UiTheme.COL_GOOD, 22)
	_validate.focus_mode = Control.FOCUS_NONE
	_validate.pressed.connect(_submit)
	buttons.add_child(_validate)
	visible = false


func _fill(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(9)
	return box


## Ouvre le panneau. `title` explique l'action ; `limit` en secondes si chronométré.
func open(text: String, title: String, p_timed: bool, limit := 0.0) -> void:
	model_text = text
	timed = p_timed
	time_limit = limit
	_title.text = title
	_model.text = text
	_input.text = ""
	_input.editable = true
	_feedback.text = "Pas de chronomètre : prends ton temps." if not timed else "Chronomètre ! Tape vite et bien."
	_feedback.add_theme_color_override("font_color", UiTheme.COL_TEXT)
	_elapsed = 0.0
	_first_key_time = -1.0
	_active = true
	_closing = false
	_open_id += 1
	_validate.disabled = false
	_cancel.disabled = false
	var timer_row := find_child("TimerRow", true, false)
	timer_row.visible = timed
	_timer_bar.max_value = maxf(time_limit, 0.1)
	_timer_bar.value = time_limit
	visible = true
	_input.grab_focus()


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if timed:
		var left := maxf(time_limit - _elapsed, 0.0)
		_timer_bar.value = left
		_timer_bar.add_theme_stylebox_override("fill", _fill(UiTheme.COL_BAD if left < time_limit * 0.3 else UiTheme.COL_ACCENT))
		_timer_label.text = "⏱ %d s" % ceili(left)
		if left <= 0.0:
			_active = false
			_input.editable = false
			_show_feedback("Trop lent cette fois… L'action est ratée. Tu vas y arriver !", UiTheme.COL_BAD)
			_close_later({"status": "timeout"}, 2.2)


func _on_text_changed(_t: String) -> void:
	if _first_key_time < 0.0:
		_first_key_time = _elapsed


func _submit() -> void:
	if not _active or _input.text.strip_edges() == "":
		return
	var game = get_node("/root/Game")
	var offset: int = Progression.TOLERANCE_OFFSET.get(Progression.setting(game.profile, "tolerance"), 0)
	var check := TypingCheck.check(model_text, _input.text, offset)
	var start := maxf(_first_key_time, 0.0)
	var seconds := maxf(_elapsed - start, 0.4)
	var cps := TypingCheck.normalize(model_text).length() / seconds
	game.record_typing(check, model_text.length(), seconds)
	if check["ok"]:
		_active = false
		_input.editable = false
		var msg := "Bravo !" if check["errors"] == 0 else "Bravo ! (petite faute acceptée)"
		_show_feedback(msg, UiTheme.COL_GOOD)
		_close_later({"status": "ok", "cps": cps, "seconds": seconds, "check": check}, 0.7)
	else:
		_show_feedback("Presque ! Regarde bien le modèle et corrige.", UiTheme.COL_WARN.darkened(0.25))
		_input.grab_focus()


func _show_feedback(text: String, color: Color) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", color)


func _close_later(result: Dictionary, delay: float) -> void:
	_validate.disabled = true
	_cancel.disabled = true
	var id := _open_id
	await get_tree().create_timer(delay).timeout
	if id == _open_id:
		_close(result)


func _close(result: Dictionary) -> void:
	if _closing:
		return
	_closing = true
	_active = false
	visible = false
	finished.emit(result)
