extends Node
## Écran de jeu : le studio, le personnage, le temps qui passe, les besoins,
## les actions déclenchées par la frappe, et les panneaux (compétences, travail…).

signal quit_to_profiles

const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Studio = preload("res://scripts/world/studio.gd")
const Character = preload("res://scripts/world/character.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const TypingPanel = preload("res://scripts/ui/typing_panel.gd")
const SkillsPanel = preload("res://scripts/ui/skills_panel.gd")

const SLEEP_TIME_FACTOR := 24.0 # pendant le sommeil, le temps passe 24 fois plus vite
const SLEEP_OTHER_NEEDS := 0.25 # les autres besoins baissent moins vite en dormant

var studio
var character
var hud
var typing
var ui: CanvasLayer
var paused := false

var _state := "idle" # idle / typing / walking / acting
var _action_id := ""
var _object = null
var _action_done_minutes := 0.0
var _last_typing_chars := 0
var _menu: Control = null
var _pause_menu: Control = null
var _overlay: Control = null # panneau compétences / travail (le jeu est en pause)
var _hovered = null
var _was_red := {}


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
	typing = TypingPanel.new()
	ui.add_child(typing)
	typing.finished.connect(_on_typing_finished)
	game.skill_level_up.connect(_on_skill_level_up)
	for n in Data.NEED_ORDER:
		_was_red[n] = game.profile["needs"][n] < Data.RED_THRESHOLD
	hud.toast("Bonjour %s ! Clique sur un objet pour agir." % game.profile["name"], UiTheme.COL_ACCENT, 5.0)


func _game():
	return get_node("/root/Game")


# --- Boucle de jeu ---------------------------------------------------------------------

func _process(delta: float) -> void:
	var game = _game()
	var profile: Dictionary = game.profile
	if not paused:
		var sleeping: bool = _state == "acting" and Data.ACTIONS[_action_id].get("sleep", false)
		var factor := SLEEP_TIME_FACTOR if sleeping else 1.0
		var minutes := delta * factor # 1 seconde réelle = 1 minute de jeu
		profile["game_minutes"] += minutes
		_update_needs(profile, minutes / 60.0, sleeping, delta)
		if _state == "acting":
			_progress_action(profile, minutes)
		_update_missions(profile, delta)
	hud.update_display(profile, _status_text())


func _update_needs(profile: Dictionary, hours: float, sleeping: bool, real_delta: float) -> void:
	var speed: float = Progression.NEEDS_SPEED.get(Progression.setting(profile, "vitesse_besoins"), 1.0)
	for n in Data.NEED_ORDER:
		var rate: float = Data.NEEDS[n]["decay"] * speed
		if sleeping:
			rate = 0.0 if n == "sommeil" else rate * SLEEP_OTHER_NEEDS
		profile["needs"][n] = clampf(profile["needs"][n] - rate * hours, 0.0, 100.0)
		var red: bool = profile["needs"][n] < Data.RED_THRESHOLD
		if red:
			_game().session["rouge_sec"][n] = _game().session["rouge_sec"].get(n, 0.0) + real_delta
		if red and not _was_red[n]:
			hud.toast("%s %s %s" % [profile["name"], Data.NEEDS[n]["alerte"], Data.NEEDS[n]["conseil"]], UiTheme.COL_BAD, 6.0)
		_was_red[n] = red


func _status_text() -> String:
	var who: String = _game().profile["name"]
	match _state:
		"walking":
			return "%s y va…" % who
		"acting":
			return "%s %s…" % [who, Data.ACTIONS[_action_id]["verbe"]]
	return ""


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
	ui.add_child(root)
	_menu = root
	var box := UiTheme.centered_panel(root, 420)
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
		var b := UiTheme.button(_action_label(a))
		b.pressed.connect(func():
			_close_menu()
			if a == "travail":
				_open_career()
			else:
				_start_typing(f, a))
		box.add_child(b)
	var cancel := UiTheme.button("Retour", Color(0.6, 0.62, 0.68))
	cancel.pressed.connect(_close_menu)
	box.add_child(cancel)


func _action_label(a: String) -> String:
	return "Mon travail" if a == "travail" else Data.ACTIONS[a]["label"]


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
	_object = f
	_action_id = action_id
	_last_typing_chars = text.length()
	typing.open(text, "Pour « %s », recopie :" % action["label"], timed, limit)


func _on_typing_finished(result: Dictionary) -> void:
	var game = _game()
	var profile: Dictionary = game.profile
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
		return
	_state = "acting"
	_action_done_minutes = 0.0
	character.start_acting(_object.pose, _object.pose_point, _object.face_point)


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
	if not gained.is_empty():
		hud.toast("+ " + ", ".join(gained), UiTheme.COL_GOOD, 2.5)
	_state = "idle"
	_action_id = ""
	character.stop()
	# Le personnage descend du lit / du canapé à côté de l'objet.
	if _object != null:
		character.position = _object.use_point
	_object = null


func _interrupt_action() -> void:
	if _state == "acting":
		character.stop()
		if _object != null:
			character.position = _object.use_point
	elif _state == "walking":
		character.stop()
	_state = "idle"


func _on_skill_level_up(skill: String, level: int) -> void:
	hud.toast("Bravo ! %s passe au niveau %d !" % [Data.SKILLS[skill]["label"], level], Color(0.65, 0.5, 0.85), 4.5)


# --- Pause ------------------------------------------------------------------------------

func _toggle_pause() -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
		paused = false
		return
	paused = true
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.12, 0.2, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	ui.add_child(root)
	_pause_menu = root
	var box := UiTheme.centered_panel(root, 420)
	var title := UiTheme.label("Pause", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume := UiTheme.button("Reprendre")
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var change := UiTheme.button("Changer de joueur", Color(0.6, 0.62, 0.68))
	change.pressed.connect(func(): quit_to_profiles.emit())
	box.add_child(change)


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
	hud.toast("Le travail arrive bientôt.")


func _open_mission() -> void:
	pass


func _update_missions(_profile: Dictionary, _delta: float) -> void:
	pass
