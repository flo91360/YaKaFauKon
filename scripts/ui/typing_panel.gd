extends Control
## Panneau de frappe : l'enfant recopie un texte modèle.
## - mode simple : un texte pour déclencher une action ;
## - mode série : plusieurs mots d'un champ lexical à la suite, avec la barre de
##   la compétence qui monte à chaque mot réussi.
## Émet `validated(result)` dès que la frappe est acceptée, puis `finished(result)`
## quand le panneau se ferme, avec result.status = "ok", "timeout" ou "cancel".

signal validated(result: Dictionary)
signal finished(result: Dictionary)

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const TypingCheck = preload("res://scripts/core/typing_check.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Data = preload("res://scripts/core/data.gd")

var model_text := ""
var timed := false
var time_limit := 0.0
var series := false

var _title: Label
var _model: RichTextLabel
var _input: LineEdit
var _feedback: Label
var _timer_row: HBoxContainer
var _timer_bar: ProgressBar
var _timer_label: Label
var _validate: Button
var _cancel: Button
var _dots: HBoxContainer
var _skill_row: HBoxContainer
var _skill_badge_slot: Control
var _skill_name: Label
var _skill_bar: ProgressBar
var _skill_level: Label
var _gain: Label
var _panel: PanelContainer
var _elapsed := 0.0
var _first_key_time := -1.0
var _active := false
var _closing := false
var _open_id := 0
var _color_help := true
var _skill_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -390
	_panel.offset_right = 390
	_panel.offset_top = -300
	_panel.offset_bottom = -18
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var panel_style: StyleBoxFlat = get_theme_stylebox("panel", "PanelContainer").duplicate()
	panel_style.content_margin_top = 14
	panel_style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	_title = UiTheme.label("", 21, UiTheme.COL_TEXT.lightened(0.2))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_dots)
	top.add_child(UiTheme.speak_button(func(): return model_text))

	# Barre de la compétence (mode série)
	_skill_row = HBoxContainer.new()
	vbox.add_child(_skill_row)
	_skill_badge_slot = HBoxContainer.new()
	_skill_row.add_child(_skill_badge_slot)
	_skill_name = UiTheme.label("", 20)
	_skill_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_skill_row.add_child(_skill_name)
	_skill_bar = UiTheme.bar(UiTheme.COL_PURPLE, 22.0)
	_skill_row.add_child(_skill_bar)
	_gain = UiTheme.label("", 20, UiTheme.COL_GOOD)
	_gain.autowrap_mode = TextServer.AUTOWRAP_OFF
	_gain.custom_minimum_size = Vector2(44, 0)
	_skill_row.add_child(_gain)
	_skill_level = UiTheme.label("", 20)
	_skill_level.autowrap_mode = TextServer.AUTOWRAP_OFF
	_skill_row.add_child(_skill_level)

	var model_box := UiTheme.card(UiTheme.COL_SOFT, 20)
	vbox.add_child(model_box)
	_model = RichTextLabel.new()
	_model.bbcode_enabled = true
	_model.fit_content = true
	_model.scroll_active = false
	_model.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_model.add_theme_font_size_override("normal_font_size", 44)
	_model.add_theme_color_override("default_color", UiTheme.COL_TEXT)
	_model.mouse_filter = Control.MOUSE_FILTER_IGNORE
	model_box.add_child(_model)

	_input = LineEdit.new()
	_input.add_theme_font_size_override("font_size", 38)
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.placeholder_text = "Écris ici…"
	_input.context_menu_enabled = false
	_input.text_submitted.connect(func(_t): _submit())
	_input.text_changed.connect(_on_text_changed)
	vbox.add_child(_input)

	_timer_row = HBoxContainer.new()
	vbox.add_child(_timer_row)
	_timer_row.add_child(UiTheme.icon("chrono", 26, UiTheme.COL_TEXT))
	_timer_label = UiTheme.label("", 20)
	_timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_timer_label.custom_minimum_size = Vector2(52, 0)
	_timer_row.add_child(_timer_label)
	_timer_bar = UiTheme.bar(UiTheme.COL_ACCENT, 18.0)
	_timer_row.add_child(_timer_bar)

	var bottom := HBoxContainer.new()
	vbox.add_child(bottom)
	_feedback = UiTheme.label("", 20)
	_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_feedback)
	_cancel = UiTheme.button("Annuler", UiTheme.COL_GREY, 20)
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.pressed.connect(func(): _close({"status": "cancel"}))
	bottom.add_child(_cancel)
	_validate = UiTheme.icon_button("coche", "Valider (Entrée)", UiTheme.COL_GOOD, 20)
	_validate.focus_mode = Control.FOCUS_NONE
	_validate.pressed.connect(_submit)
	bottom.add_child(_validate)
	visible = false


