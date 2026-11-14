extends Control
## « Construire » : l'enfant dépense le bois et les pierres récoltés dans le jardin.
## Chaque construction ajoute un objet et une activité (voir Data.CONSTRUCTIONS).

signal built(item: String)
signal garden_requested
signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Build = preload("res://scripts/core/build.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Hud = preload("res://scripts/ui/hud.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	var profile: Dictionary = get_node("/root/Game").profile
	var box := UiTheme.centered_panel(self, 1120)
	box.add_theme_constant_override("separation", 10)
	UiTheme.header(box, "Construire dans le jardin", func(): closed.emit(), "marteau", UiTheme.COL_ORANGE)

	# La réserve
	var intro := HBoxContainer.new()
	intro.add_theme_constant_override("separation", 8)
	box.add_child(intro)
	var have := []
	for res in Data.RESOURCE_ORDER:
		intro.add_child(UiTheme.badge(Data.RESOURCES[res]["icone"], UiTheme.RESOURCE_COLORS[res], 34))
		have.append(Data.resource_text(res, Build.stock(profile, res)))
	var intro_text := "Tu as %s. Avec le bois et les pierres du jardin, tu construis de nouvelles choses !" % " et ".join(have)
	var intro_label := UiTheme.label(intro_text, 22)
	intro_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_child(intro_label)
	intro.add_child(UiTheme.speak_button(func():
		var parts := [intro_text]
		for id in Data.CONSTRUCTION_ORDER:
			parts.append(_spoken(profile, id))
		return " ".join(parts)))

	for id in Data.CONSTRUCTION_ORDER:
		box.add_child(_row(profile, id))

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	box.add_child(foot)
	var foot_text := "Tu as tout construit. Bravo, ton jardin est magnifique !" if Build.next_item(profile) == "" \
		else "Pour récolter : va dans le jardin et clique sur le tas de bois ou sur les rochers. Un mot réussi = une bûche ou une pierre."
	var foot_label := UiTheme.label(foot_text, 19, UiTheme.COL_GOOD.darkened(0.2) if Build.next_item(profile) == "" else UiTheme.COL_TEXT.lightened(0.25))
	foot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(foot_label)
	var go := UiTheme.icon_button("feuille", "Aller au jardin", UiTheme.COL_GOOD, 20)
	go.name = "AllerAuJardin"
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func(): garden_requested.emit())
	foot.add_child(go)


func _spoken(profile: Dictionary, id: String) -> String:
	var item: Dictionary = Data.CONSTRUCTIONS[id]
	if Build.owns(profile, id):
		return "%s : déjà construit." % item["label"]
	var text := "%s : il faut %s. %s" % [item["label"], Build.cost_text(id), item["description"]]
	var advice := Build.advice(profile, id)
	return text + (" " + advice if advice != "" else " Tu peux le construire !")


func _row(profile: Dictionary, id: String) -> Control:
	var item: Dictionary = Data.CONSTRUCTIONS[id]
	var owned := Build.owns(profile, id)
	var color: Color = Hud.NEED_COLORS.get(item["icone"], UiTheme.COL_ORANGE)
	var card := UiTheme.card(Color(0.9, 0.96, 0.9) if owned else UiTheme.COL_SOFT, 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var need_badge := UiTheme.badge(item["icone"], color, 56)
	need_badge.tooltip_text = "Remonte : %s" % Data.NEEDS[item["icone"]]["label"].to_lower() if Data.NEEDS.has(item["icone"]) else ""
	need_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(need_badge)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var name_label := UiTheme.label(item["label"], 24)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(name_label)
	v.add_child(UiTheme.label(item["description"], 18, UiTheme.COL_TEXT.lightened(0.2)))
	if not owned:
		v.add_child(_needs_row(profile, id))

	var action := VBoxContainer.new()
	action.custom_minimum_size = Vector2(250, 0)
	action.alignment = BoxContainer.ALIGNMENT_CENTER
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	if owned:
		var done := HBoxContainer.new()
		done.alignment = BoxContainer.ALIGNMENT_END
		action.add_child(done)
		done.add_child(UiTheme.badge("coche", UiTheme.COL_GOOD, 34))
		var mine := UiTheme.label("Déjà construit", 21, UiTheme.COL_GOOD.darkened(0.25))
		mine.autowrap_mode = TextServer.AUTOWRAP_OFF
		done.add_child(mine)
		return card
	var ready := Build.can_build(profile, id)
	var build := UiTheme.icon_button("marteau" if ready else "cadenas", "Construire" if ready else "Pas encore", UiTheme.COL_GOOD if ready else UiTheme.COL_GREY, 21)
	build.disabled = not ready
	build.name = "Construire_" + id
	build.pressed.connect(func(): built.emit(id))
	action.add_child(build)
	return card


## Ce que la construction demande : ressources (« 3 / 6 ») et compétences, en vert quand c'est bon.
func _needs_row(profile: Dictionary, id: String) -> Control:
	var item: Dictionary = Data.CONSTRUCTIONS[id]
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var ok_color := UiTheme.COL_GOOD.darkened(0.25)
	var lack_color := UiTheme.COL_BAD.darkened(0.1)
	for res in Data.RESOURCE_ORDER:
		if not item["cout"].has(res):
			continue
		var need := int(item["cout"][res])
		var have := mini(Build.stock(profile, res), need)
		line.add_child(UiTheme.badge(Data.RESOURCES[res]["icone"], UiTheme.RESOURCE_COLORS[res], 28))
		var l := UiTheme.label("%d / %s" % [have, Data.resource_text(res, need)], 19, ok_color if have >= need else lack_color)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(l)
		line.add_child(_gap())
	for s in item["competences"]:
		var level := int(item["competences"][s])
		var reached := Progression.skill_level(profile, s) >= level
		line.add_child(UiTheme.badge(s, UiTheme.SKILL_COLORS.get(s, UiTheme.COL_PURPLE), 28))
		var l := UiTheme.label("%s niveau %d" % [Data.SKILLS[s]["label"], level], 19, ok_color if reached else lack_color)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.add_child(l)
		line.add_child(_gap())
	return line


func _gap() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(10, 0)
	return c
