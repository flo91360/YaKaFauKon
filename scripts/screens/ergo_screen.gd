extends Control
## Espace ergothérapeute : réglages de difficulté par enfant et récapitulatif
## (par séance datée et sur la durée). Tout reste sur ce PC.

signal back

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Recap = preload("res://scripts/core/recap.gd")
const ErgoAccess = preload("res://scripts/core/ergo_access.gd")

const PC := -2 # _selected quand la page « Ce PC » est ouverte

var profiles: Array = []
var save_enabled := true # désactivé pour la démonstration
var _list: VBoxContainer
var _content: VBoxContainer
var _selected := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.93, 0.95, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := UiTheme.label("Espace ergothérapeute", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back_button := UiTheme.button("Retour aux joueurs", Color(0.6, 0.62, 0.68), 20)
	back_button.pressed.connect(func(): back.emit())
	header.add_child(back_button)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	columns.add_child(left)
	_list = VBoxContainer.new()
	left.add_child(_list)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_build_list()
	if not profiles.is_empty():
		_select(0, "recap")
	else:
		_content.add_child(UiTheme.label("Aucun joueur pour l'instant.", 22))


func _build_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(UiTheme.label("Joueurs", 24))
	for i in profiles.size():
		var b := UiTheme.button(str(profiles[i]["name"]), UiTheme.COL_ACCENT.darkened(0.2) if i == _selected else UiTheme.COL_ACCENT, 20)
		b.pressed.connect(func(): _select(i, "recap"))
		_list.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_child(spacer)
	var pc := UiTheme.button("Ce PC : mot d'accès, prénoms", Color(0.5, 0.52, 0.6).darkened(0.2) if _selected == PC else Color(0.5, 0.52, 0.6), 18)
	pc.name = "CePC"
	pc.pressed.connect(_show_pc)
	_list.add_child(pc)


func _select(index: int, tab: String) -> void:
	_selected = index
	_build_list()
	for c in _content.get_children():
		c.queue_free()
	var p: Dictionary = profiles[index]
	var tabs := HBoxContainer.new()
	_content.add_child(tabs)
	var name_label := UiTheme.label(str(p["name"]), 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(name_label)
	var b_recap := UiTheme.button("Récapitulatif", UiTheme.COL_ACCENT.darkened(0.2) if tab == "recap" else Color(0.6, 0.62, 0.68), 20)
	b_recap.pressed.connect(func(): _select(index, "recap"))
	tabs.add_child(b_recap)
	var b_settings := UiTheme.button("Réglages", UiTheme.COL_ACCENT.darkened(0.2) if tab == "settings" else Color(0.6, 0.62, 0.68), 20)
	b_settings.pressed.connect(func(): _select(index, "settings"))
	tabs.add_child(b_settings)
	if tab == "recap":
		_show_recap(p)
	else:
		_show_settings(p)


## Réglages communs à tous les joueurs de ce PC.
func _show_pc() -> void:
	_selected = PC
	_build_list()
	for c in _content.get_children():
		c.queue_free()
	var game = get_node("/root/Game")
	_content.add_child(UiTheme.label("Ce PC", 30))
	_section("Écran « Qui joue ? »")
	var hide := CheckButton.new()
	hide.name = "CacherPrenoms"
	hide.text = "Cacher les prénoms (seulement l'initiale et la couleur du joueur)"
	hide.add_theme_font_size_override("font_size", 20)
	hide.button_pressed = bool(game.local_settings.get("prenoms_caches", false))
	hide.toggled.connect(func(on):
		if save_enabled:
			game.set_local_setting("prenoms_caches", on))
	_content.add_child(hide)
	_line("Chaque enfant ne voit plus les prénoms des autres. Deux joueurs de même initiale se distinguent par leur couleur.", 18)

	_section("Mot d'accès à cet espace")
	var edit := LineEdit.new()
	edit.name = "NouveauMot"
	edit.secret = true
	edit.placeholder_text = "Nouveau mot (au moins %d caractères)" % ErgoAccess.MIN_LENGTH
	_content.add_child(edit)
	var confirm := LineEdit.new()
	confirm.name = "ConfirmationMot"
	confirm.secret = true
	confirm.placeholder_text = "Le même mot, encore une fois"
	_content.add_child(confirm)
	var msg := UiTheme.label("", 20)
	msg.name = "MessageMot"
	var change := UiTheme.button("Changer le mot d'accès", UiTheme.COL_ACCENT, 20)
	change.name = "ChangerMot"
	change.pressed.connect(func():
		var why := ErgoAccess.refusal(edit.text, confirm.text)
		if why == "" and save_enabled and not game.set_ergo_word(edit.text):
			why = "Le mot n'a pas pu être enregistré sur ce PC."
		msg.text = why if why != "" else "Nouveau mot enregistré."
		msg.add_theme_color_override("font_color", UiTheme.COL_BAD if why != "" else UiTheme.COL_GOOD.darkened(0.2))
		if why == "":
			edit.clear()
			confirm.clear())
	_content.add_child(change)
	_content.add_child(msg)
	_line("Mot oublié : fermer le jeu et supprimer le fichier acces_ergo.json du dossier %s. Le mot « ergo » ouvre alors l'espace une fois, puis le jeu demande un nouveau mot." % ProjectSettings.globalize_path("user://"), 18)


func _section(text: String) -> void:
	var l := UiTheme.label(text, 24, UiTheme.COL_ACCENT.darkened(0.3))
	_content.add_child(l)


func _line(text: String, size := 20) -> void:
	_content.add_child(UiTheme.label(text, size))


func _show_recap(p: Dictionary) -> void:
	var o := Recap.overview(p)
	_section("En résumé")
	var kw := Recap.keywords(p)
	_line(" · ".join(kw) if not kw.is_empty() else "Pas encore assez de données.", 22)

	_section("Sur la durée")
	_line("Séances : %d — temps de jeu total : %s" % [o["seances"], Recap.format_duration(o["duree"])])
	var speeds: Array = o["vitesses"]
	if not speeds.is_empty():
		var parts := []
		for v in speeds:
			parts.append(str(roundi(v)))
		_line("Vitesse (caractères/min) séance après séance : " + " → ".join(parts))
	var tasks: int = o["finies"] + o["abandons"]
	if tasks > 0:
		_line("Persévérance : %d tâches terminées, %d abandonnées (%d %%)" % [o["finies"], o["abandons"], roundi(100.0 * o["finies"] / tasks)])
	if o["duree"] > 0.0:
		_line("Gestion de vie : au moins une jauge dans le rouge pendant %d %% du temps" % roundi(100.0 * o["rouge"] / o["duree"]))
		var reds := []
		for n in Data.NEED_ORDER:
			var sec: float = o["rouge_par_besoin"].get(n, 0.0)
			if sec > 0.0:
				reds.append("%s %s" % [Data.NEEDS[n]["label"].to_lower(), Recap.format_duration(sec)])
		if not reds.is_empty():
			_line("Temps dans le rouge par besoin : " + ", ".join(reds))
	if o["choix"] > 0:
		_line("Compréhension des consignes : %d choix justes du premier coup sur %d" % [o["choix_ok"], o["choix"]])
	_line("Missions réussies : %d" % o["missions"])
	var series: int = o["series_finies"] + o["series_interrompues"]
	if series > 0 or o["mots"] > 0:
		_line("Champs lexicaux : %d mots réussis — séries de 5 mots : %d terminées, %d arrêtées avant la fin" % [o["mots"], o["series_finies"], o["series_interrompues"]])
	if o["objectifs_choisis"] > 0:
		_line("Objectifs : %d choisis, %d atteints, %d changés en cours de route" % [o["objectifs_choisis"], o["objectifs_finis"], o["objectifs_abandonnes"]])
	_line("Compétences : " + " ; ".join(Recap.skills_progress(p)))
	var bought := []
	for id in Data.purchases(p):
		if Data.SHOP.has(id):
			bought.append(Data.SHOP[id]["label"].to_lower())
	_line("Maison : " + (", ".join(bought) if not bought.is_empty() else "aucun achat au magasin pour l'instant"))
	_line(Recap.garden_line(p))
	_line(Recap.family_line(p))
	_line(Recap.dream_line(p))
	var career: String = p["career"]["current"]
	if career != "":
		_line("Travail : %s, palier %d sur 5 — argent : %d pièces" % [Data.career(career, p)["label"], Progression.current_tier(p), int(p["money"])])
	var t: Dictionary = p["typing"]
	_line("Niveau des textes : %d — vitesse de départ mesurée : %s" % [Progression.text_level(p),
		("%d caractères/min" % roundi(t["baseline_cps"] * 60.0)) if t["baseline_cps"] > 0.0 else "pas encore mesurée"])

	_section("Par séance")
	var sessions: Array = p.get("sessions", [])
	if sessions.is_empty():
		_line("Aucune séance enregistrée.")
	for i in range(sessions.size() - 1, -1, -1):
		var s: Dictionary = sessions[i]
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = UiTheme.COL_SOFT
		style.set_corner_radius_all(14)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)
		_content.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		card.add_child(v)
		v.add_child(UiTheme.label("Séance du " + _format_date(str(s.get("date", ""))), 22))
		for line in Recap.session_lines(s):
			v.add_child(UiTheme.label(line, 18))


func _format_date(iso: String) -> String:
	# « 2026-11-11 14:05:33 » → « 11/11/2026 à 14:05 »
	var parts := iso.replace("T", " ").split(" ")
	if parts.size() < 2:
		return iso
	var d := parts[0].split("-")
	if d.size() < 3:
		return iso
	return "%s/%s/%s à %s" % [d[2], d[1], d[0], parts[1].substr(0, 5)]


func _show_settings(p: Dictionary) -> void:
	_section("Difficulté pour cet enfant")
	for key in Progression.SETTING_CHOICES:
		var row := HBoxContainer.new()
		_content.add_child(row)
		var l := UiTheme.label(Progression.SETTING_LABELS[key], 20)
		l.custom_minimum_size = Vector2(360, 0)
		row.add_child(l)
		var option := OptionButton.new()
		option.add_theme_font_size_override("font_size", 20)
		var choices: Array = Progression.SETTING_CHOICES[key]
		var current = Progression.setting(p, key)
		for i in choices.size():
			option.add_item(str(choices[i]))
			if str(choices[i]) == str(current):
				option.select(i)
		option.item_selected.connect(func(i):
			p["settings"][key] = choices[i]
			_save(p))
		row.add_child(option)
	_line("Chronomètre : « parfois » = une frappe sur trois, « souvent » = une sur deux. L'exigence suit la vitesse de l'enfant et se stabilise.", 18)
	_line("Tolérance : « normale » = sur un mot seul, aucune faute jusqu'à 3 lettres, 1 jusqu'à 8 lettres, 2 au-delà ; 2 sur plusieurs mots. « Stricte » en admet une de moins, « large » une de plus. Les accents et majuscules sont toujours ignorés.", 18)
	_line("Après 2 chronomètres « trop lents » de suite, le suivant demande 80 % de la vitesse habituelle (65 % après 4). Un chronomètre réussi remet l'exigence normale.", 18)

	_section("Vitesse de frappe")
	var t: Dictionary = p["typing"]
	_line("Vitesse de départ : %s" % (("%d caractères/min" % roundi(t["baseline_cps"] * 60.0)) if t["baseline_cps"] > 0.0 else "pas encore mesurée (%d frappes sur %d)" % [t["samples"].size(), Progression.CALIBRATION_COUNT]))
	var reset := UiTheme.button("Refaire la mesure de vitesse", UiTheme.COL_ACCENT, 20)
	reset.pressed.connect(func():
		Progression.reset_calibration(p)
		_save(p)
		_select(_selected, "settings"))
	_content.add_child(reset)

	_section("Profil")
	var delete := UiTheme.button("Supprimer ce joueur", UiTheme.COL_BAD, 20)
	delete.pressed.connect(func(): _confirm_delete(p))
	_content.add_child(delete)


func _confirm_delete(p: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Supprimer définitivement %s et tout son historique ?" % p["name"]
	dialog.ok_button_text = "Supprimer"
	dialog.cancel_button_text = "Annuler"
	add_child(dialog)
	dialog.confirmed.connect(func():
		if save_enabled:
			get_node("/root/Game").delete_profile(str(p["id"]))
		profiles.erase(p)
		_selected = -1
		for c in _content.get_children():
			c.queue_free()
		_build_list()
		if not profiles.is_empty():
			_select(0, "recap"))
	dialog.popup_centered()


func _save(p: Dictionary) -> void:
	if save_enabled:
		get_node("/root/Game").save_any(p)
