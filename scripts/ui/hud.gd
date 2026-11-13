extends Control
## Interface permanente : jauges avec pictogrammes, pièces, étoiles, heure,
## objectif en cours avec sa barre, boutons, et ce que fait le personnage.

signal skills_pressed
signal career_pressed
signal pause_pressed
signal mission_pressed
signal guide_pressed
signal objective_pressed
signal shop_pressed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Objectives = preload("res://scripts/core/objectives.gd")
const Shop = preload("res://scripts/core/shop.gd")

const NEED_COLORS := {"faim": Color(0.93, 0.55, 0.3), "sommeil": Color(0.45, 0.5, 0.85), "toilettes": Color(0.3, 0.68, 0.7),
	"hygiene": Color(0.35, 0.62, 0.9), "social": Color(0.9, 0.5, 0.68)}

var needs_panel: PanelContainer
var buttons_row: HBoxContainer
var objective_panel: PanelContainer

var _bars := {}
var _badges := {}
var _rows := {}
var _money: Label
var _stars: Label
var _clock: Label
var _clock_icon: TextureRect
var _status_panel: PanelContainer
var _status: Label
var _action_bar: ProgressBar
var _toast_box: VBoxContainer
var _mission_button: Button
var _shop_button: Button
var _obj_title: Label
var _obj_text: Label
var _obj_bar: ProgressBar
var _obj_progress: Label
var _obj_button: Button
var _obj_reward: Label
var _time := 0.0
var _shown_money := -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- Jauges (en haut à gauche) ---
	var left := VBoxContainer.new()
	left.position = Vector2(14, 14)
	left.add_theme_constant_override("separation", 10)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	needs_panel = PanelContainer.new()
	needs_panel.add_theme_stylebox_override("panel", _panel_style(14, 12))
	left.add_child(needs_panel)
	var needs_box := VBoxContainer.new()
	needs_box.add_theme_constant_override("separation", 7)
	needs_panel.add_child(needs_box)
	for n in Data.NEED_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = Data.NEEDS[n]["conseil"]
		needs_box.add_child(row)
		var badge := UiTheme.badge(n, NEED_COLORS[n], 30)
		row.add_child(badge)
		var l := UiTheme.label(Data.NEEDS[n]["label"], 18)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size = Vector2(98, 0)
		row.add_child(l)
		var bar := UiTheme.bar(UiTheme.COL_GOOD, 18.0, 100.0)
		bar.custom_minimum_size = Vector2(150, 18)
		row.add_child(bar)
		_bars[n] = bar
		_badges[n] = badge
		_rows[n] = row

	# --- Objectif en cours (sous les jauges) ---
	objective_panel = PanelContainer.new()
	objective_panel.add_theme_stylebox_override("panel", _panel_style(14, 10))
	objective_panel.custom_minimum_size = Vector2(318, 0)
	left.add_child(objective_panel)
	var obj_box := VBoxContainer.new()
	obj_box.add_theme_constant_override("separation", 5)
	objective_panel.add_child(obj_box)
	var obj_head := HBoxContainer.new()
	obj_head.add_theme_constant_override("separation", 8)
	obj_box.add_child(obj_head)
	obj_head.add_child(UiTheme.badge("cible", UiTheme.COL_CORAL, 28))
	_obj_title = UiTheme.label("Mon objectif", 17, UiTheme.COL_TEXT.lightened(0.25))
	_obj_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_obj_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_head.add_child(_obj_title)
	obj_head.add_child(UiTheme.icon("piece", 20, UiTheme.COL_GOLD))
	_obj_reward = UiTheme.label("", 17, UiTheme.COL_TEXT)
	_obj_reward.autowrap_mode = TextServer.AUTOWRAP_OFF
	obj_head.add_child(_obj_reward)
	_obj_text = UiTheme.label("", 18)
	_obj_text.custom_minimum_size = Vector2(290, 0)
	obj_box.add_child(_obj_text)
	var obj_row := HBoxContainer.new()
	obj_box.add_child(obj_row)
	_obj_bar = UiTheme.bar(UiTheme.COL_CORAL, 16.0)
	obj_row.add_child(_obj_bar)
	_obj_progress = UiTheme.label("", 16, UiTheme.COL_TEXT.lightened(0.15))
	_obj_progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	obj_row.add_child(_obj_progress)
	_obj_button = UiTheme.icon_button("cible", "Choisir un objectif", UiTheme.COL_CORAL, 18)
	_obj_button.focus_mode = Control.FOCUS_NONE
	_obj_button.pressed.connect(func(): objective_pressed.emit())
	obj_box.add_child(_obj_button)

	# --- Pièces, étoiles, heure et boutons (en haut à droite) ---
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_left = -14
	right.offset_right = -14
	right.offset_top = 14
	right.add_theme_constant_override("separation", 10)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", _panel_style(16, 8))
	info_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(info_panel)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info_panel.add_child(info)
	info.add_child(UiTheme.badge("piece", UiTheme.COL_GOLD, 30))
	_money = UiTheme.label("0", 22)
	_money.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(_money)
	info.add_child(_spacer(6))
	info.add_child(UiTheme.icon("etoile", 26, UiTheme.COL_GOLD))
	_stars = UiTheme.label("0", 22)
	_stars.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(_stars)
	info.add_child(_spacer(6))
	_clock_icon = UiTheme.icon("soleil", 26, UiTheme.COL_ORANGE)
	info.add_child(_clock_icon)
	_clock = UiTheme.label("", 22)
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.add_child(_clock)
	buttons_row = HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_END
	buttons_row.add_theme_constant_override("separation", 8)
	right.add_child(buttons_row)
	_shop_button = _add_button("magasin", "Magasin", UiTheme.COL_ACCENT, func(): shop_pressed.emit())
	_shop_button.tooltip_text = "Dépense tes pièces pour agrandir ta maison"
	_add_button("etoile", "Compétences", UiTheme.COL_PURPLE, func(): skills_pressed.emit())
	_add_button("travail", "Travail", UiTheme.COL_ORANGE, func(): career_pressed.emit())
	_add_button("livre", "Guide", UiTheme.COL_TEAL, func(): guide_pressed.emit())
	var b_pause := _add_button("pause", "", UiTheme.COL_GREY, func(): pause_pressed.emit())
	b_pause.tooltip_text = "Pause et réglages"
	_mission_button = UiTheme.icon_button("drapeau", "Nouvelle mission !", UiTheme.COL_CORAL, 20)
	_mission_button.focus_mode = Control.FOCUS_NONE
	_mission_button.visible = false
	_mission_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_mission_button.pressed.connect(func(): mission_pressed.emit())
	right.add_child(_mission_button)

	# --- Ce que fait le personnage (en bas à gauche) ---
	_status_panel = PanelContainer.new()
	_status_panel.add_theme_stylebox_override("panel", _panel_style(16, 10))
	_status_panel.anchor_top = 1.0
	_status_panel.anchor_bottom = 1.0
	_status_panel.offset_left = 14
	_status_panel.offset_top = -86
	_status_panel.offset_bottom = -14
	_status_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status_panel.custom_minimum_size = Vector2(330, 0)
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_panel.visible = false
	add_child(_status_panel)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 6)
	_status_panel.add_child(status_box)
	_status = UiTheme.label("", 20)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_box.add_child(_status)
	_action_bar = UiTheme.bar(UiTheme.COL_ACCENT, 16.0)
	status_box.add_child(_action_bar)

	# --- Messages (en haut au centre) ---
	_toast_box = VBoxContainer.new()
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_left = -250
	_toast_box.offset_right = 250
	_toast_box.offset_top = 14
	_toast_box.add_theme_constant_override("separation", 8)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_box)


