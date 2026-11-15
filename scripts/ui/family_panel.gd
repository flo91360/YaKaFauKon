extends Control
## « Ma famille » : rencontrer quelqu'un (une femme ou un homme, l'enfant choisit),
## suivre la complicité, vivre ensemble, puis avoir des enfants ou non.
## Les choix passent par des signaux : l'écran de jeu les applique (voir game.gd).

signal met(person: Dictionary)
signal moved_in
signal baby_chosen(child: Dictionary)
signal declined
signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Family = preload("res://scripts/core/family.gd")
const Portrait = preload("res://scripts/ui/portrait.gd")

const COL_FAMILY := Color(0.93, 0.45, 0.58)

## Personnes proposées à la rencontre (gardées tant que le panneau est ouvert).
var people: Array = []
var _box: VBoxContainer
var _profile: Dictionary


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	_box = UiTheme.centered_panel(self, 1160)
	_box.add_theme_constant_override("separation", 12)
	_profile = get_node("/root/Game").profile
	refresh()


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func refresh() -> void:
	_clear()
	if Family.has_partner(_profile):
		_show_family()
	else:
		_show_meeting()


func _head(text: String, icon_name: String, spoken: Callable) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_box.add_child(head)
	head.add_child(UiTheme.badge(icon_name, COL_FAMILY, 46))
	var title := UiTheme.label(text, 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.speak_button(spoken))
	var close := UiTheme.icon_button("croix", "Fermer", UiTheme.COL_GREY, 20)
	close.name = "Fermer"
	close.pressed.connect(func(): closed.emit())
	head.add_child(close)


# --- Rencontrer quelqu'un -------------------------------------------------------------