## Ouvre le panneau. `title` explique l'action ; `limit` en secondes si chronométré.
func open(text: String, title: String, p_timed: bool, limit := 0.0) -> void:
	series = false
	_skill_row.visible = false
	_dots.visible = false
	_cancel.text = "Annuler"
	_open(text, title, p_timed, limit)


## Ouvre un mot d'une série. `results` : true/false pour les mots déjà passés.
func open_series(text: String, title: String, p_timed: bool, limit: float, total: int, results: Array) -> void:
	series = true
	_skill_row.visible = true
	_dots.visible = true
	_cancel.text = "Arrêter"
	for c in _dots.get_children():
		c.free()
	for i in total:
		var color := Color(0.82, 0.84, 0.88)
		if i < results.size():
			color = UiTheme.COL_GOOD if results[i] else UiTheme.COL_WARN
		elif i == results.size():
			color = UiTheme.COL_ACCENT
		var dot := Panel.new()
		var big := i == results.size()
		dot.custom_minimum_size = Vector2(20, 20) if big else Vector2(15, 15)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(10)
		style.anti_aliasing = true
		dot.add_theme_stylebox_override("panel", style)
		_dots.add_child(dot)
	_open(text, title, p_timed, limit)


func _open(text: String, title: String, p_timed: bool, limit: float) -> void:
	model_text = text
	timed = p_timed
	time_limit = limit
	_title.text = title
	_input.text = ""
	_input.editable = true
	_color_help = true
	if has_node("/root/Game"):
		var profile: Dictionary = get_node("/root/Game").profile
		if not profile.is_empty():
			_color_help = Progression.setting(profile, "aide_couleur") == "oui"
	_refresh_model()
	_show_feedback("Prends ton temps." if not timed else "Chronomètre ! Tape vite et bien.", UiTheme.COL_TEXT.lightened(0.15))
	_elapsed = 0.0
	_first_key_time = -1.0
	_active = true
	_closing = false
	_open_id += 1
	_validate.disabled = false
	_cancel.disabled = false
	_timer_row.visible = timed
	_timer_bar.max_value = maxf(time_limit, 0.1)
	_timer_bar.value = time_limit
	_gain.text = ""
	visible = true
	_input.grab_focus()


func is_open() -> bool:
	return visible


## Ferme sans rien signaler (changement d'écran, pause forcée…).
func force_close() -> void:
	_open_id += 1
	_active = false
	_closing = true
	visible = false


# --- Barre de compétence (mode série) -------------------------------------------------------

func set_skill(skill: String, level: int, fraction: float) -> void:
	for c in _skill_badge_slot.get_children():
		c.free()
	var color: Color = UiTheme.SKILL_COLORS.get(skill, UiTheme.COL_PURPLE)
	_skill_badge_slot.add_child(UiTheme.badge(skill, color, 34))
	_skill_name.text = Data.SKILLS[skill]["label"]
	UiTheme.set_bar_color(_skill_bar, color)
	if _skill_tween != null:
		_skill_tween.kill()
	_skill_bar.value = fraction
	_skill_level.text = _level_text(level)