func _panel_style(margin_h: int, margin_v: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = get_theme_stylebox("panel", "PanelContainer").duplicate()
	style.bg_color = Color(0.99, 0.97, 0.93, 0.94)
	style.set_corner_radius_all(18)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	style.shadow_size = 8
	return style


func _spacer(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0)
	return c


func _add_button(icon_name: String, text: String, color: Color, action: Callable) -> Button:
	var b := UiTheme.icon_button(icon_name, text, color, 19)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	buttons_row.add_child(b)
	return b


## `action_fraction` : avancement de l'action en cours (0 à 1), ou -1 s'il n'y en a pas.
func update_display(profile: Dictionary, status_text: String, action_fraction := -1.0) -> void:
	var delta := get_process_delta_time()
	_time += delta
	for n in _bars:
		var v: float = profile["needs"][n]
		_bars[n].value = v
		UiTheme.set_bar_color(_bars[n], UiTheme.need_color(v))
		# La ligne clignote doucement quand la jauge est dans le rouge.
		var red: bool = v < Data.RED_THRESHOLD
		_rows[n].modulate.a = 0.55 + 0.45 * absf(sin(_time * 4.0)) if red else 1.0
		var style: StyleBoxFlat = _badges[n].get_meta("style")
		style.bg_color = UiTheme.COL_BAD if red else NEED_COLORS[n]
	# Les pièces défilent jusqu'au nouveau total.
	var money := float(profile["money"])
	if _shown_money < 0.0:
		_shown_money = money
	_shown_money = move_toward(_shown_money, money, maxf(absf(money - _shown_money) * 4.0, 20.0) * delta)
	_money.text = "%d" % roundi(_shown_money)
	_stars.text = "%d" % int(profile.get("etoiles", 0))
	var minutes := int(profile["game_minutes"])
	var hour := (minutes % 1440) / 60
	_clock.text = "Jour %d · %02d:%02d" % [minutes / 1440 + 1, hour, minutes % 60]
	var night := hour < 7 or hour >= 21
	_clock_icon.texture = UiTheme.icon_texture("sommeil" if night else "soleil")
	_clock_icon.modulate = Color(0.45, 0.5, 0.85) if night else UiTheme.COL_ORANGE
	_status_panel.visible = status_text != ""
	_status.text = status_text
	_action_bar.visible = action_fraction >= 0.0
	_status_panel.offset_top = -86.0 if action_fraction >= 0.0 else -62.0
	_action_bar.value = clampf(action_fraction, 0.0, 1.0)
	_update_objective(profile)
	# Le bouton du magasin brille quand l'enfant peut s'offrir quelque chose.
	var can_buy := false
	for id in Data.SHOP_ORDER:
		can_buy = can_buy or Shop.can_buy(profile, id)
	_shop_button.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.25, 1.0), 0.5 + 0.5 * sin(_time * 5.0)) if can_buy else Color.WHITE
	if _mission_button.visible:
		_mission_button.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.2, 1.0), 0.5 + 0.5 * sin(_time * 5.0))


