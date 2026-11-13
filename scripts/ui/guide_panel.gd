extends Control
## Guide : comment jouer, et tout ce qu'on peut faire avec chaque objet du studio.

signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Hud = preload("res://scripts/ui/hud.gd")

## Objets du studio : [{name, actions}] (donnés par l'écran de jeu).
var objects: Array = []

const HOW := [
	["souris", "Clique sur le sol pour te déplacer."],
	["souris", "Clique sur un objet pour choisir une action."],
	["clavier", "Recopie le mot affiché, puis appuie sur la touche Entrée."],
	["etoile", "Dans une activité, chaque mot réussi fait monter ta compétence."],
	["cible", "Choisis un objectif pour gagner des pièces et des étoiles."],
	["travail", "Choisis un métier : les missions de travail rapportent des pièces."],
	["magasin", "Au magasin, tes pièces achètent de nouveaux objets pour ta maison."],
	["pause", "La touche Échap met le jeu en pause."],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	var box := UiTheme.centered_panel(self, 1120)
	UiTheme.header(box, "Le guide du studio", func(): closed.emit(), "livre", UiTheme.COL_TEAL)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	# Comment jouer
	var how_row := HBoxContainer.new()
	content.add_child(how_row)
	var how_title := UiTheme.label("Comment jouer", 24)
	how_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	how_row.add_child(how_title)
	how_row.add_child(UiTheme.speak_button(func():
		var lines := []
		for h in HOW:
			lines.append(h[1])
		return " ".join(lines)))
	var how := GridContainer.new()
	how.columns = 2
	how.add_theme_constant_override("h_separation", 12)
	how.add_theme_constant_override("v_separation", 8)
	content.add_child(how)
	for h in HOW:
		var card := UiTheme.card(Color(0.93, 0.96, 0.94), 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		card.add_child(row)
		row.add_child(UiTheme.badge(h[0], UiTheme.COL_TEAL, 34))
		var l := UiTheme.label(h[1], 19)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		how.add_child(card)

	# Les objets et leurs actions
	content.add_child(UiTheme.label("Les objets du studio", 24))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)
	for o in objects:
		grid.add_child(_object_card(o))


func _object_card(o: Dictionary) -> Control:
	var card := UiTheme.card(UiTheme.COL_SOFT, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiTheme.label(o["name"], 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var spoken := [str(o["name"]) + "."]
	for a in o["actions"]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		v.add_child(line)
		var text := ""
		if a == "travail":
			text = "Mon travail : choisir un métier, voir ses missions"
			line.add_child(UiTheme.badge("travail", UiTheme.COL_ORANGE, 26))
		elif a == "look":
			text = "Changer de look : coiffure, visage, tenue"
			line.add_child(UiTheme.badge("perso", UiTheme.COL_ACCENT, 26))
		else:
			var action: Dictionary = Data.ACTIONS[a]
			text = action["label"]
			for n in action["needs"]:
				if action["needs"][n] > 0.0:
					line.add_child(UiTheme.badge(n, Hud.NEED_COLORS[n], 26))
			for s in action["skills"]:
				line.add_child(UiTheme.badge(s, UiTheme.SKILL_COLORS[s], 26))
			var effects := []
			for n in action["needs"]:
				if action["needs"][n] > 0.0:
					effects.append("remonte « %s »" % Data.NEEDS[n]["label"].to_lower())
			for s in action["skills"]:
				effects.append("entraîne « %s »" % Data.SKILLS[s]["label"].to_lower())
			var minus := []
			for n in action["needs"]:
				if action["needs"][n] < 0.0:
					minus.append(Data.NEEDS[n]["label"].to_lower())
			if not effects.is_empty():
				text += " : " + ", ".join(effects)
			if not minus.is_empty():
				text += " (fait baisser : %s)" % ", ".join(minus)
			if Data.is_series(a):
				text += ". Série de %d mots." % Data.WORDS_PER_SERIES
		spoken.append(text + ".")
		var l := UiTheme.label(text, 17)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
	head.add_child(UiTheme.speak_button(func(): return " ".join(spoken)))
	return card
