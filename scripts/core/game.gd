extends Node
## Autoload « Game » : profil en cours, sauvegarde locale, statistiques de séance,
## lecture vocale et thème visuel.

signal skill_level_up(skill: String, level: int)
signal money_changed(amount: int)

const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const SAVE_DIR := "user://profils"
const AUTOSAVE_SEC := 20.0

var profile: Dictionary = {}
var session: Dictionary = {}
var demo_mode := false # profil de démonstration, jamais sauvegardé
var _autosave_timer := 0.0
var _tts_voice := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	# Le thème est fusionné dans le thème par défaut : il s'applique partout,
	# y compris aux interfaces placées dans des CanvasLayer.
	var theme := UiTheme.build()
	var default_theme := ThemeDB.get_default_theme()
	default_theme.merge_with(theme)
	default_theme.default_font = theme.default_font
	default_theme.default_font_size = theme.default_font_size
	get_tree().root.theme = theme
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		end_session()
		get_tree().quit()


func _process(delta: float) -> void:
	if profile.is_empty():
		return
	session["duree_sec"] = session.get("duree_sec", 0.0) + delta
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SEC:
		_autosave_timer = 0.0
		save_profile()


# --- Profils -------------------------------------------------------------------

func new_profile_data(child_name: String, appearance: Dictionary) -> Dictionary:
	var needs := {}
	for n in Data.NEED_ORDER:
		needs[n] = 80.0
	var skills := {}
	for s in Data.SKILLS:
		skills[s] = 0.0
	return {
		"version": 1,
		"id": "%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000],
		"name": child_name,
		"appearance": appearance,
		"created": Time.get_datetime_string_from_system(false, true),
		"needs": needs,
		"skills_xp": skills,
		"money": 0,
		"game_minutes": 8.0 * 60.0,
		"career": {"current": "", "tiers": {}, "missions": {}},
		"mission_timer": 0.0,
		"typing": Progression.new_typing_state(),
		"settings": Progression.DEFAULT_SETTINGS.duplicate(),
		"sessions": [],
	}


func list_profiles() -> Array:
	var result := []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	for file in dir.get_files():
		if file.ends_with(".json"):
			var data := _read_json(SAVE_DIR + "/" + file)
			if not data.is_empty():
				result.append(data)
	result.sort_custom(func(a, b): return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
	return result


func create_profile(child_name: String, appearance: Dictionary) -> void:
	profile = new_profile_data(child_name, appearance)
	demo_mode = false
	save_profile()
	start_session()


func load_profile(data: Dictionary) -> void:
	profile = _sanitize(data)
	demo_mode = false
	start_session()


func start_demo() -> void:
	profile = new_profile_data("Camille", {"skin": 1, "hair": 1, "hair_style": 1, "outfit": 0})
	demo_mode = true
	start_session()


func save_profile() -> void:
	if profile.is_empty() or demo_mode:
		return
	var file := FileAccess.open(SAVE_DIR + "/" + profile["id"] + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile, "\t"))


func save_any(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_DIR + "/" + str(data["id"]) + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func delete_profile(id: String) -> void:
	DirAccess.remove_absolute(SAVE_DIR + "/" + id + ".json")


func close_profile() -> void:
	end_session()
	profile = {}
	session = {}


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Complète un profil chargé (nouvelles clés) et remet les nombres entiers en int.
func _sanitize(data: Dictionary) -> Dictionary:
	var base := new_profile_data(str(data.get("name", "")), data.get("appearance", {}))
	for key in base:
		if not data.has(key):
			data[key] = base[key]
	for key in base["typing"]:
		if not data["typing"].has(key):
			data["typing"][key] = base["typing"][key]
	for key in base["settings"]:
		if not data["settings"].has(key):
			data["settings"][key] = base["settings"][key]
	for key in base["skills_xp"]:
		if not data["skills_xp"].has(key):
			data["skills_xp"][key] = 0.0
	for key in base["needs"]:
		if not data["needs"].has(key):
			data["needs"][key] = 80.0
	data["money"] = int(data["money"])
	data["typing"]["level"] = int(data["typing"]["level"])
	data["typing"]["level_successes"] = int(data["typing"]["level_successes"])
	data["typing"]["since_timed"] = int(data["typing"]["since_timed"])
	data["settings"]["missions_minutes"] = int(data["settings"]["missions_minutes"])
	for k in data["appearance"]:
		data["appearance"][k] = int(data["appearance"][k])
	for c in data["career"]["tiers"]:
		data["career"]["tiers"][c] = int(data["career"]["tiers"][c])
	for c in data["career"]["missions"]:
		data["career"]["missions"][c] = int(data["career"]["missions"][c])
	return data


# --- Séance (statistiques pour l'ergothérapeute) ----------------------------------

func start_session() -> void:
	var red := {}
	for n in Data.NEED_ORDER:
		red[n] = 0.0
	session = {
		"date": Time.get_datetime_string_from_system(false, true),
		"duree_sec": 0.0,
		"frappes_ok": 0, "frappes_ratees": 0, "chronos_reussis": 0, "chronos_rates": 0,
		"caracteres": 0, "temps_frappe_sec": 0.0,
		"erreurs": {"substitution": 0, "oubli": 0, "ajout": 0, "inversion": 0, "accents": 0, "majuscules": 0},
		"taches_finies": 0, "taches_abandonnees": 0,
		"missions_reussies": 0, "missions_abandonnees": 0,
		"choix_justes_du_premier_coup": 0, "choix_total": 0,
		"rouge_sec": red,
		"rouge_au_moins_une_sec": 0.0,
		"competences_debut": Progression.skill_levels(profile),
		"competences_fin": Progression.skill_levels(profile),
		"argent_gagne": 0,
	}
	profile["sessions"].append(session)
	_autosave_timer = 0.0


func end_session() -> void:
	if profile.is_empty():
		return
	session["competences_fin"] = Progression.skill_levels(profile)
	# On ne garde pas les séances vides (ouverture puis fermeture immédiate).
	if session.get("duree_sec", 0.0) < 20.0 and session.get("frappes_ok", 0) == 0:
		profile["sessions"].erase(session)
	save_profile()


func record_typing(result: Dictionary, chars: int, seconds: float) -> void:
	for k in result["details"]:
		session["erreurs"][k] = session["erreurs"].get(k, 0) + result["details"][k]
	if result["ok"]:
		session["frappes_ok"] += 1
		session["caracteres"] += chars
		session["temps_frappe_sec"] += seconds
	else:
		session["frappes_ratees"] += 1


func add_skill_xp(skill: String, amount: float) -> void:
	if not profile["skills_xp"].has(skill):
		profile["skills_xp"][skill] = 0.0
	var before := Progression.skill_level(profile, skill)
	profile["skills_xp"][skill] += amount
	var after := Progression.skill_level(profile, skill)
	session["competences_fin"] = Progression.skill_levels(profile)
	if after > before:
		skill_level_up.emit(skill, after)


func add_money(amount: int) -> void:
	profile["money"] += amount
	session["argent_gagne"] = session.get("argent_gagne", 0) + amount
	money_changed.emit(profile["money"])


# --- Lecture vocale ------------------------------------------------------------

func speak(text: String) -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return false
	if _tts_voice == "":
		var voices := DisplayServer.tts_get_voices_for_language("fr")
		if voices.is_empty():
			voices = DisplayServer.tts_get_voices_for_language("")
		if voices.is_empty():
			return false
		_tts_voice = voices[0]
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, _tts_voice, 80, 1.0, 0.9)
	return true