func _update_objective(profile: Dictionary) -> void:
	var o := Objectives.current(profile)
	var has := not o.is_empty()
	var done := has and Objectives.is_done(profile)
	_obj_text.visible = has
	_obj_bar.get_parent().visible = has and not done
	_obj_reward.get_parent().get_child(2).visible = has
	_obj_reward.visible = has
	_obj_button.visible = not has or done
	if has:
		_obj_text.text = o["label"]
		_obj_reward.text = "+%d" % int(o["pieces"])
		_obj_bar.value = lerpf(_obj_bar.value, Objectives.fraction(profile), 0.15)
		_obj_progress.text = Objectives.progress_text(profile)
	if done:
		_obj_button.text = "Objectif atteint ! Clique ici"
		UiTheme.set_bar_color(_obj_bar, UiTheme.COL_GOLD)
		_obj_button.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.25, 1.0), 0.5 + 0.5 * sin(_time * 6.0))
	else:
		_obj_button.text = "Choisir un objectif"
		_obj_button.modulate = Color(1, 1, 1).lerp(Color(1.2, 1.15, 1.0), 0.5 + 0.5 * sin(_time * 3.0))
		UiTheme.set_bar_color(_obj_bar, UiTheme.COL_CORAL)


func set_mission_available(on: bool) -> void:
	_mission_button.visible = on


func toast(text: String, color := UiTheme.COL_ACCENT, seconds := 3.5, icon_name := "") -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	style.anti_aliasing = true
	style.border_color = color.darkened(0.2)
	style.border_width_bottom = 4
	style.shadow_color = Color(0.1, 0.12, 0.25, 0.25)
	style.shadow_size = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	if icon_name != "":
		row.add_child(UiTheme.icon(icon_name, 28))
	var l := UiTheme.label(text, 21, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	_toast_box.add_child(panel)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).free()
	panel.pivot_offset = Vector2(250, 20)
	panel.scale = Vector2(0.85, 0.85)
	var tween := panel.create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(seconds)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)
