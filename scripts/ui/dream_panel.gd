extends Control
## Panneau « Mon rêve » (l'objectif de vie) : choisir son rêve parmi les cartes,
## puis voir les étapes pour y arriver. Fête aussi le rêve réalisé.

signal chosen(dream: String)
signal closed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Dreams = preload("res://scripts/core/dreams.gd")

## Premier choix, en début de partie : le titre accueille l'enfant.
var first := false
## Récompense {pieces, etoiles, label} si le rêve vient d'être réalisé.
var reward: Dictionary = {}

var _box: VBoxContainer
var _profile: Dictionary


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	_box = UiTheme.centered_panel(self, 1180)
	_box.add_theme_constant_override("separation", 12)
	_profile = get_node("/root/Game").profile
	if Dreams.has_current(_profile) and not first:
		_show_status()
	else:
		_show_choice()


func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()


# --- Choisir son rêve ---------------------------------------------------------------

func _show_choice() -> void:
	_clear()
	var current := Dreams.current(_profile)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_box.add_child(head)
	head.add_child(UiTheme.badge("reve", UiTheme.COL_DREAM, 46))
	var title_text := "Quel est ton grand rêve ?" if current == "" else "Choisis un nouveau rêve"
	var title := UiTheme.label(title_text, 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.speak_button(func():
		var parts := [title_text]
		for d in Data.DREAM_ORDER:
			parts.append(Data.DREAMS[d]["label"] + ".")
		return " ".join(parts)))
	var later := UiTheme.button("Plus tard" if current == "" else "Retour", UiTheme.COL_GREY, 20)
	later.name = "PlusTard"
	later.pressed.connect(func():
		if current == "":
			closed.emit()
		else:
			_show_status())
	head.add_child(later)
	var intro := "Ton rêve guide toute ta partie. Tu avances étape par étape, et tu pourras en changer."
	_box.add_child(UiTheme.label(intro, 19, UiTheme.COL_TEXT.lightened(0.2)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_box.add_child(grid)
	for d in Data.DREAM_ORDER:
		grid.add_child(_dream_card(d, d == current))


func _dream_card(dream: String, is_current: bool) -> Control:
	var info: Dictionary = Data.DREAMS[dream]
	var color: Color = UiTheme.CAREER_COLORS.get(dream, UiTheme.COL_DREAM)
	var done: bool = dream in Dreams.achieved(_profile)
	var card := UiTheme.card(Color(1.0, 0.96, 0.82) if is_current else UiTheme.COL_SOFT, 14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(272, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(UiTheme.badge("coupe" if done else Data.dream_icon(dream), UiTheme.COL_GOLD if done else color, 56))
	var label := UiTheme.label(info["label"], 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 54)
	v.add_child(label)
	var text: String = "Rêve déjà réalisé. Bravo !" if done else info["description"]
	var description := UiTheme.label(text, 16, UiTheme.COL_TEXT.lightened(0.25))
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.custom_minimum_size = Vector2(0, 46)
	v.add_child(description)
	var pick := UiTheme.icon_button("coche", "C'est mon rêve" if is_current else "Je choisis", color, 19)
	pick.name = "Reve_" + dream
	pick.disabled = is_current
	pick.pressed.connect(func(): chosen.emit(dream))
	v.add_child(pick)
	return card


# --- Suivre son rêve ----------------------------------------------------------------

func _show_status() -> void:
	_clear()
	var dream := Dreams.current(_profile)
	var info: Dictionary = Data.DREAMS[dream]
	var color: Color = UiTheme.CAREER_COLORS.get(dream, UiTheme.COL_DREAM)
	var done := Dreams.is_done(_profile)
	UiTheme.header(_box, "Mon rêve", func(): closed.emit(), "reve", UiTheme.COL_DREAM)

	if done:
		var win := UiTheme.card(Color(1.0, 0.95, 0.78), 18)
		_box.add_child(win)
		var win_row := HBoxContainer.new()
		win_row.add_theme_constant_override("separation", 12)
		win.add_child(win_row)
		win_row.add_child(UiTheme.badge("coupe", UiTheme.COL_GOLD, 60))
		var win_text := "Rêve réalisé : %s. Bravo, tu as tenu jusqu'au bout !" % info["label"]
		if not reward.is_empty():
			win_text += "\nTu gagnes %d pièces et %d étoiles." % [reward["pieces"], reward["etoiles"]]
		var win_label := UiTheme.label(win_text, 23)
		win_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		win_row.add_child(win_label)
		win_row.add_child(UiTheme.speak_button(func(): return win_text))
	else:
		var card := UiTheme.card(UiTheme.COL_SOFT, 16)
		_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		row.add_child(UiTheme.badge(Data.dream_icon(dream), color, 60))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(UiTheme.label(info["label"], 27))
		v.add_child(UiTheme.label(info["description"], 19, UiTheme.COL_TEXT.lightened(0.2)))
		var all := Dreams.steps(_profile)
		var n := Dreams.steps_done(_profile)
		var bar_row := HBoxContainer.new()
		bar_row.add_theme_constant_override("separation", 10)
		v.add_child(bar_row)
		var bar := UiTheme.bar(UiTheme.COL_DREAM, 18.0, all.size())
		bar.value = n
		bar_row.add_child(bar)
		var count := UiTheme.label("%d étape%s sur %d" % [n, "" if n <= 1 else "s", all.size()], 18)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		bar_row.add_child(count)

	# Les étapes, l'une sous l'autre : faites, en cours, à venir.
	var steps_card := UiTheme.card(Color(1, 1, 1), 16)
	_box.add_child(steps_card)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	steps_card.add_child(list)
	var next_found := false
	var spoken := []
	for s in Dreams.steps(_profile):
		var is_next: bool = not s["done"] and not next_found
		if is_next:
			next_found = true
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		list.add_child(line)
		if s["done"]:
			line.add_child(UiTheme.badge("coche", UiTheme.COL_GOOD, 32))
		elif is_next:
			line.add_child(UiTheme.badge("fleche", UiTheme.COL_DREAM, 32))
		else:
			line.add_child(UiTheme.badge("cadenas", Color(0.8, 0.82, 0.86), 32))
		var step_color := UiTheme.COL_GOOD.darkened(0.25) if s["done"] else (UiTheme.COL_TEXT if is_next else UiTheme.COL_TEXT.lightened(0.4))
		var step_label := UiTheme.label(s["label"] + ("  (c'est la prochaine étape)" if is_next else ""), 21, step_color)
		step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(step_label)
		spoken.append(s["label"] + (", déjà fait." if s["done"] else "."))
	var advice := Dreams.advice(_profile)
	if advice != "":
		var tip := HBoxContainer.new()
		tip.add_theme_constant_override("separation", 10)
		_box.add_child(tip)
		tip.add_child(UiTheme.badge("bulle", UiTheme.COL_ACCENT, 34))
		var tip_label := UiTheme.label(advice, 20)
		tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tip.add_child(tip_label)
		tip.add_child(UiTheme.speak_button(func(): return "Mon rêve : %s. %s %s" % [info["label"], " ".join(spoken), advice]))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	_box.add_child(buttons)
	var change := UiTheme.icon_button("reve", "Choisir un nouveau rêve" if done else "Changer de rêve",
		UiTheme.COL_DREAM if done else UiTheme.COL_GREY, 20)
	change.name = "ChangerReve"
	change.pressed.connect(_show_choice)
	buttons.add_child(change)
