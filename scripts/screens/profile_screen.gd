extends Control
## Écran d'accueil : « Qui joue ? » — un bouton par enfant, création d'un nouveau joueur,
## et accès discret à l'espace ergothérapeute (protégé par un mot choisi par l'ergo).

signal profile_selected(data: Dictionary)
signal new_profile_requested
signal ergo_requested

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const ErgoAccess = preload("res://scripts/core/ergo_access.gd")

var profiles: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, Color(0.72, 0.85, 0.98))
	gradient.gradient.set_color(1, Color(0.99, 0.92, 0.82))
	gradient.fill_to = Vector2(0, 1)
	bg.texture = gradient
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := UiTheme.centered_panel(self, 760)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(110, 110)
	box.add_child(logo)
	var title := UiTheme.label("YaKaFauKon", 52, UiTheme.COL_ACCENT.darkened(0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.label("Qui joue aujourd'hui ?", 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var scroll := ScrollContainer.new() # beaucoup d'enfants : la liste défile
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, mini(ceili(profiles.size() / 2.0), 4) * 84)
	box.add_child(scroll)
	scroll.add_child(grid)
	var hide_names := bool(_game().local_settings.get("prenoms_caches", false))
	for p in profiles:
		var stars := int(p.get("etoiles", 0))
		var b := UiTheme.icon_button("perso", ErgoAccess.display_name(str(p.get("name", "?")), hide_names) + ("  ·  %d étoile%s" % [stars, "" if stars == 1 else "s"] if stars > 0 else ""), Data.OUTFIT_COLORS[clampi(int(p.get("appearance", {}).get("outfit", 0)), 0, Data.OUTFIT_COLORS.size() - 1)].darkened(0.1), 30)
		b.custom_minimum_size = Vector2(340, 70)
		b.pressed.connect(func(): profile_selected.emit(p))
		grid.add_child(b)
	if profiles.is_empty():
		var hint := UiTheme.label("Pas encore de joueur. Crée le tien !", 24)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hint)

	var new_button := UiTheme.button("+ Nouveau joueur", UiTheme.COL_GOOD, 28)
	new_button.custom_minimum_size = Vector2(0, 64)
	new_button.pressed.connect(func(): new_profile_requested.emit())
	box.add_child(new_button)

	var quit := UiTheme.icon_button("croix", "Quitter", UiTheme.COL_GREY, 18)
	quit.anchor_top = 1.0
	quit.anchor_bottom = 1.0
	quit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	quit.offset_left = 16
	quit.offset_top = -16
	quit.offset_bottom = -16
	quit.focus_mode = Control.FOCUS_NONE
	quit.pressed.connect(func(): get_tree().quit())
	add_child(quit)

	# Espace ergothérapeute : petit bouton en bas à droite + mot à taper.
	var ergo := UiTheme.button("Espace ergothérapeute", Color(0.6, 0.62, 0.68), 18)
	ergo.anchor_left = 1.0
	ergo.anchor_right = 1.0
	ergo.anchor_top = 1.0
	ergo.anchor_bottom = 1.0
	ergo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ergo.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ergo.offset_left = -16
	ergo.offset_right = -16
	ergo.offset_top = -16
	ergo.offset_bottom = -16
	ergo.focus_mode = Control.FOCUS_NONE
	ergo.pressed.connect(_ask_code)
	add_child(ergo)


func _game():
	return get_node("/root/Game")


func _ask_code() -> void:
	var root := Control.new()
	root.name = "AccesErgo"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.12, 0.2, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	add_child(root)
	var box := UiTheme.centered_panel(root, 520)
	box.add_child(UiTheme.label("Espace réservé à l'ergothérapeute.\nTape le mot d'accès :", 24))
	var edit := LineEdit.new()
	edit.name = "Mot"
	edit.secret = true
	box.add_child(edit)
	var msg := UiTheme.label("", 20, UiTheme.COL_BAD)
	box.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var cancel := UiTheme.button("Retour", Color(0.6, 0.62, 0.68))
	cancel.pressed.connect(root.queue_free)
	row.add_child(cancel)
	var ok := UiTheme.button("Entrer")
	ok.name = "Entrer"
	row.add_child(ok)
	var try_code := func():
		if not _game().check_ergo_word(edit.text):
			msg.text = "Mot d'accès incorrect."
			edit.clear()
		elif not ErgoAccess.is_set(_game().ergo_access()):
			root.queue_free()
			_choose_word()
		else:
			root.queue_free()
			ergo_requested.emit()
	ok.pressed.connect(try_code)
	edit.text_submitted.connect(func(_t): try_code.call())
	edit.grab_focus()


## Premier passage avec le mot de départ « ergo » : l'ergo choisit son propre mot,
## que les enfants ne connaissent pas.
func _choose_word() -> void:
	var root := Control.new()
	root.name = "ChoixMot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.12, 0.2, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	add_child(root)
	var box := UiTheme.centered_panel(root, 600)
	box.add_child(UiTheme.label("Choisis ton propre mot d'accès (au moins %d caractères).\nLe mot « ergo » ne marchera plus ensuite." % ErgoAccess.MIN_LENGTH, 22))
	var edit := LineEdit.new()
	edit.name = "Nouveau"
	edit.secret = true
	edit.placeholder_text = "Nouveau mot"
	box.add_child(edit)
	var confirm := LineEdit.new()
	confirm.name = "Confirmation"
	confirm.secret = true
	confirm.placeholder_text = "Le même mot, encore une fois"
	box.add_child(confirm)
	var msg := UiTheme.label("", 20, UiTheme.COL_BAD)
	msg.name = "Message"
	box.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var cancel := UiTheme.button("Retour", Color(0.6, 0.62, 0.68))
	cancel.pressed.connect(root.queue_free)
	row.add_child(cancel)
	var ok := UiTheme.button("Enregistrer")
	ok.name = "Enregistrer"
	row.add_child(ok)
	var save := func():
		var why := ErgoAccess.refusal(edit.text, confirm.text)
		if why != "":
			msg.text = why
			return
		if not _game().set_ergo_word(edit.text):
			msg.text = "Le mot n'a pas pu être enregistré sur ce PC."
			return
		root.queue_free()
		ergo_requested.emit()
	ok.pressed.connect(save)
	edit.text_submitted.connect(func(_t): confirm.grab_focus())
	confirm.text_submitted.connect(func(_t): save.call())
	edit.grab_focus()
