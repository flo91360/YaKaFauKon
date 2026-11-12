extends Control
## Tutoriel du premier lancement : une bulle explique les gestes un par un.
## L'écran de jeu signale ce que fait l'enfant avec `event()` ; le tutoriel
## annonce chaque étape avec `step_changed` (pour montrer la bonne flèche).

signal step_changed(step_id: String)
signal finished(skipped: bool)

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

## wait = "" : bouton « Suivant » ; sinon nom de l'événement attendu.
const STEPS := [
	{"id": "bienvenue", "wait": "", "text": "Bienvenue %s ! Voici ton studio. Je te montre comment jouer."},
	{"id": "bouger", "wait": "moved", "text": "Pour te déplacer, clique sur le sol avec la souris."},
	{"id": "jauges", "wait": "", "text": "En haut à gauche, ce sont tes besoins : faim, sommeil, toilettes, hygiène et vie sociale. Si une jauge devient rouge, occupe-toi d'elle !"},
	{"id": "objet", "wait": "typing_opened", "text": "Clique sur le lavabo. La flèche dorée te le montre."},
	{"id": "taper", "wait": "typed_ok", "text": "Recopie le mot avec le clavier, puis appuie sur la touche Entrée."},
	{"id": "action", "wait": "action_done", "text": "Bravo ! Ton personnage y va tout seul. La barre en bas à gauche montre où il en est."},
	{"id": "activite", "wait": "series_started", "text": "Maintenant, clique sur le tapis de course et recopie le mot. Les activités font monter tes compétences."},
	{"id": "serie", "wait": "series_end", "text": "Tape les mots un par un. À chaque mot réussi, ta barre de compétence monte !"},
	{"id": "boutons", "wait": "", "text": "En haut à droite : « Compétences » montre tes niveaux, « Travail » te donne un métier, « Guide » explique toutes les actions."},
	{"id": "objectif", "wait": "", "text": "Dernière chose : choisis un objectif. Il te guide et te fait gagner des pièces et des étoiles !"},
]

var child_name := ""
var step := -1

var _text: Label
var _count: Label
var _next: Button
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = 96
	var style: StyleBoxFlat = get_theme_stylebox("panel", "PanelContainer").duplicate()
	style.bg_color = Color(1.0, 0.98, 0.9)
	style.border_color = UiTheme.COL_GOLD
	style.set_border_width_all(4)
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	var badge := UiTheme.badge("bulle", UiTheme.COL_GOLD, 40)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(badge)
	_text = UiTheme.label("", 21)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_text)
	var buttons := HBoxContainer.new()
	v.add_child(buttons)
	_count = UiTheme.label("", 17, UiTheme.COL_TEXT.lightened(0.3))
	_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_count)
	var skip := UiTheme.button("Passer le tutoriel", UiTheme.COL_GREY, 16)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(func(): _finish(true))
	buttons.add_child(skip)
	buttons.add_child(UiTheme.speak_button(func(): return _text.text))
	_next = UiTheme.icon_button("fleche", "Suivant", UiTheme.COL_GOOD, 20)
	_next.focus_mode = Control.FOCUS_NONE
	_next.pressed.connect(advance)
	buttons.add_child(_next)
	if step < 0:
		_show(0)


func current_id() -> String:
	return STEPS[step]["id"] if step >= 0 and step < STEPS.size() else ""


## L'enfant vient de faire quelque chose dans le jeu.
func event(event_name: String) -> void:
	if step < 0 or step >= STEPS.size():
		return
	if STEPS[step]["wait"] == event_name:
		advance()
	elif event_name == "series_started" and current_id() in ["objet", "taper", "action"]:
		_show(7) # l'enfant est allé plus vite que le tutoriel
	elif event_name == "series_end" and current_id() == "activite":
		_show(8)


func advance() -> void:
	if step + 1 >= STEPS.size():
		_finish(false)
	else:
		_show(step + 1)


func _show(index: int) -> void:
	step = index
	var s: Dictionary = STEPS[index]
	var text: String = s["text"]
	_text.text = text % child_name if text.contains("%s") else text
	_count.text = "%d / %d" % [index + 1, STEPS.size()]
	_next.visible = s["wait"] == ""
	_next.text = "Suivant" if index + 1 < STEPS.size() else "Choisir mon objectif"
	_panel.pivot_offset = Vector2(300, 40)
	_panel.scale = Vector2(0.92, 0.92)
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	step_changed.emit(s["id"])


func _finish(skipped: bool) -> void:
	step = STEPS.size()
	visible = false
	step_changed.emit("")
	finished.emit(skipped)
