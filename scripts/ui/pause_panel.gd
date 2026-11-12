extends Control
## Menu de pause : reprendre, réglages (son, musique, graphismes), revoir le
## tutoriel, changer de joueur, quitter.

signal resume
signal replay_tutorial
signal change_player
signal quit_game

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _box: VBoxContainer
var _quality_buttons: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(self)
	_box = UiTheme.centered_panel(self, 560)
	var game = get_node("/root/Game")
	var title := UiTheme.label("Pause", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	var b_resume := UiTheme.icon_button("fleche", "Reprendre", UiTheme.COL_GOOD, 24)
	b_resume.pressed.connect(func(): resume.emit())
	_box.add_child(b_resume)

	var settings := UiTheme.card(UiTheme.COL_SOFT, 16)
	_box.add_child(settings)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	settings.add_child(grid)
	_slider(grid, "son", "Sons", "volume")
	_slider(grid, "son", "Musique", "musique")
	grid.add_child(_caption("reglages", "Graphismes"))
	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 6)
	grid.add_child(q_row)
	for i in game.QUALITY_LABELS.size():
		var b := UiTheme.button(game.QUALITY_LABELS[i], UiTheme.COL_ACCENT, 18)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			game.set_local_setting("qualite", i)
			_refresh_quality())
		q_row.add_child(b)
		_quality_buttons.append(b)
	_refresh_quality()
	grid.add_child(_caption("perso", "Affichage"))
	var full := UiTheme.button("", UiTheme.COL_ACCENT, 18)
	full.focus_mode = Control.FOCUS_NONE
	full.text = "Plein écran : oui" if game.local_settings["plein_ecran"] else "Plein écran : non"
	full.pressed.connect(func():
		game.set_local_setting("plein_ecran", not game.local_settings["plein_ecran"])
		full.text = "Plein écran : oui" if game.local_settings["plein_ecran"] else "Plein écran : non")
	grid.add_child(full)
	var hint := UiTheme.label("Si le jeu saccade, choisis « Léger ».", 16, UiTheme.COL_TEXT.lightened(0.3))
	_box.add_child(hint)

	var b_tuto := UiTheme.icon_button("bulle", "Revoir le tutoriel", UiTheme.COL_TEAL, 20)
	b_tuto.pressed.connect(func(): replay_tutorial.emit())
	_box.add_child(b_tuto)
	var row := HBoxContainer.new()
	_box.add_child(row)
	var b_change := UiTheme.icon_button("perso", "Changer de joueur", UiTheme.COL_GREY, 20)
	b_change.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_change.pressed.connect(func(): change_player.emit())
	row.add_child(b_change)
	var b_quit := UiTheme.icon_button("croix", "Quitter le jeu", UiTheme.COL_GREY, 20)
	b_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_quit.pressed.connect(func(): quit_game.emit())
	row.add_child(b_quit)


func _caption(icon_name: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(UiTheme.badge(icon_name, UiTheme.COL_ACCENT, 30))
	var l := UiTheme.label(text, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	return row


func _slider(grid: GridContainer, icon_name: String, text: String, key: String) -> void:
	var game = get_node("/root/Game")
	grid.add_child(_caption(icon_name, text))
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = game.local_settings[key]
	slider.custom_minimum_size = Vector2(280, 30)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v):
		game.set_local_setting(key, int(v))
		if key == "volume":
			game.play_sound("ok"))
	grid.add_child(slider)


func _refresh_quality() -> void:
	var game = get_node("/root/Game")
	for i in _quality_buttons.size():
		_quality_buttons[i].modulate = Color(1, 1, 1) if i == game.local_settings["qualite"] else Color(1, 1, 1, 0.45)
