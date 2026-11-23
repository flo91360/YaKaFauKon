extends Node
## Autoload « Game » : profil en cours, sauvegarde locale, statistiques de séance,
## réglages de l'ordinateur (son, graphismes), sons, lecture vocale et thème visuel.

signal skill_level_up(skill: String, level: int)
signal money_changed(amount: int)
signal settings_changed

const Data = preload("res://scripts/core/data.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Shop = preload("res://scripts/core/shop.gd")
const Dreams = preload("res://scripts/core/dreams.gd")
const Build = preload("res://scripts/core/build.gd")
const Family = preload("res://scripts/core/family.gd")
const ErgoAccess = preload("res://scripts/core/ergo_access.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const SAVE_DIR := "user://profils"
const AUTOSAVE_SEC := 20.0
const SETTINGS_PATH := "user://reglages.json"
const ACCESS_PATH := "user://acces_ergo.json" # mot d'accès de l'ergo, haché
## Réglages de l'ordinateur (communs à tous les joueurs).
const DEFAULT_LOCAL_SETTINGS := {"volume": 70, "musique": 35, "qualite": 1, "plein_ecran": false, "prenoms_caches": false,
	"qualite_voulue": -1, "essais_remontee": 0} # qualite_voulue : niveau d'avant l'allègement automatique
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
		"reve": Dreams.new_state(),
		"ressources": Build.new_stock(),
		"constructions": [],
		"jardin_vu": false,
		"famille": Family.new_state(),
	}


func list_profiles() -> Array:
	var result := []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	var files := dir.get_files()
	var seen := {}
	for file in files:
		var id := ""
		if file.ends_with(".json"):
			id = file.trim_suffix(".json")
		elif file.ends_with(".json.bak") or file.ends_with(".json.tmp"):
			id = file.trim_suffix(".bak").trim_suffix(".tmp").trim_suffix(".json")
		if id == "" or seen.has(id):
			continue
		seen[id] = true
		# Profil illisible (coupure pendant une ancienne sauvegarde) : on reprend la
		# dernière sauvegarde complète.
		for ext in [".json", ".json.tmp", ".json.bak"]:
			var data := _read_json(SAVE_DIR + "/" + id + ext) if FileAccess.file_exists(SAVE_DIR + "/" + id + ext) else {}
			if not data.is_empty():
				result.append(data)
				break
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
	profile["reve"]["id"] = "artisan"
	profile["jardin_vu"] = true
	profile["famille"]["vu"] = true
	demo_mode = true
	start_session()


func save_profile() -> void:
	if profile.is_empty() or demo_mode:
		return
	_write_profile(profile)


func save_any(data: Dictionary) -> void:
	_write_profile(data)


## Sauvegarde sûre : le profil est d'abord écrit dans un fichier temporaire, puis
## mis à la place de l'ancien, qui est gardé en copie de secours (.bak). Une
## coupure pendant l'écriture ne peut donc pas effacer le profil.
func _write_profile(data: Dictionary) -> bool:
	var path := SAVE_DIR + "/" + str(data["id"]) + ".json"
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if not _read_json(tmp).is_empty(): # le fichier temporaire est complet et lisible
		if FileAccess.file_exists(path):
			if FileAccess.file_exists(path + ".bak"):
				DirAccess.remove_absolute(path + ".bak")
			DirAccess.rename_absolute(path, path + ".bak")
		return DirAccess.rename_absolute(tmp, path) == OK
	DirAccess.remove_absolute(tmp)
	return false


func delete_profile(id: String) -> void:
	for ext in [".json", ".json.bak", ".json.tmp"]:
		if FileAccess.file_exists(SAVE_DIR + "/" + id + ext):
			DirAccess.remove_absolute(SAVE_DIR + "/" + id + ext)


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
	data["typing"]["rates_suite"] = int(data["typing"]["rates_suite"])
	data["settings"]["missions_minutes"] = int(data["settings"]["missions_minutes"])
	data["appearance"] = Data.complete_appearance(data["appearance"])
	data["version"] = 2
	for key in ["objectifs_choisis", "objectifs_finis", "etoiles"]:
		data[key] = int(data[key])
	if not data["objectif"] is Dictionary:
		data["objectif"] = {}
	data["tuto_fait"] = bool(data["tuto_fait"])
	data["achats"] = Shop.clean(data["achats"])
	data["reve"] = Dreams.clean(data["reve"])
	data["ressources"] = Build.clean_stock(data["ressources"])
	data["constructions"] = Build.clean(data["constructions"])
	data["jardin_vu"] = bool(data["jardin_vu"])
	data["famille"] = Family.clean(data["famille"])
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
		"caracteres": 0, "temps_frappe_sec": 0.0, "caracteres_tentes": 0, "vitesse_niveaux": {},
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
		"reves_changes": 0, "reves_realises": [],
		"recoltes": {}, "constructions": [], "famille": [],
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


## Note une frappe validée. Les fautes ne sont comptées qu'à la première tentative
## d'un texte (sinon chaque appui sur Entrée recompterait les mêmes fautes), et le
## taux de fautes se calcule sur les caractères de tous les textes tentés.
func record_typing(result: Dictionary, chars: int, seconds: float, first_attempt := true) -> void:
	if first_attempt:
		for k in result["details"]:
			session["erreurs"][k] = session["erreurs"].get(k, 0) + result["details"][k]
		session["caracteres_tentes"] = int(session.get("caracteres_tentes", 0)) + chars
	if result["ok"]:
		session["frappes_ok"] += 1
		session["caracteres"] += chars
		session["temps_frappe_sec"] += seconds
		# Vitesse par niveau de texte : on ne compare que des textes du même niveau.
		if not session.get("vitesse_niveaux") is Dictionary:
			session["vitesse_niveaux"] = {}
		var level := str(Progression.text_level(profile)) if not profile.is_empty() else "1"
		var v: Dictionary = session["vitesse_niveaux"].get(level, {"caracteres": 0, "sec": 0.0})
		v["caracteres"] = int(v.get("caracteres", 0)) + chars
		v["sec"] = float(v.get("sec", 0.0)) + seconds
		session["vitesse_niveaux"][level] = v
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


## Ajoute des ressources récoltées dans le jardin (comptées dans la séance).
func add_resource(res: String, amount: int = 1) -> void:
	amount = maxi(amount, 0)
	Build.add(profile, res, amount)
	if not session.get("recoltes") is Dictionary:
		session["recoltes"] = {}
	session["recoltes"][res] = int(session["recoltes"].get(res, 0)) + amount


## Construit dans le jardin avec les ressources du profil. Renvoie false si impossible.
func build(id: String) -> bool:
	if not Build.build(profile, id):
		return false
	if not session.get("constructions") is Array:
		session["constructions"] = []
	session["constructions"].append(id)
	save_profile()
	return true


# --- Famille ------------------------------------------------------------------------------

## Note un moment de la famille dans la séance (pour l'ergothérapeute).
func _family_event(text: String) -> void:
	if not session.get("famille") is Array:
		session["famille"] = []
	session["famille"].append(text)


## Rencontre la personne choisie. Renvoie false si ce n'est pas possible.
func meet(person: Dictionary) -> bool:
	if not Family.meet(profile, person):
		return false
	_family_event("a rencontré %s" % Family.partner_name(profile))
	save_profile()
	return true


func move_in() -> bool:
	if not Family.move_in(profile):
		return false
	_family_event("vit avec %s" % Family.partner_name(profile))
	save_profile()
	return true


## Le bébé arrive : renvoie son état ({} si ce n'est pas possible).
func have_baby(child: Dictionary) -> Dictionary:
	var baby := Family.have_baby(profile, child)
	if baby.is_empty():
		return baby
	_family_event("naissance de %s" % baby["nom"])
	save_profile()
	return baby


func decline_children() -> void:
	Family.decline_children(profile)
	_family_event("choisit de ne pas avoir d'enfant pour l'instant")
	save_profile()


## Un soin au bébé (série terminée). Renvoie true s'il vient de grandir.
func care_baby() -> bool:
	var name: String = Family.baby(profile).get("nom", "")
	var grew := Family.care_baby(profile)
	if grew:
		_family_event("%s a grandi" % name)
	save_profile()
	return grew


## Choisit l'objectif de vie (« Mon rêve »). Un changement en cours de route est
## compté dans la séance, pour l'ergothérapeute.
func choose_dream(dream: String) -> void:
	if Dreams.choose(profile, dream):
		session["reves_changes"] = int(session.get("reves_changes", 0)) + 1
	save_profile()


## Fête le rêve qui vient d'être réalisé : verse la récompense et la renvoie
## ({} s'il n'y a rien à fêter).
func claim_dream() -> Dictionary:
	var reward := Dreams.claim(profile)
	if reward.is_empty():
		return reward
	add_money(reward["pieces"])
	if not session.get("reves_realises") is Array:
		session["reves_realises"] = []
	session["reves_realises"].append(Dreams.current(profile))
	save_profile()
	return reward


# --- Mot d'accès de l'espace ergothérapeute -----------------------------------------

func ergo_access() -> Dictionary:
	return _read_json(ACCESS_PATH) if FileAccess.file_exists(ACCESS_PATH) else {}


func check_ergo_word(word: String) -> bool:
	return ErgoAccess.check(ergo_access(), word)


## Enregistre le mot choisi par l'ergo (haché). Renvoie false si l'écriture échoue.
func set_ergo_word(word: String) -> bool:
	var file := FileAccess.open(ACCESS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(ErgoAccess.make(word), "\t"))
	file.close()
	return ErgoAccess.is_set(ergo_access())


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
	local_settings["qualite_voulue"] = clampi(local_settings["qualite_voulue"], -1, 2)


## Graphismes allégés tout seuls parce que le jeu saccadait : on note le niveau
## d'avant pour le retenter plus tard.
static func quality_lowered(s: Dictionary) -> void:
	if int(s.get("qualite_voulue", -1)) < 0:
		s["qualite_voulue"] = int(s["qualite"])
	s["qualite"] = maxi(int(s["qualite"]) - 1, 0)


const QUALITY_RETRIES := 2 ## remontées automatiques tentées avant d'en rester là

## Au début d'une partie : si les graphismes ont été allégés tout seuls, on retente
## le niveau au-dessus (un ralentissement passager ne laisse pas « Léger » pour
## toujours). Au plus QUALITY_RETRIES fois, tant que l'adulte n'a rien choisi.
## Renvoie true si le niveau a changé.
static func quality_retry(s: Dictionary) -> bool:
	var wanted := int(s.get("qualite_voulue", -1))
	if wanted <= int(s["qualite"]) or int(s.get("essais_remontee", 0)) >= QUALITY_RETRIES:
		return false
	s["qualite"] = int(s["qualite"]) + 1
	s["essais_remontee"] = int(s.get("essais_remontee", 0)) + 1
	return true


## Choix fait à la main dans les réglages : il remplace l'allègement automatique.
func choose_quality(level: int) -> void:
	local_settings["qualite_voulue"] = -1
	local_settings["essais_remontee"] = 0
	set_local_setting("qualite", level)


## Début de partie : retente si besoin un niveau de graphismes plus beau.
func retry_quality() -> void:
	if quality_retry(local_settings):
		set_local_setting("qualite", local_settings["qualite"])


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