func _show_meeting() -> void:
	if people.is_empty():
		people = Family.proposals()
	var intro := "Tu peux rencontrer quelqu'un. Une femme ou un homme : c'est toi qui choisis la personne qui te plaît."
	var lack := Family.missing_skills(_profile, Data.FAMILY_MEET_SKILLS)
	_head("Rencontrer quelqu'un", "couple", func():
		var parts := [intro]
		for p in people:
			parts.append("%s aime %s." % [p["nom"], p["aime"]])
		if not lack.is_empty():
			parts.append(Family.advice(_profile))
		return " ".join(parts))
	_box.add_child(UiTheme.label(intro, 20, UiTheme.COL_TEXT.lightened(0.15)))
	if not lack.is_empty():
		var warn := UiTheme.card(Color(1.0, 0.94, 0.84), 12)
		warn.add_child(UiTheme.label(Family.advice(_profile), 19, UiTheme.COL_TEXT))
		_box.add_child(warn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	for i in people.size():
		row.add_child(_person_card(people[i], i, lack.is_empty()))
	_box.add_child(UiTheme.label("Ce n'est pas obligatoire : tu peux aussi attendre et revenir plus tard.", 17, UiTheme.COL_TEXT.lightened(0.3)))


func _person_card(person: Dictionary, index: int, can: bool) -> Control:
	var card := UiTheme.card(UiTheme.COL_SOFT, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var portrait := Portrait.new()
	portrait.setup(person["apparence"], "adulte", Vector2(240, 230))
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(portrait)
	var name_label := UiTheme.label(person["nom"], 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var likes := UiTheme.label("Aime %s" % person["aime"], 18, UiTheme.COL_TEXT.lightened(0.2))
	likes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(likes)
	var b := UiTheme.icon_button("coeur", "Rencontrer", COL_FAMILY if can else UiTheme.COL_GREY, 20)
	b.name = "Rencontrer_%d" % index
	b.disabled = not can
	b.pressed.connect(func(): met.emit(person))
	v.add_child(b)
	return card


# --- La famille -----------------------------------------------------------------------

func _show_family() -> void:
	var partner := Family.partner(_profile)
	var together := Family.is_together(_profile)
	_head("Ma famille", "famille" if together else "couple", func(): return _spoken())
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_box.add_child(top)
	var portrait := Portrait.new()
	portrait.setup(partner["apparence"], "adulte", Vector2(230, 230))
	top.add_child(portrait)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(v)
	v.add_child(UiTheme.label(partner["nom"], 30))
	v.add_child(UiTheme.label(("Vous vivez ensemble. " if together else "") + "%s aime %s." % [partner["nom"], partner["aime"]], 19, UiTheme.COL_TEXT.lightened(0.15)))
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	v.add_child(bar_row)
	bar_row.add_child(UiTheme.icon("coeur", 26, COL_FAMILY))
	var bar := UiTheme.bar(COL_FAMILY, 22.0, 100.0)
	bar.value = Family.complicity(_profile)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar)
	var pct := UiTheme.label("Complicité %d %%" % Family.complicity(_profile), 19)
	pct.autowrap_mode = TextServer.AUTOWRAP_OFF
	bar_row.add_child(pct)
	if not together:
		v.add_child(UiTheme.label("Clique sur le canapé pour offrir des fleurs, danser ou faire un câlin. Chaque mot réussi fait monter la complicité.", 18))
		var move := UiTheme.icon_button("maison", "Vivre ensemble", UiTheme.COL_GOOD if Family.can_move_in(_profile) else UiTheme.COL_GREY, 21)
		move.name = "VivreEnsemble"
		move.disabled = not Family.can_move_in(_profile)
		move.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		move.pressed.connect(func(): moved_in.emit())
		v.add_child(move)
		if not Family.can_move_in(_profile):
			v.add_child(UiTheme.label("À %d %% de complicité, vous pourrez vivre ensemble." % Data.FAMILY_MOVE_IN, 17, UiTheme.COL_TEXT.lightened(0.3)))
		return
	v.add_child(UiTheme.label("Clique sur le canapé pour passer du temps ensemble.", 18))
	_show_children()


func _show_children() -> void:
	var kids := Family.children(_profile)
	if not kids.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_box.add_child(row)
		for k in kids:
			row.add_child(_child_card(k))
	var choice := UiTheme.card(Color(1.0, 0.95, 0.9), 14)
	_box.add_child(choice)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	choice.add_child(line)
	line.add_child(UiTheme.badge("bebe", COL_FAMILY, 46))
	var blocker := Family.baby_blocker(_profile)
	var text := "Votre famille est au complet."
	if kids.is_empty():
		text = "Vous avez choisi de ne pas avoir d'enfant pour l'instant. Vous pouvez changer d'avis quand vous voulez." \
			if Family.declined(_profile) else "Avoir un enfant ou non, c'est votre choix. Les deux sont possibles."
	elif kids.size() < Data.FAMILY_MAX_CHILDREN:
		text = "Vous pouvez accueillir un autre bébé, si vous le souhaitez."
	if blocker != "" and kids.size() < Data.FAMILY_MAX_CHILDREN:
		text += " " + blocker
	var label := UiTheme.label(text.strip_edges(), 19)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	if kids.size() >= Data.FAMILY_MAX_CHILDREN:
		return
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	line.add_child(buttons)
	var baby := UiTheme.icon_button("bebe", "Avoir un bébé" if kids.is_empty() else "Un autre bébé", COL_FAMILY if blocker == "" else UiTheme.COL_GREY, 20)
	baby.name = "AvoirBebe"
	baby.disabled = blocker != ""
	baby.pressed.connect(_show_names)
	buttons.add_child(baby)
	if kids.is_empty() and not Family.declined(_profile):
		var no := UiTheme.button("Pas d'enfant", UiTheme.COL_GREY, 20)
		no.name = "PasDEnfant"
		no.pressed.connect(func(): declined.emit())
		buttons.add_child(no)


func _child_card(k: Dictionary) -> Control:
	var card := UiTheme.card(UiTheme.COL_SOFT, 10)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	if k["age"] == "enfant":
		var portrait := Portrait.new()
		portrait.setup(k["apparence"], "enfant", Vector2(110, 110))
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(portrait)
	else:
		row.add_child(UiTheme.badge("bebe", COL_FAMILY, 72))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var lines := [[k["nom"], 24, UiTheme.COL_TEXT]]
	if k["age"] == "bebe":
		lines.append(["Bébé · encore %d soin(s) pour grandir" % maxi(Data.FAMILY_BABY_CARES - int(k["soins"]), 1), 17, UiTheme.COL_TEXT.lightened(0.2)])
		lines.append(["Au berceau : bercer, biberon", 16, UiTheme.COL_TEXT.lightened(0.3)])
	else:
		lines.append(["Enfant · joue dans sa chambre", 17, UiTheme.COL_TEXT.lightened(0.2)])
		lines.append(["Jouets et petit lit : jouer, histoire", 16, UiTheme.COL_TEXT.lightened(0.3)])
	for line in lines:
		var l := UiTheme.label(line[0], line[1], line[2])
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(l)
	return card


# --- Le prénom du bébé ------------------------------------------------------------------

func _show_names() -> void:
	_clear()
	var names := Family.baby_names()
	_head("Un bébé arrive !", "bebe", func():
		return "Comment s'appelle le bébé ? " + ", ".join(names.map(func(c): return c["nom"])) + ".")
	_box.add_child(UiTheme.label("Comment s'appelle le bébé ? Choisis son prénom.", 21))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	for i in names.size():
		var c: Dictionary = names[i]
		var b := UiTheme.icon_button("bebe", "%s (%s)" % [c["nom"], "fille" if c["genre"] == 0 else "garçon"], COL_FAMILY, 22)
		b.name = "Prenom_%d" % i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(func(): baby_chosen.emit(c))
		row.add_child(b)
	var back := UiTheme.button("Retour", UiTheme.COL_GREY, 20)
	back.name = "Retour"
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(refresh)
	_box.add_child(back)


func _spoken() -> String:
	var parts := [Family.summary(_profile).trim_prefix("Famille : ") + "."]
	parts.append(Family.advice(_profile))
	return " ".join(parts)
