extends Node
## Écran de jeu : le studio, le personnage, le temps qui passe, les besoins,
## les actions déclenchées par la frappe, les séries de mots des activités,
## les objectifs, le tutoriel et les panneaux (compétences, travail, guide…).

signal quit_to_profiles

const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Objectives = preload("res://scripts/core/objectives.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Studio = preload("res://scripts/world/studio.gd")
const Character = preload("res://scripts/world/character.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const TypingPanel = preload("res://scripts/ui/typing_panel.gd")
const SkillsPanel = preload("res://scripts/ui/skills_panel.gd")
const CareerPanel = preload("res://scripts/ui/career_panel.gd")
const SessionEndPanel = preload("res://scripts/ui/session_end_panel.gd")
const MissionPanel = preload("res://scripts/ui/mission_panel.gd")
const ObjectivePanel = preload("res://scripts/ui/objective_panel.gd")
const GuidePanel = preload("res://scripts/ui/guide_panel.gd")
const ShopPanel = preload("res://scripts/ui/shop_panel.gd")
const DreamPanel = preload("res://scripts/ui/dream_panel.gd")
const Dreams = preload("res://scripts/core/dreams.gd")
const BuildPanel = preload("res://scripts/ui/build_panel.gd")
const Build = preload("res://scripts/core/build.gd")
const PausePanel = preload("res://scripts/ui/pause_panel.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const FamilyPanel = preload("res://scripts/ui/family_panel.gd")
const Family = preload("res://scripts/core/family.gd")

const SLEEP_TIME_FACTOR := 24.0 # pendant le sommeil, le temps passe 24 fois plus vite
const SLEEP_OTHER_NEEDS := 0.25 # les autres besoins baissent moins vite en dormant
const DREAM_PARTY_DELAY := 3.0 # secondes de calme avant de fêter le rêve réalisé
const COUPLE_SPOT := Vector3(0.4, 0, 1.3) # sur le tapis, devant le canapé : fleurs, danse

var studio
var character
var hud
var typing
var tutorial: Control = null
var ui: CanvasLayer
var paused := false

var _state := "idle" # idle / typing / walking / acting / series
var _action_id := ""
var _object = null
var _action_done_minutes := 0.0
var _last_typing_chars := 0
var _menu: Control = null
var _pause_menu: Control = null
var _overlay: Control = null # panneau compétences / travail / guide… (le jeu est en pause)
var _mission_state: Dictionary = {} # mission proposée ou en cours
var _mission_panel: Control = null
var _typing_mode := "action" # action / mission / series
var _last_mission_id := ""
var _hovered = null
var _was_red := {}
var _series: Dictionary = {} # série de mots en cours : {action, words, index, results}
var _objective_announced := false
var _dream_intro := false # le choix du rêve ouvre la partie : la suite vient après
var _dream_wait := 0.0
var _char_zone := "maison" # où est le personnage : la caméra le suit quand il change de zone
var _fps_time := 0.0
var _fps_frames := 0
var _session_warned := false # « plus qu'une minute » déjà dit
var _session_over := false # minuterie de séance arrivée au bout
var _arrival_pending := false # arrivé pendant une frappe de mission : l'activité attend la fin de la frappe


func _ready() -> void:
	var game = get_node("/root/Game")
	studio = Studio.new()
	add_child(studio)
	studio.set_purchases(Data.purchases(game.profile))
	studio.set_constructions(Data.constructions(game.profile))
	character = Character.new()
	studio.add_child(character)
	character.build(game.profile["appearance"])
	character.position = Vector3(0.4, 0, 0.8)
	character.face(Vector3(5, 0, 6))
	character.arrived.connect(_on_arrived)
	_sync_family()

	ui = CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	hud.skills_pressed.connect(_open_skills)
	hud.career_pressed.connect(_open_career)
	hud.pause_pressed.connect(_toggle_pause)
	hud.mission_pressed.connect(_open_mission)
	hud.guide_pressed.connect(_open_guide)
	hud.objective_pressed.connect(_open_objectives)
	hud.shop_pressed.connect(_open_shop)
	hud.dream_pressed.connect(_open_dream)
	hud.build_pressed.connect(_open_build)
	hud.view_pressed.connect(_toggle_view)
	hud.family_pressed.connect(_open_family)
	typing = TypingPanel.new()
	ui.add_child(typing)
	typing.validated.connect(_on_typing_validated)
	typing.finished.connect(_on_typing_finished)
	game.skill_level_up.connect(_on_skill_level_up)
	game.settings_changed.connect(_apply_settings)
	if not game.demo_mode:
		game.retry_quality()
	_apply_settings()
	game.start_music()
	for n in Data.NEED_ORDER:
		_was_red[n] = game.profile["needs"][n] < Data.RED_THRESHOLD
	_objective_announced = Objectives.is_done(game.profile)
	if not Dreams.has_current(game.profile):
		# Début de partie : l'enfant choisit d'abord son objectif de vie.
		_dream_intro = true
		_open_dream()
	else:
		_welcome()


## Accueil : le tutoriel au premier lancement, sinon un simple bonjour.
func _welcome() -> void:
	var profile: Dictionary = _game().profile
	if not profile.get("tuto_fait", false):
		start_tutorial()
	else:
		hud.toast("Bonjour %s ! Clique sur un objet pour agir." % profile["name"], UiTheme.COL_ACCENT, 5.0)
		if not profile.get("jardin_vu", false):
			hud.toast("Nouveau : le jardin ! Clique sur « Jardin », en bas à droite.", UiTheme.COL_GOOD.darkened(0.1), 8.0, "feuille")
		elif not profile["famille"]["vu"]:
			hud.toast("Nouveau : la famille ! Clique sur « Ma famille », à gauche.", FamilyPanel.COL_FAMILY.darkened(0.1), 8.0, "couple")


func _game():
	return get_node("/root/Game")


func _apply_settings() -> void:
	var quality: int = _game().local_settings["qualite"]
	studio.apply_quality(quality)
	get_viewport().scaling_3d_scale = 0.7 if quality == 0 else 1.0
	_fps_time = 0.0
	_fps_frames = 0


# --- Boucle de jeu ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var game = _game()
	var profile: Dictionary = game.profile
	if profile.is_empty(): # joueur en train de changer : l'écran va disparaître
		return
	if tutorial != null:
		_tutorial_avoid()
	# En pause (menu, panneau), le personnage s'arrête : rien ne démarre derrière un panneau.
	character.frozen = paused
	if _arrival_pending and not paused and not typing.is_open():
		_arrival_pending = false
		_on_arrived()
	if not paused:
		var sleeping: bool = _state == "acting" and Data.ACTIONS[_action_id].get("sleep", false)
		var factor := SLEEP_TIME_FACTOR if sleeping else 1.0
		var minutes := delta * factor # 1 seconde réelle = 1 minute de jeu
		profile["game_minutes"] += minutes
		if tutorial == null: # pendant le tutoriel, les besoins ne baissent pas
			_update_needs(profile, minutes / 60.0, sleeping, delta)
		if _state == "acting":
			_progress_action(profile, minutes)
		_update_missions(profile, delta)
		studio.set_time(profile["game_minutes"], sleeping)
		_check_objective()
		_check_dream(delta)
	var fraction := -1.0
	if _state == "acting":
		fraction = _action_done_minutes / float(Data.ACTIONS[_action_id]["minutes"])
	hud.update_display(profile, "" if typing.is_open() else _status_text(), fraction)
	hud.dream_button.visible = not typing.is_open() # le panneau de frappe a besoin de la place
	hud.family_button.visible = not typing.is_open() and tutorial == null
	hud.garden_box.visible = not typing.is_open() and tutorial == null
	# La caméra suit le personnage quand il passe de la maison au jardin (ou revient).
	var zone: String = studio.zone_of(character.position)
	if zone != _char_zone:
		_char_zone = zone
		_set_view(zone)
	_watch_fps(delta)
	_watch_session_timer()


## Minuterie de séance (réglée par l'ergo) : on prévient une minute avant, puis la
## séance se termine en douceur, une fois la frappe en cours finie.
func _watch_session_timer() -> void:
	var game = _game()
	var limit := Progression.session_limit_sec(game.profile)
	if limit <= 0.0 or _session_over:
		return
	var elapsed: float = game.session.get("duree_sec", 0.0)
	if not _session_warned and elapsed >= limit - 60.0:
		_session_warned = true
		hud.toast("Plus qu'une minute de jeu : termine ce que tu fais !", UiTheme.COL_ACCENT, 6.0, "horloge")
	if elapsed >= limit and not typing.is_open() and _state != "series":
		_end_session_by_timer()


func _end_session_by_timer() -> void:
	_session_over = true
	_interrupt_action()
	if _mission_panel != null:
		_mission_panel.visible = false
	var game = _game()
	game.session["fin_minuterie"] = true
	game.save_profile()
	game.play_sound("bravo")
	var panel := SessionEndPanel.new()
	panel.finished.connect(func(): quit_to_profiles.emit())
	_open_overlay(panel)


func _update_needs(profile: Dictionary, hours: float, sleeping: bool, real_delta: float) -> void:
	var speed: float = Progression.NEEDS_SPEED.get(Progression.setting(profile, "vitesse_besoins"), 1.0)
	var any_red := false
	for n in Data.NEED_ORDER:
		var rate: float = Data.NEEDS[n]["decay"] * speed
		if sleeping:
			rate = 0.0 if n == "sommeil" else rate * SLEEP_OTHER_NEEDS
		profile["needs"][n] = clampf(profile["needs"][n] - rate * hours, 0.0, 100.0)
		var red: bool = profile["needs"][n] < Data.RED_THRESHOLD
		if red:
			any_red = true
			_game().session["rouge_sec"][n] = _game().session["rouge_sec"].get(n, 0.0) + real_delta
		if red and not _was_red[n]:
			hud.toast("%s %s %s" % [profile["name"], Data.need_alert(n, profile.get("appearance", {})), Data.NEEDS[n]["conseil"]], UiTheme.COL_BAD, 6.0, n)
			_game().play_sound("alerte")
		_was_red[n] = red
	if any_red:
		_game().session["rouge_au_moins_une_sec"] = _game().session.get("rouge_au_moins_une_sec", 0.0) + real_delta
	Objectives.notify(profile, "temps", {"sec": real_delta, "rouge": any_red})


func _status_text() -> String:
	var who: String = _game().profile["name"]
	match _state:
		"walking":
			return "%s y va…" % who
		"acting", "series":
			return "%s %s…" % [who, Data.ACTIONS[_action_id]["verbe"]]
	return ""


## Si le jeu est trop lent sur cet ordinateur, on allège les graphismes tout seul.
func _watch_fps(delta: float) -> void:
	var game = _game()
	if game.demo_mode or paused or DisplayServer.get_name() == "headless":
		return
	_fps_time += delta
	if _fps_time < 4.0: # on laisse le jeu démarrer
		return
	_fps_frames += 1
	if _fps_time >= 12.0:
		var fps := _fps_frames / (_fps_time - 4.0)
		_fps_time = 0.0
		_fps_frames = 0
		if fps < 24.0 and game.local_settings["qualite"] > 0:
			game.quality_lowered(game.local_settings)
			game.set_local_setting("qualite", game.local_settings["qualite"])
			hud.toast("Graphismes allégés pour que le jeu reste fluide.", UiTheme.COL_GREY, 5.0, "reglages")


# --- Souris : choisir un objet ou un endroit ---------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _session_over: # la séance est finie : on ne referme pas le panneau pour rejouer
			return
		if _overlay != null:
			_close_overlay()
		elif _menu != null:
			_close_menu()
		elif not typing.is_open():
			_toggle_pause()
		return
	if paused or typing.is_open() or _menu != null or _overlay != null:
		return
	if event is InputEventMouseMotion:
		var hit: Dictionary = studio.pick(event.position)
		var f = hit.get("furniture", null)
		if f != _hovered:
			if _hovered != null:
				_hovered.set_highlight(false)
			_hovered = f
			if f != null:
				f.set_highlight(true)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit: Dictionary = studio.pick(event.position)
		if hit.has("furniture"):
			_game().play_sound("clic")
			_choose_object(hit["furniture"])
		elif hit.has("floor"):
			_interrupt_action()
			_state = "walking"
			_action_id = ""
			_object = null
			character.walk_path(studio.compute_path(character.position, studio.clamp_to_room(hit["floor"])))


func _choose_object(f) -> void:
	if f.actions.is_empty(): # chambre des enfants : le berceau attend un bébé, les jouets un enfant
		hud.toast("Rien à faire ici pour l'instant.", UiTheme.COL_GREY, 3.0)
		return
	if f.actions.size() == 1:
		if f.actions[0] == "construire":
			_open_build()
		else:
			_start_typing(f, f.actions[0])
		return
	_open_action_menu(f)


func _open_action_menu(f) -> void:
	_close_menu()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.shade(root, 0.25)
	ui.add_child(root)
	_menu = root
	var box := UiTheme.centered_panel(root, 460)
	var title_row := HBoxContainer.new()
	box.add_child(title_row)
	var title := UiTheme.label(f.display_name, 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var labels := []
	for a in f.actions:
		labels.append(_action_label(a))
	title_row.add_child(UiTheme.speak_button(func(): return f.display_name + ". " + ". ".join(labels)))
	for a in f.actions:
		var b := UiTheme.icon_button(_action_icon(a), _action_label(a), _action_color(a), 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			_close_menu()
			if a == "travail":
				_open_career()
			elif a == "look":
				_open_look()
			elif a == "construire":
				_open_build()
			else:
				_start_typing(f, a))
		box.add_child(b)
	var cancel := UiTheme.button("Retour", UiTheme.COL_GREY, 20)
	cancel.pressed.connect(_close_menu)
	box.add_child(cancel)


func _action_label(a: String) -> String:
	if a == "travail":
		return "Mon travail"
	if a == "look":
		return "Changer de look"
	if a == "construire":
		return "Construire"
	return Data.ACTIONS[a]["label"]


func _action_icon(a: String) -> String:
	if a == "travail":
		return "travail"
	if a == "look":
		return "perso"
	if a == "construire":
		return "marteau"
	var action: Dictionary = Data.ACTIONS[a]
	if action.has("recolte"):
		return Data.RESOURCES[action["recolte"]]["icone"]
	if not action["skills"].is_empty():
		return Data.main_skill(a)
	for n in action["needs"]:
		if action["needs"][n] > 0.0:
			return n
	return "fleche"


func _action_color(a: String) -> Color:
	if a == "travail":
		return UiTheme.COL_ORANGE
	if a == "look":
		return UiTheme.COL_ACCENT
	if a == "construire":
		return UiTheme.COL_ORANGE
	if a != "travail" and Data.ACTIONS[a].has("recolte"):
		return UiTheme.RESOURCE_COLORS[Data.ACTIONS[a]["recolte"]]
	var icon_name := _action_icon(a)
	return UiTheme.SKILL_COLORS.get(icon_name, Hud.NEED_COLORS.get(icon_name, UiTheme.COL_ACCENT))


func _close_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null


# --- Frappe puis action -------------------------------------------------------------------

func _start_typing(f, action_id: String) -> void:
	var profile: Dictionary = _game().profile
	var action: Dictionary = Data.ACTIONS[action_id]
	var text := Progression.text_for(action["texts"], profile)
	var timed := Progression.next_is_timed(profile)
	var limit := Progression.time_limit(profile, text) if timed else 0.0
	_interrupt_action()
	_state = "typing"
	_typing_mode = "action"
	_object = f
	_action_id = action_id
	_last_typing_chars = text.length()
	_set_view(studio.zone_of(f.position)) # la caméra montre déjà où le personnage va aller
	typing.open(text, "Pour « %s », recopie :" % action["label"], timed, limit)
	_tutorial_event("typing_opened")


## La frappe vient d'être acceptée (le panneau est encore ouvert un court instant).
func _on_typing_validated(result: Dictionary) -> void:
	if _typing_mode == "series":
		_on_series_word_ok(result)


func _on_typing_finished(result: Dictionary) -> void:
	var game = _game()
	var profile: Dictionary = game.profile
	if _typing_mode == "mission":
		_typing_mode = "action"
		_on_mission_item_typed(result)
		return
	if _typing_mode == "series":
		_on_series_word_finished(result)
		return
	match result["status"]:
		"ok":
			Progression.record_success(profile, result["cps"], typing.timed)
			if typing.timed:
				game.session["chronos_reussis"] += 1
			# Les mots tapés font aussi progresser les compétences de l'action.
			for s in Data.ACTIONS[_action_id]["skills"]:
				game.add_skill_xp(s, _last_typing_chars * 0.3)
			_state = "walking"
			character.walk_path(studio.compute_path(character.position, _object.use_point, _object))
			_tutorial_event("typed_ok")
		"timeout":
			Progression.record_timeout(profile)
			game.session["chronos_rates"] += 1
			_state = "idle"
		"cancel":
			# Un objet cliqué par erreur, refermé sans rien taper, n'est pas un abandon.
			if result.get("typed", true):
				game.session["taches_abandonnees"] += 1
			_state = "idle"


func _on_arrived() -> void:
	if _state != "walking":
		return
	if typing.is_open(): # une frappe de mission est en cours : l'activité attend qu'elle se termine
		_arrival_pending = true
		return
	if _object == null or _action_id == "":
		_state = "idle"
		_tutorial_event("moved")
		return
	if Data.is_series(_action_id):
		_start_series()
		return
	_state = "acting"
	_action_done_minutes = 0.0
	character.start_acting(_object.pose, _object.pose_point, _object.face_point, Data.ACTIONS[_action_id]["anim"])
	studio.start_activity(_object, _action_id)
	_place_family(_action_id)
	studio.focus_on(character.position * Vector3(1, 0, 1), 0.15)


func _progress_action(profile: Dictionary, minutes: float) -> void:
	var action: Dictionary = Data.ACTIONS[_action_id]
	var total: float = action["minutes"]
	var step := minf(minutes, total - _action_done_minutes)
	_action_done_minutes += step
	for n in action["needs"]:
		profile["needs"][n] = clampf(profile["needs"][n] + action["needs"][n] * step / total, 0.0, 100.0)
	if _action_done_minutes >= total:
		_finish_action()


func _finish_action() -> void:
	var game = _game()
	var action: Dictionary = Data.ACTIONS[_action_id]
	var gained := []
	for s in action["skills"]:
		game.add_skill_xp(s, action["skills"][s])
		gained.append(Data.SKILLS[s]["label"])
	game.session["taches_finies"] += 1
	Objectives.notify(game.profile, "action", {"action": _action_id})
	if not gained.is_empty():
		hud.toast("+ " + ", ".join(gained), UiTheme.COL_GOOD, 2.5, "etoile")
	game.play_sound("fini")
	_leave_object()
	_tutorial_event("action_done")


## Le personnage quitte l'objet (il descend du lit, se lève du canapé…).
func _leave_object() -> void:
	_state = "idle"
	_action_id = ""
	_series = {}
	studio.stop_activity()
	studio.unfocus()
	character.stop()
	if _object != null:
		character.position = _object.use_point
	_object = null
	_sync_family() # chacun retourne à sa place


func _interrupt_action() -> void:
	_arrival_pending = false
	if _state == "acting" or _state == "series":
		_leave_object()
	elif _state == "walking":
		character.stop()
	_state = "idle"


func _on_skill_level_up(skill: String, level: int) -> void:
	hud.toast("Bravo ! %s passe au niveau %d !" % [Data.SKILLS[skill]["label"], level], UiTheme.SKILL_COLORS.get(skill, UiTheme.COL_PURPLE), 4.5, skill)
	_game().play_sound("niveau")
	studio.burst(character.position)
	if _state != "series" and _state != "acting":
		character.play_once("celebrate", 1.5)
	# Les missions étaient faites mais il manquait une compétence : promotion maintenant.
	if Progression.try_promotion(_game().profile):
		_announce_promotion()


# --- Séries de mots (activités qui entraînent une compétence) ------------------------------

func _skill_fraction(skill: String) -> float:
	var xp: float = _game().profile["skills_xp"].get(skill, 0.0)
	var level := Data.skill_level(xp)
	if level >= Data.SKILL_MAX:
		return 1.0
	var from := float(Data.xp_for_level(level))
	return clampf((xp - from) / (Data.xp_for_level(level + 1) - from), 0.0, 1.0)


func _start_series() -> void:
	var profile: Dictionary = _game().profile
	_state = "series"
	character.start_acting(_object.pose, _object.pose_point, _object.face_point, Data.ACTIONS[_action_id]["anim"])
	studio.start_activity(_object, _action_id)
	_place_family(_action_id) # la famille prend part à l'activité (et place le personnage)
	studio.focus_on(character.position * Vector3(1, 0, 1))
	_series = {"action": _action_id, "index": 0, "results": [],
		"words": Data.series_words(_action_id, Progression.text_level(profile), Data.WORDS_PER_SERIES)}
	_tutorial_event("series_started")
	_open_series_word()


func _open_series_word() -> void:
	var profile: Dictionary = _game().profile
	var word: String = _series["words"][_series["index"]]
	var timed := Progression.next_is_timed(profile)
	var limit := Progression.time_limit(profile, word) if timed else 0.0
	var total: int = _series["words"].size()
	_typing_mode = "series"
	var title := "%s · mot %d sur %d" % [Data.ACTIONS[_action_id]["label"], _series["index"] + 1, total]
	var res: String = Data.ACTIONS[_action_id].get("recolte", "")
	if res != "": # récolte : la réserve s'affiche et grandit à chaque mot
		title += " · tu as %s" % Data.resource_text(res, Build.stock(profile, res))
	typing.open_series(word, title, timed, limit, total, _series["results"])
	var skill := Data.main_skill(_action_id)
	typing.set_skill(skill, Progression.skill_level(profile, skill), _skill_fraction(skill))


func _on_series_word_ok(result: Dictionary) -> void:
	var game = _game()
	var profile: Dictionary = game.profile
	var action_id: String = _series["action"]
	var action: Dictionary = Data.ACTIONS[action_id]
	var word: String = _series["words"][_series["index"]]
	Progression.record_success(profile, result["cps"], typing.timed)
	if typing.timed:
		game.session["chronos_reussis"] += 1
	var skill := Data.main_skill(action_id)
	var before := Progression.skill_level(profile, skill)
	var weights := Data.skill_weights(action_id)
	var xp := Data.word_xp(word)
	for s in weights:
		game.add_skill_xp(s, xp * weights[s])
	for n in action["needs"]:
		profile["needs"][n] = clampf(profile["needs"][n] + action["needs"][n] / float(Data.WORDS_PER_SERIES), 0.0, 100.0)
	game.session["mots_ok"] += 1
	game.session["mots_par_activite"][action_id] = int(game.session["mots_par_activite"].get(action_id, 0)) + 1
	profile["mots_tapes"][action_id] = int(profile["mots_tapes"].get(action_id, 0)) + 1
	Objectives.notify(profile, "mot", {"action": action_id})
	if action.get("famille", "") == "couple": # un mot réussi = un peu plus de complicité
		var was_ready := Family.can_move_in(profile)
		Family.add_complicity(profile, Data.FAMILY_COMPLICITY_PER_WORD)
		if Family.can_move_in(profile) and not was_ready:
			hud.toast("Vous êtes très complices ! Clique sur « Ma famille » pour vivre ensemble.", FamilyPanel.COL_FAMILY.darkened(0.1), 6.0, "coeur")
	if action.has("recolte"): # un mot réussi = une bûche ou une pierre
		game.add_resource(action["recolte"], 1)
		_series["recolte"] = int(_series.get("recolte", 0)) + 1
		Objectives.notify(profile, "recolte", {"res": action["recolte"], "amount": 1})
	var after := Progression.skill_level(profile, skill)
	typing.animate_skill(after, _skill_fraction(skill), xp, after > before)
	_series["results"].append(true)


func _on_series_word_finished(result: Dictionary) -> void:
	var game = _game()
	if _series.is_empty():
		return
	match result["status"]:
		"timeout":
			Progression.record_timeout(game.profile)
			game.session["chronos_rates"] += 1
			_series["results"].append(false)
		"cancel":
			_stop_series()
			return
	_series["index"] += 1
	if _series["index"] >= _series["words"].size():
		_finish_series()
	else:
		_open_series_word()


func _finish_series() -> void:
	var game = _game()
	var action_id: String = _series["action"]
	var action: Dictionary = Data.ACTIONS[action_id]
	var ok_count: int = _series["results"].count(true)
	_typing_mode = "action"
	game.session["series_finies"] += 1
	game.session["taches_finies"] += 1
	if ok_count > 0: # bonus de fin de série
		for s in action["skills"]:
			game.add_skill_xp(s, action["skills"][s])
	Objectives.notify(game.profile, "serie", {"action": action_id})
	Objectives.notify(game.profile, "action", {"action": action_id})
	if action.has("recolte"):
		var res: String = action["recolte"]
		hud.toast("Récolte terminée : + %s ! Tu en as %d." % [Data.resource_text(res, int(_series.get("recolte", 0))), Build.stock(game.profile, res)],
			UiTheme.COL_GOOD, 5.0, Data.RESOURCES[res]["icone"])
		game.save_profile()
	else:
		hud.toast("Série terminée : %d mots sur %d ! + %s" % [ok_count, _series["words"].size(), Data.SKILLS[Data.main_skill(action_id)]["label"]],
			UiTheme.COL_GOOD, 4.0, "etoile")
	game.play_sound("bravo")
	var grown_name := ""
	if action.get("famille", "") == "bebe" and ok_count > 0:
		var baby_name: String = Family.baby(game.profile).get("nom", "")
		if game.care_baby():
			grown_name = baby_name
	elif action.has("famille"):
		game.save_profile()
	var where: Vector3 = _object.use_point if _object != null else character.position
	_leave_object()
	studio.burst(where)
	character.play_once("celebrate", 1.6)
	if grown_name != "":
		hud.toast("%s a grandi ! Clique sur les jouets pour jouer ensemble." % grown_name, FamilyPanel.COL_FAMILY.darkened(0.1), 7.0, "jouet")
		studio.hearts(studio.get_object("jouets").position + Vector3(0, 1.4, 0), 6, 3.0)
	_tutorial_event("series_end")


func _stop_series() -> void:
	var game = _game()
	_typing_mode = "action"
	game.session["series_interrompues"] += 1
	game.session["taches_abandonnees"] += 1
	Objectives.notify(game.profile, "serie_arretee")
	hud.toast("Série arrêtée. Tes mots réussis sont gardés !", UiTheme.COL_GREY, 3.0)
	_leave_object()
	_tutorial_event("series_end")


# --- Famille : rencontrer quelqu'un, vivre ensemble, les enfants -------------------------------

## Met la maison à jour (lit double, chambre des enfants, actions des objets)
## et remet chaque membre de la famille à sa place.
func _sync_family() -> void:
	var profile: Dictionary = _game().profile
	studio.set_double_bed(Family.is_together(profile))
	var sofa = studio.get_object("canape")
	sofa.actions = ["inviter"] + (Data.FAMILY_ACTIONS["couple"] if Family.has_partner(profile) else [])
	if not Family.children(profile).is_empty():
		studio.add_nursery()
	if studio.has_nursery():
		var baby := Family.baby(profile)
		if baby.is_empty():
			studio.set_baby(false)
		elif not studio.has_baby():
			studio.set_baby(true, Data.SKIN_COLORS[int(baby["apparence"].get("skin", 0)) % Data.SKIN_COLORS.size()])
		studio.get_object("berceau").actions = Data.FAMILY_ACTIONS["bebe"] if not baby.is_empty() else []
		var kid := ["jouer_enfant"] if Family.has_child(profile) else []
		studio.get_object("jouets").actions = kid
		studio.get_object("lit_enfant").actions = ["histoire"] if Family.has_child(profile) else []
	_place_family()


## Place la famille. Au repos (`action_id` vide) : le conjoint lit sur le canapé,
## les enfants jouent dans leur chambre. Pendant une activité, chacun y prend part.
func _place_family(action_id := "") -> void:
	var profile: Dictionary = _game().profile
	studio.clear_family()
	var kind: String = Data.ACTIONS[action_id].get("famille", "") if action_id != "" else ""
	var partner: Node3D = null
	# Avant de vivre ensemble, le conjoint vient seulement pour les moments à deux.
	if Family.has_partner(profile) and (Family.is_together(profile) or kind == "couple"):
		partner = studio.add_family_member(Family.partner(profile)["apparence"])
	var kids: Array = []
	if studio.has_nursery():
		for k in Family.grown(profile):
			kids.append(studio.add_family_member(k["apparence"], "enfant"))
	var sofa = studio.get_object("canape")
	var partner_placed := false
	match action_id:
		"fleurs":
			studio.duo(character, partner, COUPLE_SPOT, "give", "celebrate", 0.95)
			studio._fx.append(studio.hearts(COUPLE_SPOT + Vector3(0, 1.9, 0), 5))
			partner_placed = true
		"danser":
			studio.duo(character, partner, COUPLE_SPOT, "dance", "dance", 0.9)
			studio._fx.append(studio.hearts(COUPLE_SPOT + Vector3(0, 2.0, 0), 3))
			partner_placed = true
		"calin":
			var seats: Array = sofa.get_meta("guest_points")
			character.start_acting("assis", sofa.pose_point, sofa.face_point, "sit_cuddle")
			partner.start_acting("assis", (sofa.pose_point as Vector3).lerp(seats[0], 0.62), sofa.face_point, "sit_cuddle_r")
			studio._fx.append(studio.hearts(sofa.position + Vector3(0, 1.7, -0.2), 4))
			partner_placed = true
		"dormir":
			var bed = studio.get_object("lit")
			if partner != null:
				partner.start_acting("allonge", bed.get_meta("partner_point"), bed.get_meta("partner_face"), "sleep")
				partner_placed = true
			if not kids.is_empty(): # l'aîné dort dans son petit lit
				var small_bed = studio.get_object("lit_enfant")
				kids[0].start_acting("allonge", small_bed.pose_point, small_bed.face_point, "sleep")
				kids.remove_at(0)
		"bercer", "biberon": # le bébé quitte le berceau : il est dans les bras
			var crib = studio.get_object("berceau")
			studio.set_baby(false)
			character.start_acting("debout", crib.use_point, crib.use_point + Vector3(1, 0, 0.9), Data.ACTIONS[action_id]["anim"])
			studio._fx.append(studio.hearts(crib.use_point + Vector3(0.2, 1.9, 0.2), 3))
		"jouer_enfant":
			var toys = studio.get_object("jouets")
			character.start_acting("debout", toys.get_meta("adult_point"), toys.position, "kneel_play")
		"histoire": # l'aîné est couché, le personnage lui raconte une histoire
			var small_bed = studio.get_object("lit_enfant")
			if not kids.is_empty():
				kids[0].start_acting("allonge", small_bed.pose_point, small_bed.face_point, "sleep")
				kids.remove_at(0)
			character.start_acting("debout", small_bed.use_point, small_bed.pose_point, "talk")
	if partner != null and not partner_placed:
		var seat: Vector3 = sofa.get_meta("guest_points")[1]
		partner.start_acting("assis", seat, sofa.face_point + Vector3(0.8, 0, 0), "sit_read")
	if not kids.is_empty() and studio.has_nursery():
		var toys = studio.get_object("jouets")
		var spots := [[toys.get_meta("kid_point"), "floor_play"], [toys.position + Vector3(0.95, 0, -0.35), "cuddle_toy"]]
		for i in kids.size():
			kids[i].start_acting("debout", spots[i % 2][0], toys.position, spots[i % 2][1])


func _open_family() -> void:
	if typing.is_open() or _pause_menu != null:
		return
	_game().profile["famille"]["vu"] = true
	var panel := FamilyPanel.new()
	panel.met.connect(_on_family_met)
	panel.moved_in.connect(_on_moved_in)
	panel.baby_chosen.connect(_on_baby_chosen)
	panel.declined.connect(func():
		_game().decline_children()
		hud.toast("D'accord, pas d'enfant pour l'instant. Tu pourras changer d'avis quand tu veux.", UiTheme.COL_ACCENT, 5.0)
		panel.refresh())
	_open_overlay(panel)


## La rencontre : la personne choisie arrive et dit bonjour, des cœurs s'envolent.
func _on_family_met(person: Dictionary) -> void:
	var game = _game()
	if not game.meet(person):
		return
	_close_overlay()
	_interrupt_action()
	game.play_sound("bravo")
	hud.toast("Tu as rencontré %s ! Clique sur le canapé pour passer du temps ensemble." % person["nom"], FamilyPanel.COL_FAMILY.darkened(0.1), 7.0, "couple")
	_set_view("maison")
	_sync_family()
	var visitor: Node3D = studio.add_family_member(person["apparence"])
	studio.duo(character, visitor, COUPLE_SPOT, "wave", "wave", 1.1)
	studio.hearts(COUPLE_SPOT + Vector3(0, 1.9, 0), 6, 3.0)
	var end := create_tween()
	end.tween_interval(3.5)
	end.tween_callback(func():
		# La personne rencontrée repart même si l'enfant a déjà cliqué ailleurs
		# (pendant une activité, l'activité a déjà placé la famille).
		if _state == "idle":
			character.stop()
		if _state == "idle" or _state == "walking":
			_sync_family())


func _on_moved_in() -> void:
	var game = _game()
	if not game.move_in():
		return
	_close_overlay()
	game.play_sound("bravo")
	hud.toast("%s vient vivre avec toi ! Le lit est maintenant un grand lit." % Family.partner_name(game.profile), FamilyPanel.COL_FAMILY.darkened(0.1), 7.0, "famille")
	_set_view("maison")
	_sync_family()
	studio.hearts(studio.get_object("canape").position + Vector3(0, 1.7, -0.2), 6, 3.0)


func _on_baby_chosen(child: Dictionary) -> void:
	var game = _game()
	var first: bool = not studio.has_nursery()
	var baby: Dictionary = game.have_baby(child)
	if baby.is_empty():
		return
	_close_overlay()
	_interrupt_action()
	if first:
		studio.add_nursery(true)
	_sync_family()
	game.play_sound("bravo")
	hud.toast("Bienvenue %s ! Clique sur le berceau pour bercer le bébé ou lui donner le biberon." % baby["nom"], FamilyPanel.COL_FAMILY.darkened(0.1), 8.0, "bebe")
	_set_view("chambre")
	var crib = studio.get_object("berceau")
	studio.hearts(crib.position + Vector3(0, 1.3, 0), 8, 3.5)
	studio.burst(crib.position)


# --- Objectifs ---------------------------------------------------------------------------

func _check_objective() -> void:
	var profile: Dictionary = _game().profile
	if Objectives.is_done(profile):
		if not _objective_announced:
			_objective_announced = true
			hud.toast("Objectif atteint ! Clique sur « Objectif atteint » pour ta récompense.", UiTheme.COL_GOLD.darkened(0.15), 6.0, "cible")
			_game().play_sound("objectif")
	else:
		_objective_announced = false


func _open_objectives() -> void:
	if typing.is_open() or _overlay != null or _pause_menu != null:
		return
	var game = _game()
	var profile: Dictionary = game.profile
	var panel := ObjectivePanel.new()
	if Objectives.is_done(profile):
		var reward := Objectives.claim(profile)
		game.add_money(reward["pieces"])
		game.session["objectifs_finis"] += 1
		game.play_sound("piece")
		studio.burst(character.position)
		panel.reward = reward
	panel.offers = Objectives.offers(profile)
	panel.chosen.connect(_on_objective_chosen)
	_open_overlay(panel)


func _on_objective_chosen(offer: Dictionary) -> void:
	var game = _game()
	if Objectives.has_current(game.profile):
		game.session["objectifs_abandonnes"] += 1
	Objectives.choose(game.profile, offer)
	game.session["objectifs_choisis"] += 1
	_objective_announced = false
	_close_overlay()
	hud.toast("Nouvel objectif : %s" % offer["label"], UiTheme.COL_CORAL, 4.5, "cible")
	game.play_sound("clic")
	game.save_profile()


# --- Mon rêve : l'objectif de vie -----------------------------------------------------------

func _open_dream() -> void:
	if typing.is_open() or _pause_menu != null:
		return
	var panel := DreamPanel.new()
	panel.first = _dream_intro
	panel.chosen.connect(_on_dream_chosen)
	_open_overlay(panel)
	if _dream_intro: # « Plus tard » ou « Fermer » : la partie commence quand même
		panel.closed.connect(_end_dream_intro)


func _end_dream_intro() -> void:
	if _dream_intro:
		_dream_intro = false
		_welcome()


func _on_dream_chosen(dream: String) -> void:
	var game = _game()
	game.choose_dream(dream)
	_dream_wait = 0.0
	_close_overlay()
	game.play_sound("clic")
	hud.toast("Ton rêve : %s !" % Data.dream(dream, game.profile)["label"].to_lower(), UiTheme.COL_DREAM.darkened(0.1), 5.0, "reve")
	var career: String = Data.DREAMS[dream]["career"]
	if not _dream_intro and career != "" and game.profile["career"]["current"] == "":
		hud.toast("Clique sur « Travail » et choisis : %s." % Data.career(career, game.profile)["label"], UiTheme.COL_ACCENT, 6.0, "travail")
	_end_dream_intro()


## Le rêve est réalisé : après quelques secondes de calme, on le fête.
func _check_dream(delta: float) -> void:
	var game = _game()
	if not Dreams.to_celebrate(game.profile):
		_dream_wait = 0.0
		return
	if _overlay != null or _mission_panel != null or tutorial != null or typing.is_open() or _state in ["acting", "series", "typing"]:
		return
	_dream_wait += delta
	if _dream_wait < DREAM_PARTY_DELAY:
		return
	_dream_wait = 0.0
	var reward: Dictionary = game.claim_dream()
	if reward.is_empty():
		return
	game.play_sound("bravo")
	game.play_sound("niveau")
	studio.burst(character.position)
	character.play_once("celebrate", 2.5)
	var panel := DreamPanel.new()
	panel.reward = reward
	panel.chosen.connect(_on_dream_chosen)
	_open_overlay(panel)


# --- Magasin : agrandir la maison ---------------------------------------------------------

func _open_shop() -> void:
	if typing.is_open() or _pause_menu != null:
		return
	var panel := ShopPanel.new()
	panel.bought.connect(_on_shop_bought)
	_open_overlay(panel)


func _on_shop_bought(item: String) -> void:
	var game = _game()
	if not game.buy(item):
		return
	_close_overlay()
	var f = studio.add_purchase(item, true)
	if f != null:
		_set_view(studio.zone_of(f.position))
	game.play_sound("piece")
	game.play_sound("bravo")
	hud.toast("Nouveau dans ta maison : %s ! Clique dessus pour essayer." % Data.SHOP[item]["label"].to_lower(), UiTheme.COL_GOLD.darkened(0.15), 7.0, "maison")
	if f == null:
		return
	studio.burst(f.position)
	# La caméra montre la nouveauté quelques secondes, avec la flèche dorée.
	f.set_marker(true)
	if _state == "idle":
		studio.focus_on(f.position, 0.15)
	var show := create_tween() # lié à cet écran : s'arrête tout seul si on change de joueur
	show.tween_interval(4.0)
	show.tween_callback(func():
		if _state != "acting" and _state != "series":
			studio.unfocus())
	show.tween_interval(8.0)
	show.tween_callback(func():
		if tutorial == null:
			f.set_marker(false))


# --- Jardin : changer de vue, construire ---------------------------------------------------

## Montre la maison ou le jardin (la caméra glisse de l'un à l'autre).
func _set_view(view: String) -> void:
	if studio.view == view:
		return
	studio.set_view(view)
	hud.set_view(view, studio.has_nursery())
	var profile: Dictionary = _game().profile
	if view == "jardin" and not profile.get("jardin_vu", false):
		profile["jardin_vu"] = true
		hud.toast("Voici le jardin ! Clique sur le tas de bois ou sur les rochers pour récolter.", UiTheme.COL_GOOD.darkened(0.1), 8.0, "feuille")


func _toggle_view() -> void:
	if typing.is_open() or _overlay != null or _pause_menu != null:
		return
	_game().play_sound("clic")
	_set_view(hud.next_view(studio.view, studio.has_nursery()))


func _open_build() -> void:
	if typing.is_open() or _pause_menu != null:
		return
	var panel := BuildPanel.new()
	panel.built.connect(_on_built)
	panel.garden_requested.connect(func():
		_close_overlay()
		_set_view("jardin"))
	_open_overlay(panel)


func _on_built(item: String) -> void:
	var game = _game()
	if not game.build(item):
		return
	_close_overlay()
	var f = studio.add_construction(item, true)
	game.play_sound("fini")
	game.play_sound("bravo")
	hud.toast("Tu as construit : %s ! Clique dessus pour essayer." % Data.CONSTRUCTIONS[item]["label"].to_lower(), UiTheme.COL_GOLD.darkened(0.15), 7.0, "marteau")
	_set_view("jardin")
	if f == null:
		return
	studio.burst(Vector3(f.position.x, 0, f.position.z))
	# La caméra montre la construction quelques secondes, avec la flèche dorée.
	f.set_marker(true)
	if _state == "idle":
		studio.focus_on(Vector3(f.position.x, 0, f.position.z), 0.15)
	var show := create_tween()
	show.tween_interval(4.0)
	show.tween_callback(func():
		if _state != "acting" and _state != "series":
			studio.unfocus())
	show.tween_interval(8.0)
	show.tween_callback(func():
		if tutorial == null:
			f.set_marker(false))


# --- Tutoriel et guide ---------------------------------------------------------------------

func start_tutorial() -> void:
	if tutorial != null:
		tutorial.queue_free()
	tutorial = Tutorial.new()
	tutorial.child_name = _game().profile["name"]
	tutorial.step_changed.connect(_on_tutorial_step)
	tutorial.finished.connect(_on_tutorial_finished)
	ui.add_child(tutorial)
	ui.move_child(tutorial, hud.get_index() + 1)


func _tutorial_event(event_name: String) -> void:
	if tutorial != null:
		tutorial.event(event_name)


## La bulle du tutoriel ne doit pas cacher la flèche dorée (seulement quand le
## panneau de frappe n'occupe pas le bas de l'écran).
func _tutorial_avoid() -> void:
	var pts: Array = []
	if _state != "typing" and _state != "series":
		for f in studio.furniture:
			for p in f.marker_points():
				if not studio.camera.is_position_behind(p):
					pts.append(studio.camera.unproject_position(p))
	tutorial.avoid_points = pts


func _on_tutorial_step(step_id: String) -> void:
	for f in studio.furniture:
		f.set_marker(false)
	hud.needs_panel.modulate = Color.WHITE
	hud.buttons_row.modulate = Color.WHITE
	match step_id:
		"objet", "taper":
			studio.get_object("lavabo").set_marker(true)
		"activite":
			studio.get_object("tapis").set_marker(true)
		"jauges":
			_pulse(hud.needs_panel)
		"boutons":
			_pulse(hud.buttons_row)


func _pulse(control: Control) -> void:
	var tween := control.create_tween().set_loops(8)
	tween.tween_property(control, "modulate", Color(1.35, 1.25, 0.9), 0.35)
	tween.tween_property(control, "modulate", Color.WHITE, 0.35)


func _on_tutorial_finished(_skipped: bool) -> void:
	var game = _game()
	if tutorial != null:
		tutorial.queue_free()
		tutorial = null
	game.profile["tuto_fait"] = true
	game.save_profile()
	if not Objectives.has_current(game.profile) and not typing.is_open():
		_open_objectives()


func _open_guide() -> void:
	if typing.is_open():
		return
	var panel := GuidePanel.new()
	for f in studio.furniture:
		panel.objects.append({"name": f.display_name, "actions": f.actions})
	_open_overlay(panel)


## Le miroir permet de changer l'apparence du personnage.
func _open_look() -> void:
	if typing.is_open():
		return
	var game = _game()
	var screen = load("res://scripts/screens/create_profile_screen.gd").new()
	screen.edit_mode = true
	screen.appearance = game.profile["appearance"].duplicate()
	screen.created.connect(func(_name, appearance):
		game.profile["appearance"] = appearance
		character.build(appearance)
		game.save_profile()
		_close_overlay())
	screen.back.connect(_close_overlay)
	_close_overlay()
	_close_menu()
	_overlay = screen
	paused = true
	ui.add_child(screen)


# --- Pause ------------------------------------------------------------------------------

func _toggle_pause() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
		paused = _overlay != null
		return
	if typing.is_open():
		return
	paused = true
	var panel := PausePanel.new()
	ui.add_child(panel)
	_pause_menu = panel
	panel.resume.connect(_toggle_pause)
	panel.change_player.connect(func(): quit_to_profiles.emit())
	panel.replay_tutorial.connect(func():
		_toggle_pause()
		start_tutorial())
	panel.quit_game.connect(func():
		_game().end_session()
		get_tree().quit())


# --- Étapes suivantes (compétences, carrières, missions) ---------------------------------

func _open_overlay(panel: Control) -> void:
	_close_overlay()
	_close_menu()
	_overlay = panel
	paused = true
	ui.add_child(panel)
	panel.closed.connect(_close_overlay)


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		paused = _pause_menu != null


func _open_skills() -> void:
	if typing.is_open():
		return
	_open_overlay(SkillsPanel.new())


func _open_career() -> void:
	if typing.is_open() or _pause_menu != null:
		return
	var panel := CareerPanel.new()
	panel.mission_available = not _mission_state.is_empty()
	panel.career_chosen.connect(_on_career_chosen)
	panel.mission_requested.connect(func():
		_close_overlay()
		_open_mission())
	_open_overlay(panel)


func _on_career_chosen(career: String) -> void:
	var profile: Dictionary = _game().profile
	if Progression.choose_career(profile, career):
		_close_overlay()
		_drop_mission()
		profile["mission_timer"] = 3.0 # première mission très vite
		hud.toast("Ton nouveau travail : %s !" % Data.career(career, profile)["label"], UiTheme.COL_GOOD, 4.0)
		var dream := Dreams.current(profile)
		if dream != "" and Data.DREAMS[dream]["career"] == career:
			hud.toast("C'est le travail de ton rêve !", UiTheme.COL_DREAM.darkened(0.1), 5.0, "reve")
		_game().save_profile()


# --- Missions ---------------------------------------------------------------------------

func _update_missions(profile: Dictionary, delta: float) -> void:
	if profile["career"]["current"] == "" or not _mission_state.is_empty():
		return
	profile["mission_timer"] -= delta
	if profile["mission_timer"] > 0.0:
		return
	var pool := Data.missions_for(profile["career"]["current"], Progression.current_tier(profile))
	pool = pool.filter(func(m): return m["id"] != _last_mission_id) if pool.size() > 1 else pool
	if pool.is_empty():
		return
	var mission: Dictionary = pool[randi() % pool.size()]
	_last_mission_id = mission["id"]
	_mission_state = {"data": mission, "step": "intro", "q": 0, "item": 0}
	hud.set_mission_available(true)
	hud.toast("Nouvelle mission : %s !" % mission["title"], UiTheme.COL_CORAL, 5.0, "drapeau")
	_game().play_sound("mission")


func _open_mission() -> void:
	if _mission_state.is_empty() or _mission_panel != null or typing.is_open() or _overlay != null:
		return
	_close_menu()
	var panel := MissionPanel.new()
	panel.state = _mission_state
	_mission_panel = panel
	ui.add_child(panel)
	ui.move_child(typing, -1)
	panel.closed.connect(_close_mission_panel)
	panel.abandoned.connect(_on_mission_abandoned)
	panel.typing_requested.connect(_on_mission_typing_requested)
	panel.completed.connect(_on_mission_completed)


func _close_mission_panel() -> void:
	if _mission_panel != null:
		_mission_panel.queue_free()
		_mission_panel = null


func _drop_mission() -> void:
	_close_mission_panel()
	_mission_state = {}
	hud.set_mission_available(false)
	_game().profile["mission_timer"] = float(Progression.setting(_game().profile, "missions_minutes")) * 60.0


func _on_mission_typing_requested(text: String, title: String) -> void:
	var profile: Dictionary = _game().profile
	if typing.is_open() or _state == "series": # une série est en cours : elle garde le clavier
		if _mission_panel != null:
			_mission_panel.visible = true
		hud.toast("Termine d'abord ta série de mots, puis reviens à la mission.", UiTheme.COL_ACCENT, 4.0, "drapeau")
		return
	var timed := Progression.next_is_timed(profile)
	_typing_mode = "mission"
	typing.open(text, title, timed, Progression.time_limit(profile, text) if timed else 0.0)


func _on_mission_item_typed(result: Dictionary) -> void:
	var game = _game()
	var profile: Dictionary = game.profile
	var ok: bool = result["status"] == "ok"
	if ok:
		Progression.record_success(profile, result["cps"], typing.timed)
		if typing.timed:
			game.session["chronos_reussis"] += 1
	elif result["status"] == "timeout":
		Progression.record_timeout(profile)
		game.session["chronos_rates"] += 1
	if _mission_panel != null:
		_mission_panel.item_typed(ok)


func _on_mission_abandoned() -> void:
	var session: Dictionary = _game().session
	session["missions_abandonnees"] += 1
	session["taches_abandonnees"] += 1
	_drop_mission()
	hud.toast("Mission abandonnée. Une autre arrivera bientôt.", Color(0.6, 0.62, 0.68))


func _on_mission_completed() -> void:
	var game = _game()
	var profile: Dictionary = game.profile
	var career: String = profile["career"]["current"]
	var pay := Progression.salary(profile)
	game.add_money(pay)
	Objectives.notify(profile, "argent", {"amount": pay})
	Objectives.notify(profile, "mission")
	game.play_sound("piece")
	studio.burst(character.position)
	var gained := []
	var skills: Dictionary = Data.CAREERS[career]["mission_skills"]
	game.session["missions_reussies"] += 1
	game.session["taches_finies"] += 1
	var promoted := Progression.complete_mission(profile)
	for s in skills:
		game.add_skill_xp(s, skills[s])
		gained.append(Data.SKILLS[s]["label"])
	_drop_mission()
	hud.toast("Mission réussie ! + %d pièces" % pay, UiTheme.COL_GOOD, 5.0, "piece")
	hud.toast("+ " + ", ".join(gained), UiTheme.COL_GOOD, 4.0)
	if promoted:
		_announce_promotion()
	elif profile["career"]["missions"].get(career, 0) >= Data.MISSIONS_PER_TIER:
		var missing := Progression.missing_for_next_tier(profile)
		var parts := []
		for s in missing:
			parts.append("%s %d" % [Data.SKILLS[s]["label"], missing[s]])
		if not parts.is_empty():
			hud.toast("Pour monter de palier, il te faut : " + ", ".join(parts), UiTheme.COL_ACCENT, 6.0)


func _announce_promotion() -> void:
	var profile: Dictionary = _game().profile
	var c: String = profile["career"]["current"]
	var tier := Progression.current_tier(profile)
	hud.toast("Promotion ! Tu deviens %s (palier %d)." % [Data.career(c, profile)["tiers"][tier - 1]["title"], tier], UiTheme.COL_PURPLE, 7.0, "travail")
	_game().play_sound("niveau")
	studio.burst(character.position)
