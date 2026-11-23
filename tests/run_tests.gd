extends SceneTree
## Tests de la logique du jeu, sans affichage.
## Lancer : Godot --headless --path . --script res://tests/run_tests.gd

const TypingCheck = preload("res://scripts/core/typing_check.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Data = preload("res://scripts/core/data.gd")
const Objectives = preload("res://scripts/core/objectives.gd")
const Shop = preload("res://scripts/core/shop.gd")
const Dreams = preload("res://scripts/core/dreams.gd")
const Recap = preload("res://scripts/core/recap.gd")
const Build = preload("res://scripts/core/build.gd")
const Family = preload("res://scripts/core/family.gd")
const ErgoAccess = preload("res://scripts/core/ergo_access.gd")
const GameScript = preload("res://scripts/core/game.gd")

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
	_test_shop()
	_test_new_careers()
	_test_dreams()
	_test_garden()
	_test_family_graphics()
	_test_family()
	_test_recap_speeds()
	_test_ergo_access()
	_test_quality_retry()
	_test_agreement()
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
	for i in Progression.LEVEL_UP_SUCCESSES[1] - 1:
		Progression.record_success(p, 1.0, false)
	check(Progression.text_for(texts, p) == "toilettes", "encore niveau 1 juste avant le seuil")
	Progression.record_success(p, 1.0, false)
	check(Progression.text_for(texts, p) == "les toilettes", "niveau 2 : article + mot")
	for i in Progression.LEVEL_UP_SUCCESSES[2]:
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


func _test_shop() -> void:
	print("Magasin")
	var p := _profile()
	p["objectifs_finis"] = 2
	var bought_actions := 0
	for id in Data.ACTIONS:
		if Data.ACTIONS[id].has("achat"):
			bought_actions += 1
			check(Data.SHOP.has(Data.ACTIONS[id]["achat"]) and Data.SHOP[Data.ACTIONS[id]["achat"]]["action"] == id, "action %s : liée à un achat du magasin" % id)
	check(bought_actions == Data.SHOP.size() and Data.SHOP_ORDER.size() == Data.SHOP.size(), "chaque achat apporte une activité")
	var prices_ok := true
	for i in range(1, Data.SHOP_ORDER.size()):
		prices_ok = prices_ok and Data.SHOP[Data.SHOP_ORDER[i]]["prix"] > Data.SHOP[Data.SHOP_ORDER[i - 1]]["prix"]
	check(prices_ok, "achats rangés du moins cher au plus cher")
	check(Data.available_skills(p) == ["physique", "creativite", "charisme", "organisation", "humour"], "au départ : 5 compétences à entraîner")
	check(not Data.is_available("lire", p) and Data.is_available("sport", p), "lire demande le coin lecture")
	check(not "lire" in Objectives.candidates(p).filter(func(o): return o["type"] == "mots").map(func(o): return o["action"]), "pas d'objectif sur une activité pas encore achetée")
	check(not "logique" in Objectives.candidates(p).filter(func(o): return o["type"] == "competence").map(func(o): return o["skill"]), "pas d'objectif sur une compétence pas encore débloquée")
	check(Shop.next_item(p) == "lecture" and Shop.missing(p, "lecture") == 40, "premier achat conseillé : le coin lecture (40 pièces)")
	check(not Shop.can_buy(p, "lecture") and not Shop.buy(p, "lecture") and p["money"] == 0, "pas d'achat sans assez de pièces")
	# Objectif « acheter »
	var buy_offer: Array = Objectives.candidates(p).filter(func(o): return o["type"] == "achat")
	check(buy_offer.size() == 1 and buy_offer[0]["item"] == "lecture", "objectif proposé : acheter le coin lecture")
	Objectives.choose(p, buy_offer[0])
	p["money"] = 20
	check(is_equal_approx(Objectives.fraction(p), 0.5) and not Objectives.is_done(p), "objectif achat : barre à la moitié avec 20 pièces sur 40")
	p["money"] = 45
	check(Shop.can_buy(p, "lecture") and Shop.buy(p, "lecture"), "achat possible avec assez de pièces")
	check(p["money"] == 5 and Shop.owns(p, "lecture"), "les pièces sont dépensées, l'achat est gardé")
	check(Objectives.is_done(p), "objectif achat atteint")
	Objectives.claim(p)
	check(not Shop.buy(p, "lecture") and p["money"] == 5, "on n'achète pas deux fois la même chose")
	check(Data.is_available("lire", p) and "logique" in Data.available_skills(p), "le coin lecture débloque « lire » et la logique")
	check("lire" in Objectives.candidates(p).filter(func(o): return o["type"] == "mots").map(func(o): return o["action"]), "objectif de mots possible sur la nouvelle activité")
	check(Shop.next_item(p) == "jeux", "achat suivant conseillé : la table de jeux")
	check(Data.skill_help("logique", p).contains("lire un livre") and not Data.skill_help("logique", p).contains("jeu de société"), "conseil : seulement les activités possédées")
	p["money"] = 1000
	for id in Data.SHOP_ORDER:
		Shop.buy(p, id)
	check(Shop.next_item(p) == "" and Data.available_skills(p).size() == Data.SKILLS.size(), "tout acheté : les 10 compétences sont ouvertes")
	check(not "achat" in Objectives.candidates(p).map(func(o): return o["type"]), "plus d'objectif d'achat quand tout est acheté")
	check(Shop.clean(["chat", "inconnu", "chat", "lecture"]) == ["lecture", "chat"] and Shop.clean("x") == [], "liste d'achats nettoyée (inconnus, doublons)")
	for s in Data.SKILLS:
		check(not Data.shop_items_for_skill(s).is_empty() or s in ["physique", "creativite", "charisme", "organisation", "humour"], "compétence %s : une activité l'entraîne" % s)


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


func _test_new_careers() -> void:
	print("Carrières : les 7 métiers")
	check(Data.CAREER_ORDER.size() == 7 and Data.CAREERS.size() == 7, "7 carrières")
	for c in Data.CAREER_ORDER:
		check(Data.CAREERS.has(c), "carrière %s : dans la liste" % c)
		var info: Dictionary = Data.CAREERS[c]
		check(FileAccess.file_exists("res://icons/%s.png" % info["icone"]), "carrière %s : pictogramme présent" % c)
		var skills_ok := true
		for s in info["mission_skills"]:
			skills_ok = skills_ok and Data.SKILLS.has(s)
		var rising := true
		var previous := {}
		for t in info["tiers"]:
			for s in t["req"]:
				skills_ok = skills_ok and Data.SKILLS.has(s) and int(t["req"][s]) <= Data.SKILL_MAX and info["mission_skills"].has(s)
				rising = rising and int(t["req"][s]) > int(previous.get(s, 0))
			for s in previous:
				rising = rising and t["req"].has(s)
			previous = t["req"]
		check(skills_ok, "carrière %s : compétences connues, entraînées par ses missions" % c)
		check(rising and info["tiers"][0]["req"].is_empty(), "carrière %s : exigences de plus en plus hautes" % c)
		check(Data.missions_for(c, 1).size() == 3 and Data.missions_for(c, 2).size() == 4 and Data.missions_for(c, 5).size() == 5, "carrière %s : 3 missions au départ, 5 en tout" % c)
	var ids := {}
	var texts_ok := true
	for m in Data.MISSIONS:
		ids[m["id"]] = true
		texts_ok = texts_ok and Data.CAREERS.has(m["career"]) and m["questions"].size() == 2
		for q in m["questions"]:
			texts_ok = texts_ok and q["choices"].size() == 3 and q["aide"] != ""
		for it in m["items"]:
			texts_ok = texts_ok and it[0].length() < it[1].length() and it[1].length() < it[2].length()
			for text in it:
				texts_ok = texts_ok and not text.contains("œ") and text == text.strip_edges()
	check(ids.size() == Data.MISSIONS.size() and Data.MISSIONS.size() == 35, "35 missions, toutes avec un nom différent")
	check(texts_ok, "missions : 2 questions à 3 choix, textes de plus en plus longs, sans « œ »")
	# Une compétence qui ne vient que du travail se voit quand même.
	var p := _profile()
	check(not "patience" in Data.visible_skills(p), "sans travail ni achat : la patience n'est pas montrée")
	Progression.choose_career(p, "nature")
	check("patience" in Data.visible_skills(p) and "douceur" in Data.visible_skills(p), "vie dans la nature : patience et douceur sont montrées")
	check(not "patience" in Data.available_skills(p), "mais pas d'objectif dessus tant qu'aucune activité ne l'entraîne")
	check(Data.skill_help("patience", p).contains("missions de travail") and Data.skill_help("patience", p).contains("terrasse"), "conseil : les missions, et la terrasse au magasin")
	p["skills_xp"]["physique"] = Data.xp_for_level(2)
	p["skills_xp"]["patience"] = Data.xp_for_level(1)
	var promoted := false
	for i in Data.MISSIONS_PER_TIER:
		promoted = Progression.complete_mission(p)
	check(promoted and Progression.current_tier(p) == 2 and Progression.salary(p) == 35, "vie dans la nature : palier 2 après 3 missions")
	Progression.choose_career(p, "sportif")
	check("patience" in Data.visible_skills(p), "une compétence déjà commencée reste visible après un changement de travail")


func _test_dreams() -> void:
	print("Objectif de vie (« Mon rêve »)")
	var p := _profile()
	p["etoiles"] = 0
	p["achats"] = []
	check(not Dreams.has_current(p) and Dreams.steps(p).is_empty() and Dreams.fraction(p) == 0.0, "au départ : pas de rêve")
	check(Data.DREAM_ORDER.size() == Data.DREAMS.size(), "tous les rêves sont proposés")
	var careers_covered := {}
	for d in Data.DREAM_ORDER:
		var career: String = Data.DREAMS[d]["career"]
		check(career == "" or Data.CAREERS.has(career), "rêve %s : carrière connue" % d)
		check(FileAccess.file_exists("res://icons/%s.png" % Data.dream_icon(d)), "rêve %s : pictogramme présent" % d)
		careers_covered[career] = true
	check(careers_covered.size() == Data.CAREERS.size() + 1, "un rêve par carrière, plus la maison")
	check(not Dreams.choose(p, "inconnu") and not Dreams.has_current(p), "rêve inconnu refusé")
	check(not Dreams.choose(p, "sportif") and Dreams.current(p) == "sportif", "premier choix : ce n'est pas un changement")
	check(Dreams.steps(p).size() == 5 and Dreams.steps_done(p) == 0, "rêve de métier : 5 étapes")
	check(Dreams.next_step(p) == "Choisir le travail : Sportif" and Dreams.advice(p).contains("Travail"), "première étape : choisir le travail")
	# Les objectifs qui rapprochent du rêve sont signalés
	p["objectifs_finis"] = 2
	p["objectifs_choisis"] = 2
	var helping := Objectives.candidates(p).filter(func(o): return o["reve"]).map(func(o): return o["type"])
	check(helping == ["metier"], "sans travail : l'objectif « choisir un métier » aide le rêve")
	check(Objectives.candidates(p).filter(func(o): return o["type"] == "metier")[0]["aide"].contains("Sportif"), "l'aide cite le métier du rêve")
	Progression.choose_career(p, "artisan")
	check(Dreams.steps_done(p) == 0 and Dreams.advice(p).contains("palier 2"), "autre travail : il faut le palier 2 avant de changer")
	helping = Objectives.candidates(p).filter(func(o): return o["reve"]).map(func(o): return o["type"])
	check("missions" in helping and "palier" in helping and not "competence" in helping, "les missions de l'autre travail aident à pouvoir changer")
	p["career"]["tiers"]["artisan"] = 2
	Progression.choose_career(p, "sportif")
	check(Dreams.steps_done(p) == 1 and is_equal_approx(Dreams.fraction(p), 0.2), "travail du rêve choisi : 1 étape sur 5")
	var skills_help: Array = Objectives.candidates(p).filter(func(o): return o["reve"] and o["type"] == "competence").map(func(o): return o["skill"])
	check(skills_help == ["physique"], "la compétence demandée au palier suivant aide le rêve")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var always := true
	for i in 30:
		var offers := Objectives.offers(p, rng)
		var kinds := {}
		for o in offers:
			kinds[o["type"]] = true
		always = always and offers.size() == 3 and kinds.size() == 3 and offers.any(func(o): return o["reve"])
	check(always, "toujours une proposition pour le rêve, et 3 types différents")
	p["career"]["tiers"]["sportif"] = 4
	check(Dreams.steps_done(p) == 4 and Dreams.next_step(p) == "Devenir champion" and not Dreams.is_done(p), "palier 4 : il reste à devenir champion")
	check(Dreams.claim(p).is_empty(), "pas de récompense avant la fin")
	check(Recap.dream_line(p) == "Rêve : devenir champion, 4 étape(s) sur 5", "ligne du récapitulatif en cours de route")
	p["career"]["tiers"]["sportif"] = 5
	check(Dreams.is_done(p) and Dreams.to_celebrate(p) and Dreams.next_step(p) == "" and Dreams.advice(p) == "", "palier 5 : rêve réalisé")
	var reward := Dreams.claim(p)
	check(reward.get("pieces", 0) == Data.DREAM_REWARD_PIECES and p["etoiles"] == Data.DREAM_REWARD_STARS, "récompense : pièces et étoiles")
	check(not Dreams.to_celebrate(p) and Dreams.claim(p).is_empty() and Dreams.achieved(p) == ["sportif"], "le rêve n'est fêté qu'une fois")
	check(Objectives.candidates(p).filter(func(o): return o["reve"]).is_empty(), "rêve réalisé : plus d'objectif signalé")
	# Un nouveau rêve après le premier
	check(not Dreams.choose(p, "maison") and p["reve"]["changements"] == 0, "nouveau rêve après un rêve réalisé : pas compté comme un changement")
	check(Dreams.steps(p).size() == Data.SHOP_ORDER.size() and Dreams.advice(p).contains("Magasin"), "rêve « maison » : une étape par achat")
	p["money"] = 45
	Shop.buy(p, "lecture")
	check(Dreams.steps_done(p) == 1 and Dreams.next_step(p) == "Acheter : table de jeux", "un achat = une étape")
	check("achat" in Objectives.candidates(p).filter(func(o): return o["reve"]).map(func(o): return o["type"]), "rêve « maison » : l'objectif d'achat est signalé")
	check(Dreams.choose(p, "chanteur") and p["reve"]["changements"] == 1, "changer de rêve en cours de route est compté")
	check(Recap.dream_line(p).contains("déjà réalisé : devenir champion") and Recap.dream_line(p).contains("changé 1 fois"), "récapitulatif : rêve réalisé et changement notés")
	Dreams.choose(p, "sportif")
	check(not Dreams.to_celebrate(p) and Dreams.is_done(p), "revenir à un rêve déjà réalisé ne le fête pas deux fois")
	# Sauvegardes
	var cleaned := Dreams.clean({"id": "licorne", "changements": 2.0, "realises": ["sportif", "sportif", "x"], "fete": true})
	check(cleaned == {"id": "", "fete": false, "changements": 2, "realises": ["sportif"]}, "état relu d'une sauvegarde : remis en ordre")
	check(Dreams.clean(null) == Dreams.new_state() and Dreams.clean({"id": "maison"})["id"] == "maison", "sauvegarde sans rêve : état neuf")
	check(Recap.session_lines({"reves_realises": ["sportif"], "reves_changes": 1}).filter(func(l): return l.to_lower().contains("rêve")).size() == 2, "séance : rêve réalisé et changement dans le récapitulatif")


func _test_garden() -> void:
	print("Jardin : ressources et constructions")
	for res in Data.RESOURCE_ORDER:
		var info: Dictionary = Data.RESOURCES[res]
		check(Data.ACTIONS.has(info["action"]) and Data.ACTIONS[info["action"]].get("recolte", "") == res, "ressource %s : une action pour la récolter" % res)
		check(Data.LEXIQUE.has(info["action"]), "ressource %s : la récolte se joue en série de mots" % res)
	check(Data.RESOURCE_ORDER.size() == Data.RESOURCES.size() and Data.CONSTRUCTION_ORDER.size() == Data.CONSTRUCTIONS.size(), "listes ordonnées complètes")
	for id in Data.CONSTRUCTION_ORDER:
		var item: Dictionary = Data.CONSTRUCTIONS[id]
		var ok: bool = Data.ACTIONS.has(item["action"]) and Data.ACTIONS[item["action"]].get("construction", "") == id and not item["cout"].is_empty()
		for res in item["cout"]:
			ok = ok and Data.RESOURCES.has(res) and int(item["cout"][res]) > 0
		for s in item["competences"]:
			ok = ok and Data.SKILLS.has(s)
		check(ok, "construction %s bien formée" % id)
	check(Data.resource_text("bois", 1) == "1 bûche" and Data.resource_text("bois", 6) == "6 bûches" and Data.resource_text("pierre", 0) == "0 pierre", "accord : 1 bûche, 6 bûches")
	check(Build.cost_text("barbecue") == "6 bûches et 8 pierres", "coût écrit en clair")

	var p := _profile()
	check(Build.stock(p, "bois") == 0 and not Build.can_build(p, "banc"), "profil sans réserve : rien à construire")
	check(not Data.is_available("repos", p) and Data.is_available("couper", p) and Data.is_available("pierres", p), "récolter est possible tout de suite, le banc non")
	check(Build.add(p, "bois", 4) == 4 and Build.add(p, "bois", -3) == 4, "la réserve ne baisse pas avec une récolte")
	check(Build.missing_resources(p, "banc") == {"bois": 2} and is_equal_approx(Build.fraction(p, "banc"), 4.0 / 6.0), "il manque 2 bûches pour le banc")
	check(Build.advice(p, "banc") == "Il te faut encore 2 bûches.", "conseil : ce qu'il manque")
	check(not Build.build(p, "banc") and Build.stock(p, "bois") == 4, "pas assez de bois : rien n'est dépensé")
	Build.add(p, "bois", 3)
	check(Build.can_build(p, "banc") and Build.advice(p, "banc") == "", "assez de bois : le banc est possible")
	check(Build.build(p, "banc") and Build.stock(p, "bois") == 1 and Build.owns(p, "banc"), "construire dépense les ressources")
	check(not Build.build(p, "banc") and Build.stock(p, "bois") == 1, "on ne construit pas deux fois")
	check(Data.is_available("repos", p) and Build.next_item(p) == "fontaine", "le banc ouvre son activité, la fontaine est la suivante")
	# Compétences demandées
	Build.add(p, "pierre", 10)
	check(not Build.can_build(p, "fontaine") and Build.missing_skills(p, "fontaine") == {"physique": 2}, "la fontaine demande le niveau 2 en physique")
	check(Build.advice(p, "fontaine") == "Il te faut physique au niveau 2.", "conseil : la compétence qui manque")
	p["skills_xp"]["physique"] = 60.0
	check(Build.can_build(p, "fontaine") and Build.build(p, "fontaine") and Build.stock(p, "pierre") == 0, "niveau atteint : fontaine construite")
	check(not Build.build(p, "inconnu"), "construction inconnue refusée")
	# Sauvegardes abîmées
	check(Build.clean_stock({"bois": 3.0, "pierre": -2, "or": 9}) == {"bois": 3, "pierre": 0}, "réserve nettoyée")
	check(Build.clean_stock("x") == {"bois": 0, "pierre": 0}, "réserve illisible remise à zéro")
	check(Build.clean(["fontaine", "x", "banc", "banc"]) == ["banc", "fontaine"] and Build.clean(null) == [], "constructions nettoyées")

	# Objectifs du jardin
	var o := _profile()
	o["objectif"] = {}
	o["objectifs_finis"] = 0
	o["objectifs_choisis"] = 0
	o["etoiles"] = 0
	var early := Objectives.candidates(o).map(func(c): return c["type"])
	check(not "recolte" in early and not "construction" in early, "pas d'objectif jardin avant le premier objectif réussi")
	o["objectifs_finis"] = 1
	var garden := Objectives.candidates(o).filter(func(c): return c["type"] in ["recolte", "construction"])
	check(garden.size() == 2 and garden[0]["res"] == "bois" and garden[0]["target"] == 6 and garden[1]["item"] == "banc", "ensuite : récolter du bois (pour le banc) et construire le banc")
	Objectives.choose(o, garden[0])
	check(not Objectives.notify(o, "recolte", {"res": "pierre", "amount": 3}), "une autre ressource ne compte pas")
	Objectives.notify(o, "recolte", {"res": "bois", "amount": 3})
	check(is_equal_approx(Objectives.fraction(o), 0.5) and Objectives.progress_text(o) == "3 / 6 bûches", "récolte à la moitié")
	check(Objectives.notify(o, "recolte", {"res": "bois", "amount": 3}) and Objectives.is_done(o), "récolte terminée")
	Objectives.claim(o)
	Objectives.choose(o, garden[1])
	Build.add(o, "bois", 6)
	check(not Objectives.is_done(o) and is_equal_approx(Objectives.fraction(o), 0.95), "ressources réunies : il reste à construire")
	Build.build(o, "banc")
	check(Objectives.is_done(o), "objectif « construire » atteint")
	Objectives.claim(o)
	var after := Objectives.candidates(o).filter(func(c): return c["type"] in ["recolte", "construction"])
	check(after.size() == 2 and after[0]["res"] == "pierre" and after[1]["item"] == "fontaine", "après le banc : des pierres pour la fontaine")
	o["constructions"] = Data.CONSTRUCTION_ORDER.duplicate()
	var end := Objectives.candidates(o).filter(func(c): return c["type"] in ["recolte", "construction"])
	check(end.size() == 2 and end.all(func(c): return c["type"] == "recolte"), "tout est construit : on peut encore récolter")
	Objectives.choose(o, {"type": "soins", "target": 1, "label": "x", "pieces": 5})
	check(Objectives.notify(o, "action", {"action": "fontaine"}), "se laver à la fontaine compte comme un soin")

	# Espace de l'adulte
	var r := _profile()
	check(Recap.garden_line(r).begins_with("Jardin : 0 bûche et 0 pierre en réserve") and Recap.garden_line(r).ends_with("rien de construit pour l'instant"), "récapitulatif : jardin vide")
	r["ressources"] = {"bois": 7, "pierre": 3}
	r["constructions"] = ["banc"]
	check(Recap.garden_line(r).contains("7 bûches et 3 pierres") and Recap.garden_line(r).ends_with("construit : banc de jardin (1 sur 3)"), "récapitulatif : réserve et constructions")
	var lines := Recap.session_lines({"recoltes": {"bois": 5, "pierre": 0}, "constructions": ["banc", "x"]})
	check("Récolte dans le jardin : 5 bûches" in lines and "Construit dans le jardin : banc de jardin" in lines, "séance : récolte et construction dans le récapitulatif")
	check(Recap.session_lines({}).filter(func(l): return l.contains("jardin")).is_empty(), "séance d'une ancienne version : pas de ligne jardin")


func _test_family_graphics() -> void:
	print("Famille : pictogrammes prêts (version 2.4)")
	for name in ["couple", "famille", "bebe", "biberon", "fleurs", "jouet", "coeur"]:
		check(FileAccess.file_exists("res://icons/%s.png" % name), "pictogramme de la famille prêt : %s" % name)


func _test_family() -> void:
	print("Famille : rencontrer, vivre ensemble, les enfants")
	var p := _profile()
	p["appearance"] = Data.complete_appearance({})
	p["objectifs_finis"] = 3
	check(Family.stage(p) == "seul" and not Family.has_partner(p) and Family.children(p).is_empty(), "au départ : seul (le profil est complété tout seul)")
	check(not Family.can_meet(p) and Family.advice(p).contains("charisme"), "il faut du charisme niveau 1 pour rencontrer quelqu'un")
	check(not Data.is_available("fleurs", p) and not Data.is_available("bercer", p), "pas d'activité en couple ni de bébé sans famille")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var people := Family.proposals(rng)
	var names := {}
	for person in people:
		names[person["nom"]] = true
	check(people.size() == 4 and names.size() == 4, "quatre personnes, quatre prénoms différents")
	check(people.map(func(q): return q["genre"]) == [0, 1, 0, 1] and people.all(func(q): return q["apparence"]["body"] == q["genre"]), "deux femmes et deux hommes : c'est l'enfant qui choisit")
	check(people.all(func(q): return q["genre"] == 1 or q["apparence"].get("beard", 0) == 0), "pas de barbe pour les femmes")
	check(not Family.meet(p, people[0]), "rencontre refusée sans charisme")
	check(not Objectives.candidates(p).any(func(o): return o["type"] == "rencontre"), "pas d'objectif « rencontrer » sans charisme")
	p["skills_xp"]["charisme"] = float(Data.xp_for_level(1))
	check(Family.can_meet(p) and Objectives.candidates(p).any(func(o): return o["type"] == "rencontre"), "avec le charisme : objectif « rencontrer quelqu'un »")
	check(Family.meet(p, people[1]) and Family.partner_name(p) == people[1]["nom"] and Family.complicity(p) == 10, "rencontre : la complicité commence à 10")
	check(not Family.meet(p, people[2]), "une seule personne à la fois")
	check(Family.stage(p) == "rencontre" and Data.is_available("fleurs", p) and not Data.is_available("bercer", p), "les moments à deux sont possibles")
	check(Objectives.candidates(p).any(func(o): return o["type"] == "famille"), "objectif « passer du temps en famille »")
	check(not Family.can_move_in(p) and not Family.move_in(p), "pas encore assez complices pour vivre ensemble")
	check(Family.add_complicity(p, 500) == 100, "la complicité ne dépasse pas 100 %")
	p["famille"]["complicite"] = Data.FAMILY_MOVE_IN
	check(Family.can_move_in(p) and Family.has_news(p) and Family.advice(p).contains("vivre ensemble"), "très complices : « Ma famille » le signale")
	check(Family.move_in(p) and Family.is_together(p) and not Family.move_in(p), "ils vivent ensemble")
	check(Family.status_text(p) == "Avec " + people[1]["nom"], "le cadre « Ma famille » montre le conjoint")
	check(not Family.can_have_baby(p) and Family.baby_blocker(p).contains("organisation"), "il faut de l'organisation pour accueillir un bébé")
	Family.decline_children(p)
	p["famille"]["vu"] = true
	check(Family.declined(p) and not Family.has_news(p) and Family.advice(p).contains("canapé"), "« pas d'enfant » : un choix respecté")
	p["skills_xp"]["organisation"] = float(Data.xp_for_level(2))
	var baby_names := Family.baby_names(rng)
	check(baby_names.size() == 4 and baby_names.filter(func(c): return c["genre"] == 0).size() == 2, "quatre prénoms : deux filles, deux garçons")
	var baby := Family.have_baby(p, baby_names[2], rng)
	check(not baby.is_empty() and baby["nom"] == baby_names[2]["nom"] and baby["age"] == "bebe" and not Family.declined(p), "changement d'avis : le bébé arrive")
	var parents := [p["appearance"]["skin"], Family.partner(p)["apparence"]["skin"]]
	check(baby["apparence"]["skin"] in parents, "le bébé a la peau de l'un de ses parents")
	check(Family.has_baby(p) and Data.is_available("bercer", p) and not Data.is_available("jouer_enfant", p), "on s'occupe du bébé au berceau")
	check(Family.have_baby(p, baby_names[0], rng).is_empty() and Family.baby_blocker(p).contains("un bébé à la fois"), "un bébé à la fois")
	for i in Data.FAMILY_BABY_CARES - 1:
		check(not Family.care_baby(p), "soin %d : le bébé est encore petit" % (i + 1))
	check(Family.care_baby(p) and Family.has_child(p) and not Family.has_baby(p), "après %d soins, le bébé a grandi" % Data.FAMILY_BABY_CARES)
	check(Data.is_available("jouer_enfant", p) and Data.is_available("histoire", p), "jouer et raconter une histoire à son enfant")
	Dreams.choose(p, "famille")
	check(Dreams.current(p) == "famille" and Dreams.steps_done(p) == 5 and Dreams.is_done(p), "rêve « Fonder une famille » : les 5 étapes faites")
	check(Recap.family_line(p).contains(Family.partner_name(p)) and Recap.family_line(p).contains(baby["nom"]), "l'adulte voit la famille en une ligne")
	Family.have_baby(p, baby_names[1], rng)
	check(Family.children(p).size() == Data.FAMILY_MAX_CHILDREN and Family.baby_blocker(p).contains("complet"), "au plus deux enfants")
	# Sauvegardes : anciennes versions et fichiers abîmés
	check(Family.clean(null) == Family.new_state() and Family.clean({"enfants": [{"nom": "Zoé"}]})["enfants"].is_empty(), "sauvegarde abîmée : état vide, pas d'enfant sans couple")
	var cleaned := Family.clean(p["famille"])
	check(cleaned["partenaire"]["nom"] == Family.partner_name(p) and cleaned["enfants"].size() == 2 and cleaned["ensemble"], "la famille est relue telle quelle")
	var messy := Family.clean({"partenaire": {"nom": "Lina", "genre": 9}, "complicite": 900, "ensemble": true, "choix_enfant": "non",
		"enfants": [{"nom": "A"}, {"nom": "B", "age": "enfant"}, {"nom": "C"}]})
	check(messy["complicite"] == 100 and messy["partenaire"]["genre"] == 1 and messy["enfants"].size() == 2 and messy["choix_enfant"] == "", "valeurs remises en ordre")
	var counted := {"type": "famille", "target": 2, "count": 0}
	p["objectif"] = counted
	Objectives.notify(p, "action", {"action": "calin"})
	Objectives.notify(p, "action", {"action": "dormir"})
	check(int(p["objectif"]["count"]) == 1, "seules les activités en famille comptent pour l'objectif")
	for id in Data.ACTIONS:
		if Data.ACTIONS[id].has("famille"):
			check(Data.ACTIONS[id]["famille"] in Data.FAMILY_ACTIONS and id in Data.FAMILY_ACTIONS[Data.ACTIONS[id]["famille"]], "activité %s : rangée avec la famille" % id)


func _test_recap_speeds() -> void:
	print("Récapitulatif : vitesse par niveau et fautes")
	var s := {"caracteres": 100, "caracteres_tentes": 150, "vitesse_niveaux": {"1": {"caracteres": 60, "sec": 30.0}}}
	check(Recap.attempted_chars(s) == 150, "taux de fautes calculé sur les caractères tentés")
	check(Recap.attempted_chars({"caracteres": 80}) == 80, "ancienne séance : on reprend les caractères réussis")
	check(is_equal_approx(Recap.level_cpm(s, "1"), 120.0) and Recap.level_cpm(s, "2") == 0.0, "vitesse en caractères/min par niveau de texte")
	check(Recap.session_lines(s).any(func(l): return l.begins_with("Vitesse par niveau de texte") and l.contains("niveau 1 : 120")), "la séance montre la vitesse par niveau")
	check(not Recap.session_lines({}).any(func(l): return l.begins_with("Vitesse par niveau")), "ancienne séance : pas de ligne de vitesse par niveau")
	# Passage au niveau 2 (textes plus longs, donc plus lents) : ce n'est pas une baisse.
	var sessions := []
	for v in [100.0, 110.0, 105.0]:
		sessions.append({"frappes_ok": 1, "caracteres": int(v), "temps_frappe_sec": 60.0, "vitesse_niveaux": {"1": {"caracteres": int(v), "sec": 60.0}}})
	for v in [50.0, 55.0]:
		sessions.append({"frappes_ok": 1, "caracteres": int(v), "temps_frappe_sec": 60.0, "vitesse_niveaux": {"2": {"caracteres": int(v), "sec": 60.0}}})
	var words := Recap.keywords({"sessions": sessions})
	check(not words.has("Vitesse en baisse") and words.has("Vitesse stable"), "changer de niveau de texte ne passe pas pour une baisse")


func _test_ergo_access() -> void:
	print("Accès ergo et prénoms")
	check(ErgoAccess.check({}, "Ergo ") and not ErgoAccess.check({}, "erg"), "sans mot choisi : « ergo » ouvre l'espace")
	var a := ErgoAccess.make("Cabinet2026")
	check(ErgoAccess.is_set(a) and not JSON.stringify(a).to_lower().contains("cabinet"), "mot gardé haché, pas en clair")
	check(ErgoAccess.check(a, " cabinet2026") and not ErgoAccess.check(a, "ergo") and not ErgoAccess.check(a, "cabinet"), "mot choisi : seul lui ouvre l'espace")
	var b := ErgoAccess.make("Cabinet2026")
	check(a["sel"] != b["sel"] and a["hache"] != b["hache"], "un sel différent à chaque mot")
	check(ErgoAccess.refusal("abc", "abc") != "" and ErgoAccess.refusal("ergo", "ergo") != "" and ErgoAccess.refusal("cabinet", "cabinat") != "", "mot trop court, « ergo » ou mal recopié : refusé")
	check(ErgoAccess.refusal("Cabinet", "cabinet ") == "", "mot valable accepté")
	check(ErgoAccess.display_name("léo", true) == "L." and ErgoAccess.display_name("Léo", false) == "Léo", "prénom caché : seulement l'initiale")
	check(ErgoAccess.is_duplicate(" LÉO ", ["Camille", "Leo"]) and not ErgoAccess.is_duplicate("Léon", ["Léo"]), "prénom en double reconnu malgré majuscules et accents")


func _test_quality_retry() -> void:
	print("Graphismes allégés puis retentés")
	var q := {"qualite": 2, "qualite_voulue": -1, "essais_remontee": 0}
	GameScript.quality_lowered(q)
	GameScript.quality_lowered(q)
	check(q["qualite"] == 0 and q["qualite_voulue"] == 2, "allègement automatique : le niveau choisi est retenu")
	check(GameScript.quality_retry(q) and q["qualite"] == 1, "partie suivante : le niveau au-dessus est retenté")
	check(GameScript.quality_retry(q) and q["qualite"] == 2, "puis encore au-dessus")
	GameScript.quality_lowered(q)
	check(not GameScript.quality_retry(q) and q["qualite"] == 1, "après %d essais, on en reste là" % GameScript.QUALITY_RETRIES)
	check(not GameScript.quality_retry({"qualite": 0, "qualite_voulue": -1, "essais_remontee": 0}), "« Léger » choisi à la main : jamais remonté")


func _test_agreement() -> void:
	print("Accords au féminin")
	check(Data.need_alert("sommeil", {"body": 0}) == "est très fatiguée !" and Data.need_alert("sommeil", {"body": 1}) == "est très fatigué !", "alerte de fatigue accordée au corps choisi")
	check(Data.need_alert("social", {"body": 0}) == "se sent seule !" and Data.need_alert("social", {"body": 1}) == "se sent seul !", "alerte de solitude accordée")
	check(Data.need_alert("faim", {"body": 0}) == Data.need_alert("faim", {"body": 1}), "alerte sans accord : la même pour tous")
	var gendered := []
	for m in Data.MISSIONS:
		for t in [m["consigne"]] + m["questions"].map(func(q): return q["aide"]):
			for w in ["Tu es le dernier", "Tu es la dernière", "tu es prêt ", "Tu es seul "]:
				if t.contains(w):
					gendered.append(m["id"])
	check(gendered.is_empty(), "consignes des missions sans accord masculin pour l'enfant %s" % str(gendered))
	var woman := {"appearance": {"body": 0}}
	var man := {"appearance": {"body": 1}}
	check(Data.career("sportif", woman)["label"] == "Sportive" and Data.career("sportif", woman)["tiers"][4]["title"] == "Championne", "métier accordé : sportive, championne")
	check(Data.career("sportif", man)["tiers"][4]["title"] == "Champion" and Data.CAREERS["sportif"]["tiers"][4]["title"] == "Champion", "corps « Homme » : masculin, les données ne changent pas")
	check(Data.career("scientifique", woman)["label"] == "Scientifique" and Data.career("ingenieur", woman)["tiers"][4]["title"] == "Grande inventrice", "accords des titres de paliers")
	check(Data.dream("sportif", woman)["label"] == "Devenir championne" and Data.dream("chanteur", woman)["label"] == Data.dream("chanteur", man)["label"], "rêve accordé (et inchangé s'il est déjà neutre)")
	check(Data.career("artisan", {})["label"] == "Artisan", "profil sans apparence : forme d'origine")
	var all_f := true
	for c in Data.CAREERS:
		for t in Data.CAREERS[c]["tiers"]:
			all_f = all_f and t.has("title_f")
	check(all_f, "chaque palier a sa forme au féminin")
