extends Control
## Magasin : l'enfant dépense ses pièces pour agrandir sa maison. Chaque achat
## ajoute un objet et une nouvelle activité (voir Data.SHOP).

signal bought(item: String)
signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Shop = preload("res://scripts/core/shop.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	var profile: Dictionary = get_node("/root/Game").profile
	var money := int(profile["money"])
	var box := UiTheme.centered_panel(self, 1120)
	box.add_theme_constant_override("separation", 10)
	UiTheme.header(box, "Le magasin", func(): closed.emit(), "magasin", UiTheme.COL_ACCENT)

	var intro := HBoxContainer.new()
	box.add_child(intro)
	intro.add_child(UiTheme.badge("piece", UiTheme.COL_GOLD, 34))
	var intro_text := "Tu as %d pièce%s. Achète de nouvelles choses pour agrandir ta maison !" % [money, "" if money == 1 else "s"]
	var intro_label := UiTheme.label(intro_text, 22)
	intro_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.add_child(intro_label)
	intro.add_child(UiTheme.speak_button(func():
		var parts := [intro_text]
		for id in Data.SHOP_ORDER:
			parts.append(_spoken(profile, id))
		return " ".join(parts)))

	for id in Data.SHOP_ORDER:
		box.add_child(_row(profile, id))
	if Shop.next_item(profile) == "":
		box.add_child(UiTheme.label("Tu as tout acheté. Bravo, ta maison est très bien équipée !", 20, UiTheme.COL_GOOD.darkened(0.2)))
	else:
		box.add_child(UiTheme.label("Pour gagner des pièces : atteins tes objectifs et réussis des missions de travail.", 19, UiTheme.COL_TEXT.lightened(0.25)))


func _spoken(profile: Dictionary, id: String) -> String:
	var item: Dictionary = Data.SHOP[id]
	if Shop.owns(profile, id):
		return "%s : déjà à toi." % item["label"]
	return "%s : %d pièces. %s" % [item["label"], int(item["prix"]), item["description"]]


func _row(profile: Dictionary, id: String) -> Control:
	var item: Dictionary = Data.SHOP[id]
	var owned := Shop.owns(profile, id)
	var skills: Dictionary = Data.ACTIONS[item["action"]]["skills"]
	var color: Color = UiTheme.SKILL_COLORS.get(item["icone"], UiTheme.COL_ACCENT)
	var card := UiTheme.card(Color(0.9, 0.96, 0.9) if owned else UiTheme.COL_SOFT, 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(UiTheme.badge(item["icone"], color, 56))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var name_label := UiTheme.label(item["label"], 24)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(name_label)
	v.add_child(UiTheme.label(item["description"], 18, UiTheme.COL_TEXT.lightened(0.2)))

	# Compétences que l'achat permet d'entraîner
	var trained := HBoxContainer.new()
	trained.add_theme_constant_override("separation", 4)
	trained.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(trained)
	var names := []
	for s in skills:
		trained.add_child(UiTheme.badge(s, UiTheme.SKILL_COLORS.get(s, UiTheme.COL_PURPLE), 30))
		names.append(Data.SKILLS[s]["label"].to_lower())
	trained.tooltip_text = "Entraîne : " + ", ".join(names)
	trained.mouse_filter = Control.MOUSE_FILTER_STOP

	var action := HBoxContainer.new()
	action.custom_minimum_size = Vector2(330, 0)
	action.alignment = BoxContainer.ALIGNMENT_END
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	if owned:
		action.add_child(UiTheme.badge("coche", UiTheme.COL_GOOD, 34))
		var mine := UiTheme.label("Déjà à toi", 21, UiTheme.COL_GOOD.darkened(0.25))
		mine.autowrap_mode = TextServer.AUTOWRAP_OFF
		action.add_child(mine)
		return card
	action.add_child(UiTheme.icon("piece", 28, UiTheme.COL_GOLD))
	var price := UiTheme.label("%d" % int(item["prix"]), 24)
	price.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.custom_minimum_size = Vector2(48, 0)
	action.add_child(price)
	var lack := Shop.missing(profile, id)
	var buy := UiTheme.icon_button("magasin" if lack == 0 else "cadenas", "Acheter" if lack == 0 else "Encore %d pièce%s" % [lack, "" if lack == 1 else "s"],
		UiTheme.COL_GOOD if lack == 0 else UiTheme.COL_GREY, 21)
	buy.custom_minimum_size = Vector2(230, 0)
	buy.disabled = lack > 0
	buy.name = "Acheter_" + id
	buy.pressed.connect(func(): bought.emit(id))
	action.add_child(buy)
	return card
