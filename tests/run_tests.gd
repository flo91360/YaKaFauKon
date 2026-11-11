extends SceneTree
## Tests de la logique du jeu, sans affichage.
## Lancer : Godot --headless --path . --script res://tests/run_tests.gd

const TypingCheck = preload("res://scripts/core/typing_check.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Data = preload("res://scripts/core/data.gd")

var _fails := 0
var _count := 0


func _init() -> void:
	_test_typing()
	_test_speed()
	_test_text_levels()
	_test_skills()
	_test_careers()
	_test_data()
	print("")
	print("%d tests, %d échec(s)" % [_count, _fails])
	quit(1 if _fails > 0 else 0)


func check(cond: bool, label: String) -> void:
	_count += 1
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  ÉCHEC ", label)


func _test_typing() -> void:
	print("Frappe tolérante")
	check(TypingCheck.check("toilettes", "toilettes")["ok"], "texte identique")
	check(TypingCheck.check("écran", "ECRAN")["ok"], "accents et majuscules ignorés")
	check(TypingCheck.check("écran", "ECRAN")["errors"] == 0, "accents/majuscules ne comptent pas comme erreurs")
	check(TypingCheck.check("écran", "ECRAN")["details"]["accents"] >= 1, "accent oublié noté pour l'ergo")
	check(TypingCheck.check("toilettes", "toilete")["ok"] == false, "mot seul : 2 erreurs refusées")
	check(TypingCheck.check("sport", "sprot")["ok"], "mot seul : 1 inversion acceptée")
	check(TypingCheck.check("sport", "sprot")["details"]["inversion"] == 1, "inversion reconnue")
	check(TypingCheck.check("aller aux toilettes", "aler aux toilette")["ok"], "texte long : 2 erreurs acceptées")
	check(TypingCheck.check("aller aux toilettes", "aler au toilete")["ok"] == false, "texte long : 3 erreurs refusées")
	check(TypingCheck.check("le lit", "  le   lit. ")["ok"], "espaces et point final ignorés")
	check(TypingCheck.check("lit", "")["ok"] == false, "texte vide refusé")
	check(TypingCheck.check("toilettes", "toiletes", -1)["ok"] == false, "tolérance stricte")
	check(TypingCheck.check("toilettes", "toltes", 1)["ok"] == false, "tolérance large : 3 oublis refusés")
	var d: Dictionary = TypingCheck.check("repas", "rpas")["details"]
	check(d["oubli"] == 1, "oubli de lettre reconnu")
	d = TypingCheck.check("repas", "reppas")["details"]
	check(d["ajout"] == 1, "lettre en trop reconnue")
	d = TypingCheck.check("repas", "revas")["details"]
	check(d["substitution"] == 1, "lettre remplacée reconnue")


func _profile() -> Dictionary:
	var skills := {}
	for s in Data.SKILLS:
		skills[s] = 0.0
	return {"typing": Progression.new_typing_state(), "settings": Progression.DEFAULT_SETTINGS.duplicate(),
		"skills_xp": skills, "money": 0, "career": {"current": "", "tiers": {}, "missions": {}}}


func _test_speed() -> void:
	print("Vitesse adaptative")
	var p := _profile()
	check(not Progression.next_is_timed(p), "pas de chronomètre au début")
	for i in Progression.CALIBRATION_COUNT:
		Progression.record_success(p, 1.0 + i * 0.1, false)
	check(Progression.is_calibrated(p), "vitesse de base mesurée après %d frappes" % Progression.CALIBRATION_COUNT)
	var base_limit := Progression.time_limit(p, "aller aux toilettes")
	check(base_limit > Progression.READ_MARGIN_SEC, "limite de temps positive (%.1f s)" % base_limit)
	var timed_seen := false
	for i in 3:
		if Progression.next_is_timed(p):
			timed_seen = true
		Progression.record_success(p, 1.3, Progression.next_is_timed(p))
	check(timed_seen, "le chronomètre apparaît régulièrement")
	for i in 40:
		Progression.record_success(p, 3.0, false)
	var fast_limit := Progression.time_limit(p, "aller aux toilettes")
	check(fast_limit < base_limit, "l'exigence monte quand l'enfant va plus vite")
	for i in 40:
		Progression.record_success(p, 30.0, false)
	var capped := Progression.time_limit(p, "aller aux toilettes")
	var floor_limit: float = Progression.READ_MARGIN_SEC + "aller aux toilettes".length() / (p["typing"]["baseline_cps"] * Progression.SPEED_CAP_FACTOR)
	check(absf(capped - floor_limit) < 0.01, "l'exigence se stabilise (plafond)")
	p["settings"]["chrono"] = "jamais"
	check(not Progression.next_is_timed(p), "réglage : jamais de chronomètre")


func _test_text_levels() -> void:
	print("Niveaux de texte")
	var p := _profile()
	var texts: Array = Data.ACTIONS["toilettes"]["texts"]
	check(Progression.text_for(texts, p) == "toilettes", "niveau 1 : mot-clé")
	for i in 10:
		Progression.record_success(p, 1.0, false)
	check(Progression.text_for(texts, p) == "les toilettes", "niveau 2 : article + mot")
	for i in 15:
		Progression.record_success(p, 1.0, false)
	check(Progression.text_for(texts, p) == "aller aux toilettes", "niveau 3 : petite phrase")
	p["settings"]["niveau_texte"] = "1"
	check(Progression.text_for(texts, p) == "toilettes", "réglage : niveau forcé")


func _test_skills() -> void:
	print("Compétences")
	check(Data.skill_level(0.0) == 0, "niveau 0 au départ")
	check(Data.skill_level(Data.xp_for_level(3)) == 3, "niveau 3")
	check(Data.skill_level(1e9) == Data.SKILL_MAX, "niveau max 10")
	check(Data.active_skills().size() >= 4, "au moins 4 compétences actives")


func _test_careers() -> void:
	print("Carrières")
	var p := _profile()
	check(Progression.choose_career(p, "artisan"), "choisir artisan")
	check(Progression.current_tier(p) == 1, "palier 1 au départ")
	check(not Progression.can_change_career(p), "pas de changement au palier 1")
	check(not Progression.choose_career(p, "organisateur"), "changement refusé au palier 1")
	for i in Data.MISSIONS_PER_TIER:
		Progression.complete_mission(p)
	check(Progression.current_tier(p) == 1, "pas de promotion sans les compétences")
	check(Progression.missing_for_next_tier(p).has("physique"), "il manque la compétence physique")
	p["skills_xp"]["physique"] = Data.xp_for_level(2)
	p["skills_xp"]["creativite"] = Data.xp_for_level(1)
	check(Progression.try_promotion(p), "promotion avec les compétences")
	check(Progression.current_tier(p) == 2, "palier 2")
	check(Progression.salary(p) == 35, "salaire du palier 2")
	check(Progression.choose_career(p, "organisateur"), "changement possible au palier 2")
	check(Progression.current_tier(p) == 1, "nouvelle carrière au palier 1")
	check(p["career"]["tiers"]["artisan"] == 2, "ancien palier conservé")
	check(p["skills_xp"]["physique"] == Data.xp_for_level(2), "compétences conservées")


func _test_data() -> void:
	print("Données")
	for id in Data.ACTIONS:
		check(Data.ACTIONS[id]["texts"].size() == 3, "action %s : 3 niveaux de texte" % id)
	for m in Data.MISSIONS:
		var ok := true
		for q in m["questions"]:
			ok = ok and q["good"] < q["choices"].size()
		for it in m["items"]:
			ok = ok and it.size() == 3
		check(ok, "mission %s bien formée" % m["id"])
	for c in Data.CAREERS:
		check(Data.CAREERS[c]["tiers"].size() == 5, "carrière %s : 5 paliers" % c)
		check(Data.missions_for(c, 1).size() >= 2, "carrière %s : missions disponibles" % c)
