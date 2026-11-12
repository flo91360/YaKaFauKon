extends SceneTree
## Tests de la logique du jeu, sans affichage.
## Lancer : Godot --headless --path . --script res://tests/run_tests.gd

const TypingCheck = preload("res://scripts/core/typing_check.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Data = preload("res://scripts/core/data.gd")
const Objectives = preload("res://scripts/core/objectives.gd")

var _fails := 0
var _count := 0


func _init() -> void:
	_test_typing()
	_test_speed()
	_test_text_levels()
	_test_skills()
	_test_careers()
	_test_data()
	_test_lexique()
	_test_appearance()
	_test_objectives()
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


func _test_lexique() -> void:
	print("Champs lexicaux")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for id in Data.ACTIONS:
		var has_skills: bool = not Data.ACTIONS[id]["skills"].is_empty()
		check(Data.is_series(id) == has_skills, "action %s : série de mots si et seulement si elle entraîne une compétence" % id)
		check(Data.ACTIONS[id].has("anim"), "action %s : animation définie" % id)
	for id in Data.LEXIQUE:
		var lists: Array = Data.LEXIQUE[id]
		var total := 0
		var clean := true
		var all_words := []
		for list in lists:
			total += list.size()
			for w in list:
				clean = clean and not w.contains("œ") and not w.contains("'") and w == w.strip_edges() and w.length() >= 2
				all_words.append(w)
		check(lists.size() == 3 and total >= 25, "%s : 3 niveaux et au moins 25 mots (%d)" % [id, total])
		check(clean, "%s : mots faciles à trouver sur le clavier" % id)
		var unique := {}
		for w in all_words:
			unique[w] = true
		check(unique.size() == all_words.size(), "%s : pas de mot en double" % id)
		var easy := Data.series_words(id, 1, Data.WORDS_PER_SERIES, rng)
		var only_easy := true
		for w in easy:
			only_easy = only_easy and w in lists[0]
		check(easy.size() == Data.WORDS_PER_SERIES and only_easy, "%s : niveau 1 = mots courts, sans doublon dans la série" % id)
		var hard := Data.series_words(id, 3, Data.WORDS_PER_SERIES, rng)
		var no_easy := true
		for w in hard:
			no_easy = no_easy and not w in lists[0]
		check(no_easy, "%s : niveau 3 = mots moyens et longs" % id)
	check(Data.word_xp("endurance") > Data.word_xp("saut"), "un mot long rapporte plus qu'un mot court")
	check(Data.main_skill("cuisiner") == "organisation" and Data.skill_weights("cuisiner")["creativite"] < 1.0, "compétence principale et secondaire")


func _test_appearance() -> void:
	print("Apparence")
	var old := Data.complete_appearance({"skin": 3, "hair": 4, "hair_style": 2, "outfit": 1})
	check(old["skin"] == 3 and old["hair"] == 4 and old["hair_style"] == 2 and old["outfit"] == 1, "apparence de la version 1 conservée")
	check(old.size() == Data.APPEARANCE_COUNTS.size() and old["body"] == 0 and old["height"] == 2, "nouvelles options complétées")
	var bad := Data.complete_appearance({"skin": 99, "height": -4, "glasses": 2.0})
	check(bad["skin"] == Data.SKIN_COLORS.size() - 1 and bad["height"] == 0 and typeof(bad["glasses"]) == TYPE_INT, "valeurs hors limites corrigées")
	var sizes_ok: bool = Data.SKIN_COLORS.size() == Data.APPEARANCE_COUNTS["skin"] and Data.HAIR_COLORS.size() == Data.APPEARANCE_COUNTS["hair"] \
		and Data.HAIR_STYLES.size() == Data.APPEARANCE_COUNTS["hair_style"] and Data.OUTFIT_COLORS.size() == Data.APPEARANCE_COUNTS["outfit"] \
		and Data.EYE_COLORS.size() == Data.APPEARANCE_COUNTS["eye_color"] and Data.HEIGHT_SCALES.size() == Data.APPEARANCE_COUNTS["height"] \
		and Data.BUILD_FACTORS.size() == Data.APPEARANCE_COUNTS["build"] and Data.BODIES.size() == 2
	check(sizes_ok, "listes d'options cohérentes")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var valid := true
	for i in 50:
		var a := Data.random_appearance(rng)
		valid = valid and a == Data.complete_appearance(a)
	check(valid, "personnages au hasard toujours valides")


func _test_objectives() -> void:
	print("Objectifs")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var p := _profile()
	p["objectif"] = {}
	p["objectifs_finis"] = 0
	p["objectifs_choisis"] = 0
	p["etoiles"] = 0
	var first := Objectives.offers(p, rng)
	var types := first.map(func(o): return o["type"])
	check(first.size() == 3 and types == ["competence", "mots", "soins"], "premier choix guidé : compétence, mots, soins")
	check(not "metier" in Objectives.candidates(p).map(func(o): return o["type"]), "pas d'objectif métier avant le premier objectif réussi")
	# Objectif « taper des mots »
	Objectives.choose(p, {"type": "mots", "action": "sport", "target": 2, "label": "x", "pieces": 10})
	check(not Objectives.notify(p, "mot", {"action": "peindre"}), "un mot d'une autre activité ne compte pas")
	check(not Objectives.notify(p, "mot", {"action": "sport"}) and is_equal_approx(Objectives.fraction(p), 0.5), "avancement à la moitié")
	check(Objectives.notify(p, "mot", {"action": "sport"}) and Objectives.is_done(p), "objectif atteint au 2e mot")
	var reward := Objectives.claim(p)
	check(reward["pieces"] == 10 and p["etoiles"] == 1 and p["objectifs_finis"] == 1 and not Objectives.has_current(p), "récompense : pièces et étoile")
	check(Objectives.claim(p).is_empty(), "pas de récompense sans objectif")
	# Compétence
	Objectives.choose(p, {"type": "competence", "skill": "physique", "target": 1, "label": "x", "pieces": 20})
	p["skills_xp"]["physique"] = 10.0
	check(is_equal_approx(Objectives.fraction(p), 0.5) and not Objectives.is_done(p), "compétence : barre à la moitié")
	p["skills_xp"]["physique"] = 20.0
	check(Objectives.is_done(p), "compétence : niveau atteint")
	Objectives.claim(p)
	# Jauges hors du rouge
	Objectives.choose(p, {"type": "vert", "target": 10, "label": "x", "pieces": 5})
	Objectives.notify(p, "temps", {"sec": 6.0, "rouge": false})
	Objectives.notify(p, "temps", {"sec": 1.0, "rouge": true})
	check(Objectives.current(p)["count"] == 0.0, "une jauge dans le rouge remet le compteur à zéro")
	Objectives.notify(p, "temps", {"sec": 10.0, "rouge": false})
	check(Objectives.is_done(p), "jauges hors du rouge assez longtemps")
	Objectives.claim(p)
	# Soins et séries
	Objectives.choose(p, {"type": "soins", "target": 1, "label": "x", "pieces": 5})
	check(not Objectives.notify(p, "action", {"action": "sport"}) and Objectives.notify(p, "action", {"action": "douche"}), "seules les actions de soin comptent")
	Objectives.claim(p)
	# Travail
	var with_job := Objectives.candidates(p).map(func(o): return o["type"])
	check("metier" in with_job and not "missions" in with_job, "sans métier : on propose d'en choisir un")
	check("metier" in Objectives.offers(p, rng).map(func(o): return o["type"]), "le choix d'un métier est proposé en priorité")
	Objectives.choose(p, {"type": "metier", "target": 1, "label": "x", "pieces": 20})
	Progression.choose_career(p, "artisan")
	check(Objectives.is_done(p), "objectif métier atteint")
	Objectives.claim(p)
	var job_types := Objectives.candidates(p).map(func(o): return o["type"])
	check("missions" in job_types and "palier" in job_types and "argent" in job_types and not "metier" in job_types, "avec un métier : missions, palier, argent")
	Objectives.choose(p, {"type": "argent", "target": 30, "label": "x", "pieces": 5})
	check(not Objectives.notify(p, "argent", {"amount": 20}) and Objectives.notify(p, "argent", {"amount": 20}), "argent gagné compté")
	Objectives.abandon(p)
	check(not Objectives.has_current(p) and Objectives.fraction(p) == 0.0, "abandon : plus d'objectif")
	var varied := true
	for i in 30:
		var offers := Objectives.offers(p, rng)
		var seen := {}
		for o in offers:
			seen[o["type"]] = true
		varied = varied and offers.size() == 3 and seen.size() == 3
	check(varied, "toujours 3 propositions de types différents")
