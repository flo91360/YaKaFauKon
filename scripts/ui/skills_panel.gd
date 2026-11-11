extends Control
## Panneau des compétences : niveau sur 10 et conseils pour progresser.

signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.12, 0.2, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var profile: Dictionary = get_node("/root/Game").profile
	var box := UiTheme.centered_panel(self, 900)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := UiTheme.label("Mes compétences", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiTheme.button("Fermer", Color(0.6, 0.62, 0.68), 22)
	close.pressed.connect(func(): closed.emit())
	header.add_child(close)

	for s in Data.active_skills():
		var xp: float = profile["skills_xp"].get(s, 0.0)
		var level := Data.skill_level(xp)
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = UiTheme.COL_SOFT
		style.set_corner_radius_all(16)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)
		box.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		var row := HBoxContainer.new()
		v.add_child(row)
		var name_label := UiTheme.label(Data.SKILLS[s]["label"], 26)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.custom_minimum_size = Vector2(190, 0)
		row.add_child(name_label)
		row.add_child(_stars(level))
		var lvl := UiTheme.label("%d / 10" % level, 24)
		lvl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lvl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(lvl)
		var help_row := HBoxContainer.new()
		v.add_child(help_row)
		var help_text: String = Data.SKILLS[s]["aide"]
		var help := UiTheme.label(help_text, 20, UiTheme.COL_TEXT.lightened(0.2))
		help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		help_row.add_child(help)
		help_row.add_child(UiTheme.speak_button(func(): return Data.SKILLS[s]["label"] + ". " + help_text))


## Dix pastilles : pleines jusqu'au niveau atteint.
func _stars(level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in Data.SKILL_MAX:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(22, 22)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(11)
		style.bg_color = Color(0.65, 0.5, 0.85) if i < level else Color(0.85, 0.86, 0.9)
		dot.add_theme_stylebox_override("panel", style)
		row.add_child(dot)
	return row
