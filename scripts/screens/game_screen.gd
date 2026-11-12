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
const MissionPanel = preload("res://scripts/ui/mission_panel.gd")
const ObjectivePanel = preload("res://scripts/ui/objective_panel.gd")
const GuidePanel = preload("res://scripts/ui/guide_panel.gd")
const PausePanel = preload("res://scripts/ui/pause_panel.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

const SLEEP_TIME_FACTOR := 24.0 # pendant le sommeil, le temps passe 24 fois plus vite
const SLEEP_OTHER_NEEDS := 0.25 # les autres besoins baissent moins vite en dormant

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
var _fps_time := 0.0
var _fps_frames := 0


func _ready() -> void:
	var game = get_node("/root/Game")
	studio = Studio.new()
	add_child(studio)
	character = Character.new()
	studio.add_child(character)
	character.build(game.profile["appearance"])
	character.position = Vector3(0.4, 0, 0.8)
	character.face(Vector3(5, 0, 6))
	character.arrived.connect(_on_arrived)

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
	typing = TypingPanel.new()
	ui.add_child(typing)
	typing.validated.connect(_on_typing_validated)
	typing.finished.connect(_on_typing_finished)
	game.skill_level_up.connect(_on_skill_level_up)
	game.settings_changed.connect(_apply_settings)
	_apply_settings()
	game.start_music()
	for n in Data.NEED_ORDER:
		_was_red[n] = game.profile["needs"][n] < Data.RED_THRESHOLD
	_objective_announced = Objectives.is_done(game.profile)
	if not game.profile.get("tuto_fait", false):
		start_tutorial()
	else:
		hud.toast("Bonjour %s ! Clique sur un objet pour agir." % game.profile["name"], UiTheme.COL_ACCENT, 5.0)


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
	var fraction := -1.0
	if _state == "acting":
		fraction = _action_done_minutes / float(Data.ACTIONS[_action_id]["minutes"])
	hud.update_display(profile, "" if typing.is_open() else _status_text(), fraction)
	_watch_fps(delta)


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
			hud.toast("%s %s %s" % [profile["name"], Data.NEEDS[n]["alerte"], Data.NEEDS[n]["conseil"]], UiTheme.COL_BAD, 6.0, n)
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
			game.set_local_setting("qualite", game.local_settings["qualite"] - 1)
			hud.toast("Graphismes allégés pour que le jeu reste fluide.", UiTheme.COL_GREY, 5.0, "reglages")


# --- Souris : choisir un objet ou un endroit ---------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
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
	if f.actions.size() == 1:
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
	return Data.ACTIONS[a]["label"]


func _action_icon(a: String) -> String:
	if a == "travail":
		return "travail"
	if a == "look":
		return "perso"
	var action: Dictionary = Data.ACTIONS[a]
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
			game.session["taches_abandonnees"] += 1
			_state = "idle"


func _on_arrived() -> void:
	if _state != "walking":
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


func _interrupt_action() -> void:
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
	typing.open_series(word, "%s · mot %d sur %d" % [Data.ACTIONS[_action_id]["label"], _series["index"] + 1, total],
		timed, limit, total, _series["results"])
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
	hud.toast("Série terminée : %d mots sur %d ! + %s" % [ok_count, _series["words"].size(), Data.SKILLS[Data.main_skill(action_id)]["label"]],
		UiTheme.COL_GOOD, 4.0, "etoile")
	game.play_sound("bravo")
	var where: Vector3 = _object.use_point if _object != null else character.position
	_leave_object()
	studio.burst(where)
	character.play_once("celebrate", 1.6)
	_tutorial_event("series_end")


func _stop_series() -> void:
	var game = _game()
	_typing_mode = "action"
	game.session["series_interrompues"] += 1
	game.session["taches_abandonnees"] += 1
	hud.toast("Série arrêtée. Tes mots réussis sont gardés !", UiTheme.COL_GREY, 3.0)
	_leave_object()
	_tutorial_event("series_end")


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
		hud.toast("Ton nouveau travail : %s !" % Data.CAREERS[career]["label"], UiTheme.COL_GOOD, 4.0)


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
	hud.toast("Promotion ! Tu deviens %s (palier %d)." % [Data.CAREERS[c]["tiers"][tier - 1]["title"], tier], UiTheme.COL_PURPLE, 7.0, "travail")
	_game().play_sound("niveau")
	studio.burst(character.position)
