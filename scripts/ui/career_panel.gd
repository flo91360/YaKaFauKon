extends Control
## Panneau « Mon travail » : choisir une carrière, voir son palier,
## ce qu'il faut pour monter, et changer de carrière (à partir du palier 2).

signal closed
signal career_chosen(career: String)
signal mission_requested

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")

var mission_available := false
var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.12, 0.2, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_box = UiTheme.centered_panel(self, 900)
	var profile: Dictionary = get_node("/root/Game").profile
	if profile["career"]["current"] == "":
		_show_choice(profile, false)
	else:
		_show_status(profile)


func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func _header(text: String) -> void:
	var header := HBoxContainer.new()
	_box.add_child(header)
	var title := UiTheme.label(text, 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiTheme.button("Fermer", Color(0.6, 0.62, 0.68), 22)
	close.pressed.connect(func(): closed.emit())
	header.add_child(close)


func _card() -> VBoxContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.COL_SOFT
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	_box.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	return v


func _show_choice(profile: Dictionary, changing: bool) -> void:
	_clear()
	_header("Change de travail" if changing else "Choisis ton travail")
	if changing:
		_box.add_child(UiTheme.label("Tu gardes ton palier actuel. Le nouveau travail commence au palier 1 (ou reprend là où tu l'avais laissé). Tes compétences restent.", 20))
	for c in Data.CAREERS:
		if c == profile["career"]["current"]:
			continue
		var info: Dictionary = Data.CAREERS[c]
		var v := _card()
		var row := HBoxContainer.new()
		v.add_child(row)
		var name_label := UiTheme.label(info["label"], 28)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(UiTheme.speak_button(func(): return info["label"] + ". " + info["description"]))
		v.add_child(UiTheme.label(info["description"], 22))
		var known: int = profile["career"]["tiers"].get(c, 0)
		if known > 0:
			v.add_child(UiTheme.label("Tu étais au palier %d." % known, 20, UiTheme.COL_ACCENT))
		var choose := UiTheme.button("Choisir ce travail", UiTheme.COL_GOOD)
		choose.pressed.connect(func(): career_chosen.emit(c))
		v.add_child(choose)
	if changing:
		var back := UiTheme.button("Retour", Color(0.6, 0.62, 0.68))
		back.pressed.connect(func(): _show_status(profile))
		_box.add_child(back)


func _show_status(profile: Dictionary) -> void:
	_clear()
	var c: String = profile["career"]["current"]
	var info: Dictionary = Data.CAREERS[c]
	var tier := Progression.current_tier(profile)
	var tier_info: Dictionary = info["tiers"][tier - 1]
	_header(info["label"])

	var v := _card()
	v.add_child(UiTheme.label("Palier %d sur 5 : %s" % [tier, tier_info["title"]], 26))
	v.add_child(UiTheme.label("Salaire : %d pièces par mission réussie" % tier_info["salary"], 22))
	if tier < 5:
		var done: int = profile["career"]["missions"].get(c, 0)
		v.add_child(UiTheme.label("Missions réussies à ce palier : %d sur %d" % [mini(done, Data.MISSIONS_PER_TIER), Data.MISSIONS_PER_TIER], 22))
		var next: Dictionary = info["tiers"][tier]
		var req: Dictionary = next["req"]
		var nv := _card()
		nv.add_child(UiTheme.label("Pour devenir « %s » :" % next["title"], 24))
		var lines := ["%d missions réussies" % Data.MISSIONS_PER_TIER]
		for s in req:
			var have := Progression.skill_level(profile, s)
			var ok: bool = have >= req[s]
			var line := "%s %d sur 10 (tu as %d)" % [Data.SKILLS[s]["label"], req[s], have]
			lines.append(line)
			nv.add_child(UiTheme.label(("✔ " if ok else "• ") + line, 22, UiTheme.COL_GOOD.darkened(0.2) if ok else UiTheme.COL_TEXT))
		nv.add_child(UiTheme.speak_button(func(): return "Pour devenir " + next["title"] + ", il faut : " + ", ".join(lines)))
	else:
		v.add_child(UiTheme.label("Tu es au plus haut palier. Bravo !", 22, UiTheme.COL_GOOD))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(buttons)
	if mission_available:
		var go := UiTheme.button("Faire la mission", Color(0.95, 0.5, 0.45))
		go.pressed.connect(func(): mission_requested.emit())
		buttons.add_child(go)
	var change := UiTheme.button("Changer de travail", Color(0.6, 0.62, 0.68))
	if Progression.can_change_career(profile):
		change.pressed.connect(func(): _show_choice(profile, true))
	else:
		change.disabled = true
		change.tooltip_text = "Possible à partir du palier %d" % Data.CAREER_CHANGE_MIN_TIER
		_box.add_child(UiTheme.label("Tu pourras changer de travail à partir du palier %d." % Data.CAREER_CHANGE_MIN_TIER, 20, UiTheme.COL_TEXT.lightened(0.3)))
	buttons.add_child(change)
