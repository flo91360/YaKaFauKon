extends Node
## Autoload « Game » : profil en cours, sauvegarde locale, statistiques de séance,
## réglages de l'ordinateur (son, graphismes), sons, lecture vocale et thème visuel.

signal skill_level_up(skill: String, level: int)
signal money_changed(amount: int)
signal settings_changed

const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Shop = preload("res://scripts/core/shop.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const SAVE_DIR := "user://profils"
const AUTOSAVE_SEC := 20.0
const SETTINGS_PATH := "user://reglages.json"
## Réglages de l'ordinateur (communs à tous les joueurs).
const DEFAULT_LOCAL_SETTINGS := {"volume": 70, "musique": 35, "qualite": 1, "plein_ecran": false}
const QUALITY_LABELS := ["Léger", "Normal", "Beau"]

var profile: Dictionary = {}
var session: Dictionary = {}
var demo_mode := false # profil de démonstration, jamais sauvegardé
var _autosave_timer := 0.0
var _tts_voice := ""
var local_settings: Dictionary = DEFAULT_LOCAL_SETTINGS.duplicate()
var _sounds := {}
var _players: Array = []
var _music: AudioStreamPlayer


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
	_load_local_settings()
	_setup_audio()
	apply_local_settings()


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
		"version": 2,
		"id": "%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000],
		"name": child_name,
		"appearance": Data.complete_appearance(appearance),
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
		"objectif": {},
		"objectifs_choisis": 0,
		"objectifs_finis": 0,
		"etoiles": 0,
		"tuto_fait": false,
		"mots_tapes": {},
		"achats": [],
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
	profile = new_profile_data("Camille", {"skin": 1, "hair": 1, "hair_style": 4, "outfit": 3, "outfit_style": 1, "eye_color": 2, "blush": 1, "mouth": 1})
	profile["tuto_fait"] = true
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
	data["appearance"] = Data.complete_appearance(data["appearance"])
	data["version"] = 2
	for key in ["objectifs_choisis", "objectifs_finis", "etoiles"]:
		data[key] = int(data[key])
	if not data["objectif"] is Dictionary:
		data["objectif"] = {}
	data["tuto_fait"] = bool(data["tuto_fait"])
	data["achats"] = Shop.clean(data["achats"])
	for a in data["mots_tapes"]:
		data["mots_tapes"][a] = int(data["mots_tapes"][a])
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
		"mots_ok": 0, "mots_par_activite": {},
		"series_finies": 0, "series_interrompues": 0,
		"objectifs_choisis": 0, "objectifs_finis": 0, "objectifs_abandonnes": 0,
		"argent_depense": 0, "achats": [],
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


## Achète un objet du magasin avec les pièces du profil. Renvoie false si impossible.
func buy(item: String) -> bool:
	if not Shop.buy(profile, item):
		return false
	session["argent_depense"] = int(session.get("argent_depense", 0)) + int(Data.SHOP[item]["prix"])
	if not session.get("achats") is Array:
		session["achats"] = []
	session["achats"].append(item)
	money_changed.emit(profile["money"])
	save_profile()
	return true


# --- Réglages de l'ordinateur, sons et musique ---------------------------------------

func _load_local_settings() -> void:
	var data := _read_json(SETTINGS_PATH) if FileAccess.file_exists(SETTINGS_PATH) else {}
	for key in DEFAULT_LOCAL_SETTINGS:
		if data.has(key):
			var v = data[key]
			local_settings[key] = bool(v) if DEFAULT_LOCAL_SETTINGS[key] is bool else int(v)
	local_settings["volume"] = clampi(local_settings["volume"], 0, 100)
	local_settings["musique"] = clampi(local_settings["musique"], 0, 100)
	local_settings["qualite"] = clampi(local_settings["qualite"], 0, 2)


func set_local_setting(key: String, value) -> void:
	local_settings[key] = value
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(local_settings, "\t"))
	apply_local_settings()
	settings_changed.emit()


func apply_local_settings() -> void:
	var sfx := AudioServer.get_bus_index("Sons")
	var music := AudioServer.get_bus_index("Musique")
	if sfx >= 0:
		AudioServer.set_bus_mute(sfx, local_settings["volume"] <= 0)
		AudioServer.set_bus_volume_db(sfx, linear_to_db(maxf(local_settings["volume"], 1) / 100.0))
	if music >= 0:
		AudioServer.set_bus_mute(music, local_settings["musique"] <= 0)
		AudioServer.set_bus_volume_db(music, linear_to_db(maxf(local_settings["musique"], 1) / 100.0) - 8.0)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		if local_settings["plein_ecran"] and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not local_settings["plein_ecran"] and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _setup_audio() -> void:
	for bus_name in ["Sons", "Musique"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = "Sons"
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = "Musique"
	add_child(_music)


## Joue un petit son (res://sons/<nom>.wav). Sans effet si le fichier n'existe pas.
func play_sound(sound_name: String, pitch := 1.0) -> void:
	if not _sounds.has(sound_name):
		var path := "res://sons/%s.wav" % sound_name
		_sounds[sound_name] = load(path) if ResourceLoader.exists(path) else null
	var stream = _sounds[sound_name]
	if stream == null:
		return
	for player in _players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch
			player.play()
			return
	_players[0].stream = stream
	_players[0].pitch_scale = pitch
	_players[0].play()


func start_music() -> void:
	if _music.playing:
		return
	var path := "res://sons/musique.ogg"
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


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
