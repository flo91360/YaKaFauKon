extends Control
## Panneau « Mon travail » : choisir une carrière, voir son palier,
## ce qu'il faut pour monter, et changer de carrière (à partir du palier 2).

signal closed
signal career_chosen(career: String)
signal mission_requested

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Dreams = preload("res://scripts/core/dreams.gd")

var mission_available := false
var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	_box = UiTheme.centered_panel(self, 1180)
	_box.add_theme_constant_override("separation", 10)
	var profile: Dictionary = get_node("/root/Game").profile
	if profile["career"]["current"] == "":
		_show_choice(profile, false)
	else:
		_show_status(profile)


func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func _header(text: String, icon_name := "travail", color := UiTheme.COL_ORANGE) -> void:
	UiTheme.header(_box, text, func(): closed.emit(), icon_name, color)


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
		_box.add_child(UiTheme.label("Tu gardes ton palier actuel. Le nouveau travail commence au palier 1 (ou reprend là où tu l'avais laissé). Tes compétences restent.", 19))
	var dream_career := _dream_career(profile)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_box.add_child(grid)
	for c in Data.CAREER_ORDER:
		if c == profile["career"]["current"]:
			continue
		grid.add_child(_career_card(profile, c, c == dream_career))
	if changing:
		var back := UiTheme.button("Retour", Color(0.6, 0.62, 0.68))
		back.pressed.connect(func(): _show_status(profile))
		_box.add_child(back)


## Carrière du rêve en cours ("" si le rêve n'est pas un métier).
func _dream_career(profile: Dictionary) -> String:
	var dream := Dreams.current(profile)
	return Data.DREAMS[dream]["career"] if dream != "" else ""


func _career_card(profile: Dictionary, c: String, is_dream: bool) -> Control:
	var info: Dictionary = Data.CAREERS[c]
	var color: Color = UiTheme.CAREER_COLORS.get(c, UiTheme.COL_ORANGE)
	var card := UiTheme.card(Color(1.0, 0.96, 0.82) if is_dream else UiTheme.COL_SOFT, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(560, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(UiTheme.badge(info["icone"], color, 50))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	v.add_child(name_row)
	var name_label := UiTheme.label(info["label"], 23)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_row.add_child(name_label)
	if is_dream:
		name_row.add_child(UiTheme.icon("reve", 24, UiTheme.COL_DREAM))
		var dream_label := UiTheme.label("ton rêve", 17, UiTheme.COL_DREAM.darkened(0.25))
		dream_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_row.add_child(dream_label)
	var description: String = info["description"]
	var known: int = profile["career"]["tiers"].get(c, 0)
	if known > 0:
		description += " Tu étais au palier %d." % known
	var text := UiTheme.label(description, 17, UiTheme.COL_TEXT.lightened(0.15))
	text.custom_minimum_size = Vector2(0, 46)
	v.add_child(text)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)
	var choose := UiTheme.icon_button("coche", "Choisir", UiTheme.COL_GOOD, 19)
	choose.name = "Choisir_" + c
	choose.pressed.connect(func(): career_chosen.emit(c))
	side.add_child(choose)
	side.add_child(UiTheme.speak_button(func(): return info["label"] + ". " + description))
	return card


func _show_status(profile: Dictionary) -> void:
	_clear()
	var c: String = profile["career"]["current"]
	var info: Dictionary = Data.CAREERS[c]
	var tier := Progression.current_tier(profile)
	var tier_info: Dictionary = info["tiers"][tier - 1]
	_header(info["label"], info["icone"], UiTheme.CAREER_COLORS.get(c, UiTheme.COL_ORANGE))
	if c == _dream_career(profile):
		var dream_row := HBoxContainer.new()
		dream_row.add_theme_constant_override("separation", 8)
		_box.add_child(dream_row)
		dream_row.add_child(UiTheme.icon("reve", 26, UiTheme.COL_DREAM))
		var dream_label := UiTheme.label("C'est le travail de ton rêve : chaque palier te rapproche de lui.", 20, UiTheme.COL_DREAM.darkened(0.3))
		dream_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dream_row.add_child(dream_label)

	var v := _card()
	v.add_child(UiTheme.label("Palier %d sur 5 : %s" % [tier, tier_info["title"]], 26))
	v.add_child(UiTheme.label("Salaire : %d pièces par mission réussie" % tier_info["salary"], 22))
	if tier < 5:
		var done: int = profile["career"]["missions"].get(c, 0)
		v.add_child(UiTheme.label("Missions réussies à ce palier : %d sur %d" % [mini(done, Data.MISSIONS_PER_TIER), Data.MISSIONS_PER_TIER], 22))
		var missions_bar := UiTheme.bar(UiTheme.COL_ORANGE, 20.0, Data.MISSIONS_PER_TIER)
		missions_bar.value = mini(done, Data.MISSIONS_PER_TIER)
		v.add_child(missions_bar)
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
			var req_row := HBoxContainer.new()
			nv.add_child(req_row)
			req_row.add_child(UiTheme.badge("coche" if ok else s, UiTheme.COL_GOOD if ok else UiTheme.SKILL_COLORS.get(s, UiTheme.COL_PURPLE), 30))
			var req_label := UiTheme.label(line, 21, UiTheme.COL_GOOD.darkened(0.2) if ok else UiTheme.COL_TEXT)
			req_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			req_label.custom_minimum_size = Vector2(330, 0)
			req_row.add_child(req_label)
			var req_bar := UiTheme.bar(UiTheme.COL_GOOD if ok else UiTheme.SKILL_COLORS.get(s, UiTheme.COL_PURPLE), 18.0, float(req[s]))
			req_bar.value = minf(have, req[s])
			req_row.add_child(req_bar)
		nv.add_child(UiTheme.speak_button(func(): return "Pour devenir " + next["title"] + ", il faut : " + ", ".join(lines)))
	else:
		v.add_child(UiTheme.label("Tu es au plus haut palier. Bravo !", 22, UiTheme.COL_GOOD))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(buttons)
	if mission_available:
		var go := UiTheme.icon_button("drapeau", "Faire la mission", UiTheme.COL_CORAL)
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
