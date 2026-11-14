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