func _level_text(level: int) -> String:
	return "niveau %d" % level if level < Data.SKILL_MAX else "niveau max !"


## Fait monter la barre après un mot réussi. `leveled` : la compétence gagne un niveau.
func animate_skill(level: int, fraction: float, gained: float, leveled: bool) -> void:
	_gain.text = "+%d" % roundi(gained)
	_gain.modulate.a = 1.0
	if _skill_tween != null:
		_skill_tween.kill()
	_skill_tween = create_tween()
	if leveled:
		_skill_tween.tween_property(_skill_bar, "value", 1.0, 0.3)
		_skill_tween.tween_callback(func():
			_skill_level.text = _level_text(level)
			_skill_bar.value = 0.0)
		_skill_tween.tween_property(_skill_bar, "value", fraction, 0.3)
	else:
		_skill_tween.tween_property(_skill_bar, "value", fraction, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_skill_tween.parallel().tween_property(_gain, "modulate:a", 0.0, 0.5).set_delay(0.5)


# --- Frappe -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if timed:
		var left := maxf(time_limit - _elapsed, 0.0)
		_timer_bar.value = left
		UiTheme.set_bar_color(_timer_bar, UiTheme.COL_BAD if left < time_limit * 0.3 else UiTheme.COL_ACCENT)
		_timer_label.text = "%d s" % ceili(left)
		if left <= 0.0:
			_active = false
			_input.editable = false
			_play("erreur")
			_show_feedback("Trop lent cette fois… Tu vas y arriver !", UiTheme.COL_BAD)
			_close_later({"status": "timeout"}, 1.8)


func _on_text_changed(_t: String) -> void:
	if _first_key_time < 0.0:
		_first_key_time = _elapsed
	_refresh_model()


## Affiche le modèle : les lettres bien tapées passent en vert, la première
## lettre différente en rouge (aide visuelle, réglable par l'ergothérapeute).
func _refresh_model() -> void:
	var typed := _input.text if _input != null else ""
	var out := "[center]"
	if not _color_help or typed == "":
		out += _escape(model_text)
	else:
		var good := UiTheme.COL_GOOD.darkened(0.15).to_html(false)
		var bad := UiTheme.COL_BAD.to_html(false)
		for i in model_text.length():
			var c := model_text[i]
			if i >= typed.length():
				out += _escape(c)
			elif _same(c, typed[i]):
				out += "[color=#%s]%s[/color]" % [good, _escape(c)]
			else:
				out += "[color=#%s][u]%s[/u][/color]" % [bad, _escape(c)]
	_model.text = out + "[/center]"


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


func _same(a: String, b: String) -> bool:
	return TypingCheck.strip_accents(a.to_lower()) == TypingCheck.strip_accents(b.to_lower())


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
		_play("ok")
		var msg := "Bravo !" if check["errors"] == 0 else "Bravo ! (petite faute acceptée)"
		_show_feedback(msg, UiTheme.COL_GOOD.darkened(0.1))
		var result := {"status": "ok", "cps": cps, "seconds": seconds, "check": check}
		validated.emit(result)
		_close_later(result, 0.95 if series else 0.7)
	else:
		_play("erreur")
		_show_feedback("Presque ! Regarde bien le modèle et corrige.", UiTheme.COL_WARN.darkened(0.3))
		_input.grab_focus()
		var tween := create_tween() # petite secousse
		for dx in [10.0, -8.0, 5.0, 0.0]:
			var shift: float = dx
			tween.tween_property(_panel, "position:x", _panel.position.x - (_panel.position.x - _base_x()) + shift, 0.05)


func _base_x() -> float:
	return size.x / 2.0 - 390.0


func _play(sound: String) -> void:
	if has_node("/root/Game"):
		get_node("/root/Game").play_sound(sound)


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
