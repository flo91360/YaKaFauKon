extends Control
## Panneau des compétences : niveau sur 10, barre d'avancement vers le niveau
## suivant, et conseils pour progresser.

signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	var profile: Dictionary = get_node("/root/Game").profile
	var box := UiTheme.centered_panel(self, 960)
	box.add_theme_constant_override("separation", 10)
	UiTheme.header(box, "Mes compétences", func(): closed.emit(), "etoile", UiTheme.COL_PURPLE)

	for s in Data.active_skills():
		var xp: float = profile["skills_xp"].get(s, 0.0)
		var level := Data.skill_level(xp)
		var color: Color = UiTheme.SKILL_COLORS.get(s, UiTheme.COL_PURPLE)
		var card := UiTheme.card(UiTheme.COL_SOFT, 16)
		box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		row.add_child(UiTheme.badge(s, color, 54))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var top := HBoxContainer.new()
		v.add_child(top)
		var name_label := UiTheme.label(Data.SKILLS[s]["label"], 25)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.custom_minimum_size = Vector2(170, 0)
		top.add_child(name_label)
		top.add_child(_dots(level, color))
		var lvl := UiTheme.label("%d / 10" % level, 23)
		lvl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lvl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(lvl)
		# Barre vers le niveau suivant
		var bar_row := HBoxContainer.new()
		v.add_child(bar_row)
		var bar := UiTheme.bar(color, 16.0)
		bar_row.add_child(bar)
		var next := UiTheme.label("", 17, UiTheme.COL_TEXT.lightened(0.25))
		next.autowrap_mode = TextServer.AUTOWRAP_OFF
		bar_row.add_child(next)
		if level >= Data.SKILL_MAX:
			bar.value = 1.0
			next.text = "niveau maximum !"
		else:
			var from := float(Data.xp_for_level(level))
			var to := float(Data.xp_for_level(level + 1))
			bar.value = clampf((xp - from) / (to - from), 0.0, 1.0)
			next.text = "encore %d points pour le niveau %d" % [ceili(to - xp), level + 1]
		var help_row := HBoxContainer.new()
		v.add_child(help_row)
		var help_text: String = Data.SKILLS[s]["aide"]
		var help := UiTheme.label(help_text, 18, UiTheme.COL_TEXT.lightened(0.2))
		help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		help_row.add_child(help)
		help_row.add_child(UiTheme.speak_button(func(): return Data.SKILLS[s]["label"] + ". " + help_text))


## Dix pastilles : pleines jusqu'au niveau atteint.
func _dots(level: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in Data.SKILL_MAX:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(20, 20)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.anti_aliasing = true
		style.bg_color = color if i < level else Color(0.84, 0.86, 0.9)
		dot.add_theme_stylebox_override("panel", style)
		row.add_child(dot)
	return row
