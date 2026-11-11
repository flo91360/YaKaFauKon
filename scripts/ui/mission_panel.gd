extends Control
## Panneau de mission : consigne à lire, choix à faire, puis liste à taper.
## L'état de la mission est gardé dans `state` (le jeu peut la mettre de côté
## et la reprendre plus tard). La frappe elle-même est faite par l'écran de jeu.

signal closed # mission mise de côté (on pourra la reprendre)
signal abandoned
signal typing_requested(text: String, title: String)
signal completed

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")

## state = {"data": mission, "step": "intro"|"question"|"items", "q": int, "item": int}
var state: Dictionary = {}
var _box: VBoxContainer
var _feedback: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = UiTheme.centered_panel(self, 860)
	refresh()


func _game():
	return get_node("/root/Game")


func refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var m: Dictionary = state["data"]
	var header := HBoxContainer.new()
	_box.add_child(header)
	var title := UiTheme.label("Mission : " + m["title"], 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var later := UiTheme.button("Plus tard", Color(0.6, 0.62, 0.68), 20)
	later.tooltip_text = "Mettre la mission de côté pour s'occuper du personnage"
	later.pressed.connect(func(): closed.emit())
	header.add_child(later)
	match state["step"]:
		"intro":
			_show_intro(m)
		"question":
			_show_question(m)
		"items":
			_show_items(m)


func _consigne_box(m: Dictionary, size: int) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.82)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	_box.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	var text := UiTheme.label(m["consigne"], size)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	row.add_child(UiTheme.speak_button(func(): return m["consigne"]))


func _show_intro(m: Dictionary) -> void:
	_box.add_child(UiTheme.label("Lis bien la consigne :", 22, UiTheme.COL_TEXT.lightened(0.25)))
	_consigne_box(m, 28)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(buttons)
	var give_up := UiTheme.button("Abandonner", Color(0.75, 0.5, 0.5), 20)
	give_up.pressed.connect(func(): abandoned.emit())
	buttons.add_child(give_up)
	var go := UiTheme.button("J'ai compris, on y va !", UiTheme.COL_GOOD)
	go.pressed.connect(func():
		state["step"] = "question"
		state["q"] = 0
		refresh())
	buttons.add_child(go)


func _show_question(m: Dictionary) -> void:
	var q: Dictionary = m["questions"][state["q"]]
	_consigne_box(m, 22)
	var row := HBoxContainer.new()
	_box.add_child(row)
	var question := UiTheme.label(q["q"], 28)
	question.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(question)
	row.add_child(UiTheme.speak_button(func(): return q["q"] + " " + ". ".join(q["choices"])))
	var first_try := [true]
	for i in q["choices"].size():
		var b := UiTheme.button(q["choices"][i], UiTheme.COL_ACCENT, 24)
		b.pressed.connect(func(): _answer(q, i, b, first_try))
		_box.add_child(b)
	_feedback = UiTheme.label("", 22)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_feedback)


func _answer(q: Dictionary, index: int, button: Button, first_try: Array) -> void:
	var session: Dictionary = _game().session
	if index == q["good"]:
		session["choix_total"] += 1
		if first_try[0]:
			session["choix_justes_du_premier_coup"] += 1
		_feedback.text = "Bien joué !"
		_feedback.add_theme_color_override("font_color", UiTheme.COL_GOOD.darkened(0.2))
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
		state["q"] += 1
		if state["q"] >= state["data"]["questions"].size():
			state["step"] = "items"
			state["item"] = 0
		refresh()
	else:
		first_try[0] = false
		button.disabled = true
		_feedback.text = "Pas tout à fait. " + q["aide"]
		_feedback.add_theme_color_override("font_color", UiTheme.COL_BAD)


func _show_items(m: Dictionary) -> void:
	var profile: Dictionary = _game().profile
	_box.add_child(UiTheme.label("Maintenant, tape la liste. Tu as fait de bons choix !", 24))
	var lines := []
	for i in m["items"].size():
		var text := Progression.text_for(m["items"][i], profile)
		lines.append(text)
		var done: bool = i < state["item"]
		var l := UiTheme.label(("✔  " if done else "•  ") + text, 28, UiTheme.COL_GOOD.darkened(0.2) if done else UiTheme.COL_TEXT)
		_box.add_child(l)
	_box.add_child(UiTheme.speak_button(func(): return "La liste : " + ", ".join(lines)))
	if state["item"] >= m["items"].size():
		completed.emit()
		return
	var go := UiTheme.button("Taper : « %s »" % lines[state["item"]], UiTheme.COL_GOOD)
	go.pressed.connect(func():
		visible = false
		typing_requested.emit(lines[state["item"]], "Mission « %s » (%d / %d), recopie :" % [m["title"], state["item"] + 1, m["items"].size()]))
	_box.add_child(go)


## Appelé par l'écran de jeu après la frappe d'un élément de la liste.
func item_typed(ok: bool) -> void:
	visible = true
	if ok:
		state["item"] += 1
	refresh()
