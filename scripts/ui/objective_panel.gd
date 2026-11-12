extends Control
## Choix d'un objectif parmi 3 cartes. Peut d'abord afficher la récompense
## de l'objectif qui vient d'être atteint.

signal chosen(offer: Dictionary)
signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")

var offers: Array = []
var reward: Dictionary = {} # {pieces, label} si un objectif vient d'être atteint
var can_close := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	var box := UiTheme.centered_panel(self, 1040)
	box.add_theme_constant_override("separation", 14)
	if not reward.is_empty():
		var win := UiTheme.card(Color(1.0, 0.95, 0.78), 18)
		box.add_child(win)
		var row := HBoxContainer.new()
		win.add_child(row)
		row.add_child(UiTheme.badge("etoile", UiTheme.COL_GOLD, 52))
		var text := UiTheme.label("Objectif atteint : %s\nTu gagnes %d pièces et 1 étoile. Bravo !" % [reward["label"], reward["pieces"]], 22)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(UiTheme.badge("cible", UiTheme.COL_CORAL, 46))
	var title := UiTheme.label("Choisis ton prochain objectif" if not reward.is_empty() else "Choisis ton objectif", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.speak_button(func():
		var parts := ["Choisis ton objectif."]
		for i in offers.size():
			parts.append("Choix %d : %s." % [i + 1, offers[i]["label"]])
		return " ".join(parts)))
	if can_close:
		var later := UiTheme.button("Plus tard", UiTheme.COL_GREY, 20)
		later.pressed.connect(func(): closed.emit())
		head.add_child(later)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	box.add_child(cards)
	for offer in offers:
		cards.add_child(_card(offer))


func _card(offer: Dictionary) -> Control:
	var icon_name: String = offer.get("icone", "cible")
	var color: Color = UiTheme.SKILL_COLORS.get(icon_name, {"etoile": UiTheme.COL_GOLD, "coeur": UiTheme.COL_CORAL,
		"travail": UiTheme.COL_ORANGE, "piece": UiTheme.COL_GOLD}.get(icon_name, UiTheme.COL_ACCENT))
	var card := UiTheme.card(UiTheme.COL_SOFT, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(310, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(UiTheme.badge(icon_name, color, 64))
	var label := UiTheme.label(offer["label"], 23)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 92)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(label)
	var help := UiTheme.label(offer.get("aide", ""), 17, UiTheme.COL_TEXT.lightened(0.25))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.custom_minimum_size = Vector2(0, 100)
	help.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(help)
	var gain := HBoxContainer.new()
	gain.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(gain)
	gain.add_child(UiTheme.icon("piece", 26, UiTheme.COL_GOLD))
	var coins := UiTheme.label("+%d" % int(offer["pieces"]), 22)
	coins.autowrap_mode = TextServer.AUTOWRAP_OFF
	gain.add_child(coins)
	gain.add_child(UiTheme.icon("etoile", 26, UiTheme.COL_GOLD))
	var star := UiTheme.label("+1", 22)
	star.autowrap_mode = TextServer.AUTOWRAP_OFF
	gain.add_child(star)
	var pick := UiTheme.icon_button("coche", "Je choisis", color, 22)
	pick.pressed.connect(func(): chosen.emit(offer))
	v.add_child(pick)
	return card
