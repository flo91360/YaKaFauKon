extends Control
## Panneau des compétences : niveau sur 10, barre d'avancement vers le niveau
## suivant, et conseils pour progresser. Les compétences qui demandent un achat
## du magasin sont annoncées en bas, avec un cadenas.

signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	var profile: Dictionary = get_node("/root/Game").profile
	var box := UiTheme.centered_panel(self, 1180)
	box.add_theme_constant_override("separation", 10)
	UiTheme.header(box, "Mes compétences", func(): closed.emit(), "etoile", UiTheme.COL_PURPLE)

	var available := Data.visible_skills(profile)
	var locked := []
	for s in Data.SKILLS:
		if not s in available:
			locked.append(s)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := (available.size() + 1) / 2
	scroll.custom_minimum_size = Vector2(0, minf(rows * 128.0 + (80.0 if not locked.is_empty() else 0.0), 548.0))
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for s in available:
		grid.add_child(_skill_card(profile, s))

	if not locked.is_empty():
		var lock_card := UiTheme.card(Color(0.93, 0.93, 0.95), 14)
		content.add_child(lock_card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		lock_card.add_child(row)
		row.add_child(UiTheme.badge("cadenas", UiTheme.COL_GREY, 38))
		var names := []
		for s in locked:
			names.append(Data.SKILLS[s]["label"].to_lower())
		var text := "À découvrir avec le magasin ou un travail : %s." % ", ".join(names)
		var label := UiTheme.label(text, 19, UiTheme.COL_TEXT.lightened(0.15))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		for s in locked:
			var badge := UiTheme.badge(s, UiTheme.SKILL_COLORS.get(s, UiTheme.COL_PURPLE).lerp(UiTheme.COL_GREY, 0.55), 30)
			row.add_child(badge)
		row.add_child(UiTheme.speak_button(func(): return text))


func _skill_card(profile: Dictionary, s: String) -> Control:
	var xp: float = profile["skills_xp"].get(s, 0.0)
	var level := Data.skill_level(xp)
	var color: Color = UiTheme.SKILL_COLORS.get(s, UiTheme.COL_PURPLE)
	var card := UiTheme.card(UiTheme.COL_SOFT, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(UiTheme.badge(s, color, 48))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var name_label := UiTheme.label(Data.SKILLS[s]["label"], 22)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.custom_minimum_size = Vector2(158, 0)
	top.add_child(name_label)
	top.add_child(_dots(level, color))
	var lvl := UiTheme.label("%d / 10" % level, 21)
	lvl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lvl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(lvl)
	# Barre vers le niveau suivant
	var bar_row := HBoxContainer.new()
	v.add_child(bar_row)
	var bar := UiTheme.bar(color, 14.0)
	bar_row.add_child(bar)
	var next := UiTheme.label("", 16, UiTheme.COL_TEXT.lightened(0.25))
	next.autowrap_mode = TextServer.AUTOWRAP_OFF
	bar_row.add_child(next)
	if level >= Data.SKILL_MAX:
		bar.value = 1.0
		next.text = "niveau maximum !"
	else:
		var from := float(Data.xp_for_level(level))
		var to := float(Data.xp_for_level(level + 1))
		bar.value = clampf((xp - from) / (to - from), 0.0, 1.0)
		next.text = "encore %d points" % ceili(to - xp)
	var help_row := HBoxContainer.new()
	v.add_child(help_row)
	var help_text := Data.skill_help(s, profile)
	var help := UiTheme.label(help_text, 16, UiTheme.COL_TEXT.lightened(0.2))
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.custom_minimum_size = Vector2(0, 44)
	help_row.add_child(help)
	var speak := UiTheme.speak_button(func(): return Data.SKILLS[s]["label"] + ". " + help_text)
	speak.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	help_row.add_child(speak)
	return card


## Dix pastilles : pleines jusqu'au niveau atteint.
func _dots(level: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in Data.SKILL_MAX:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.anti_aliasing = true
		style.bg_color = color if i < level else Color(0.84, 0.86, 0.9)
		dot.add_theme_stylebox_override("panel", style)
		row.add_child(dot)
	return row
