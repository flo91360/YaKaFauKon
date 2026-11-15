extends SceneTree
## Test de jeu automatique (sans affichage) : on simule un enfant qui tape,
## puis on vérifie que le personnage se déplace, agit, et que les jauges bougent.
## Lancer : Godot --headless --path . --script res://tests/gameplay_test.gd

const GameScreen = preload("res://scripts/screens/game_screen.gd")
const DreamPanel = preload("res://scripts/ui/dream_panel.gd")
const Dreams = preload("res://scripts/core/dreams.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Objectives = preload("res://scripts/core/objectives.gd")
const Data = preload("res://scripts/core/data.gd")
const Shop = preload("res://scripts/core/shop.gd")
const Build = preload("res://scripts/core/build.gd")
const BuildPanel = preload("res://scripts/ui/build_panel.gd")

var _fails := 0
var _count := 0


func _initialize() -> void:
	_run()


func check(cond: bool, label: String) -> void:
	_count += 1
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  ÉCHEC ", label)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _wait_state(screen, state: String, max_seconds: float) -> bool:
	var t := 0.0
	while screen._state != state and t < max_seconds:
		await process_frame
		t += 1.0 / 60.0
		await create_timer(0.05).timeout
		t += 0.05
	return screen._state == state


func _object(screen, id: String):
	return screen.studio.furniture.filter(func(f): return f.object_id == id)[0]


func _run() -> void:
	await process_frame
	var game = root.get_node("Game")
	game.start_demo()
	var screen = GameScreen.new()
	root.add_child(screen)
	await process_frame
	var profile: Dictionary = game.profile

	print("Boucle d'action (toilettes)")
	profile["needs"]["toilettes"] = 20.0
	screen._start_typing(_object(screen, "toilettes"), "toilettes")
	check(screen.typing.is_open(), "le panneau de frappe s'ouvre")
	check(screen.typing.model_text == "toilettes", "texte modèle niveau 1")
	screen.typing._input.text = "toilete" # 2 fautes sur un mot seul
	screen.typing._submit()
	check(screen.typing.is_open() and screen._state == "typing", "trop de fautes : on peut corriger")
	screen.typing._input.text = "Toiletes" # 1 faute + majuscule : accepté
	screen.typing._submit()
	check(await _wait_state(screen, "walking", 3.0), "frappe acceptée : le personnage se déplace")
	check(await _wait_state(screen, "acting", 8.0), "le personnage arrive et agit")
	check(await _wait_state(screen, "idle", 20.0), "l'action se termine")
	check(profile["needs"]["toilettes"] > 90.0, "la jauge toilettes remonte (%.0f)" % profile["needs"]["toilettes"])
	check(game.session["taches_finies"] == 1, "tâche terminée comptée")
	check(game.session["frappes_ok"] == 1 and game.session["frappes_ratees"] == 1, "frappes réussies / ratées comptées")

	print("Activité en série de mots (miroir)")
	var xp_before: float = profile["skills_xp"]["charisme"]
	Objectives.choose(profile, {"type": "mots", "action": "miroir", "target": 3, "label": "test", "pieces": 12})
	screen._start_typing(_object(screen, "miroir"), "miroir")
	screen.typing._input.text = "miroir"
	screen.typing._submit()
	check(await _wait_state(screen, "series", 10.0), "le personnage va au miroir et la série commence")
	check(screen.typing.is_open() and screen.typing.series, "le panneau de série est ouvert")
	check(screen._series["words"].size() == Data.WORDS_PER_SERIES, "la série contient %d mots" % Data.WORDS_PER_SERIES)
	check(screen.character.anim == "talk", "le personnage est animé pendant l'activité")
	var all_in_field := true
	for w in screen._series["words"]:
		var found := false
		for list in Data.LEXIQUE["miroir"]:
			if w in list:
				found = true
		all_in_field = all_in_field and found
	check(all_in_field, "les mots viennent du champ lexical de l'activité")
	var xp_word: float = profile["skills_xp"]["charisme"]
	var first_word: String = screen.typing.model_text
	screen.typing._input.text = first_word
	screen.typing._submit()
	check(profile["skills_xp"]["charisme"] > xp_word, "un mot réussi fait monter la compétence tout de suite")
	check(Objectives.current(profile)["count"] == 1, "le mot compte pour l'objectif en cours")
	await _wait(1.3)
	check(screen._series["index"] == 1 and screen.typing.model_text != first_word, "le mot suivant s'affiche")
	for i in range(1, Data.WORDS_PER_SERIES):
		screen.typing._input.text = screen.typing.model_text
		screen.typing._submit()
		await _wait(1.3)
	check(await _wait_state(screen, "idle", 5.0), "la série se termine")
	check(profile["skills_xp"]["charisme"] > xp_before + 30.0, "le charisme progresse (%.0f XP)" % (profile["skills_xp"]["charisme"] - xp_before))
	check(game.session["series_finies"] == 1 and game.session["mots_ok"] == Data.WORDS_PER_SERIES, "série et mots comptés pour l'ergo")
	check(Objectives.is_done(profile), "objectif « taper 3 mots » atteint")
	var money_obj: int = profile["money"]
	screen._open_objectives()
	check(profile["money"] == money_obj + 12 and profile["etoiles"] == 1, "récompense de l'objectif : pièces et étoile")
	check(screen._overlay != null and screen._overlay.offers.size() == 3, "3 nouveaux objectifs proposés")
	screen._on_objective_chosen(screen._overlay.offers[0])
	check(Objectives.has_current(profile) and screen._overlay == null, "nouvel objectif choisi")

	print("Série arrêtée en cours")
	screen._start_typing(_object(screen, "tapis"), "sport")
	screen.typing._input.text = screen.typing.model_text
	screen.typing._submit()
	check(await _wait_state(screen, "series", 12.0), "série de sport commencée")
	check(screen.character.pose == "course" and screen.character.anim == "run", "le personnage court sur le tapis")
	screen.typing._input.text = screen.typing.model_text
	screen.typing._submit()
	await _wait(1.3)
	var physique: float = profile["skills_xp"]["physique"]
	screen.typing._close({"status": "cancel"})
	check(screen._state == "idle" and not screen.typing.is_open(), "bouton Arrêter : la série s'arrête")
	check(game.session["series_interrompues"] == 1, "série interrompue comptée pour l'ergo")
	check(profile["skills_xp"]["physique"] == physique and physique > 0.0, "les points déjà gagnés sont gardés")
	game.session["taches_abandonnees"] = 0

	print("Tutoriel")
	screen.start_tutorial()
	check(screen.tutorial != null and screen.tutorial.current_id() == "bienvenue", "le tutoriel démarre")
	screen.tutorial.advance()
	check(screen.tutorial.current_id() == "bouger", "étape : se déplacer")
	screen._state = "walking"
	screen._object = null
	screen._on_arrived()
	check(screen.tutorial.current_id() == "jauges", "se déplacer fait avancer le tutoriel")
	screen.tutorial.advance()
	check(screen.tutorial.current_id() == "objet" and screen.studio.get_object("lavabo")._marker.visible, "la flèche montre le lavabo")
	screen.tutorial._finish(true)
	check(screen.tutorial == null and profile["tuto_fait"], "le tutoriel peut être passé")
	screen._close_overlay()

	print("Guide et changement de look")
	screen._open_guide()
	check(screen._overlay != null and screen._overlay.objects.size() == screen.studio.furniture.size(), "le guide présente tous les objets")
	screen._close_overlay()
	screen._open_look()
	check(screen._overlay != null and screen._overlay.edit_mode, "le miroir ouvre le changement de look")
	screen._overlay.appearance["hair_style"] = 6
	screen._overlay._validate()
	check(profile["appearance"]["hair_style"] == 6 and screen._overlay == null, "nouveau look enregistré")

	print("Magasin : la maison s'agrandit")
	var base_objects: int = screen.studio.furniture.size()
	check(screen.studio.get_object("lecture") == null and screen.studio.get_object("potager") == null, "au départ : ni coin lecture ni potager utilisable")
	check(is_equal_approx(screen.studio.clamp_to_room(Vector3(6.5, 0, -1.5)).x, 4.6), "sans terrasse : on ne sort pas de la pièce")
	profile["money"] = 50
	screen._open_shop()
	check(screen._overlay != null and screen.paused, "le magasin s'ouvre (jeu en pause)")
	check(not screen._overlay.find_child("Acheter_lecture", true, false).disabled and screen._overlay.find_child("Acheter_jeux", true, false).disabled, "bouton Acheter actif seulement avec assez de pièces")
	screen._overlay.bought.emit("jeux")
	check(profile["money"] == 50 and not Shop.owns(profile, "jeux") and screen._overlay != null, "achat trop cher refusé")
	screen._overlay.bought.emit("lecture")
	check(profile["money"] == 10 and Shop.owns(profile, "lecture") and screen._overlay == null, "coin lecture acheté : 40 pièces dépensées")
	check(screen.studio.get_object("lecture") != null and screen.studio.furniture.size() == base_objects + 1, "le coin lecture apparaît dans la maison")
	check(game.session["achats"] == ["lecture"] and game.session["argent_depense"] == 40, "achat compté pour l'ergo")
	var logic_before: float = profile["skills_xp"]["logique"]
	screen._start_typing(_object(screen, "lecture"), "lire")
	screen.typing._input.text = screen.typing.model_text
	screen.typing._submit()
	check(await _wait_state(screen, "series", 12.0), "le personnage va lire : la série commence")
	check(screen.character.pose == "assis" and screen.character.anim == "sit_read", "il lit assis dans le fauteuil")
	screen.typing._input.text = screen.typing.model_text
	screen.typing._submit()
	await _wait(1.3)
	check(profile["skills_xp"]["logique"] > logic_before, "lire fait monter la logique")
	screen.typing._close({"status": "cancel"})
	game.session["series_interrompues"] = 1
	game.session["taches_abandonnees"] = 0
	profile["money"] = 1000
	for item in ["jeux", "guitare", "terrasse", "chat"]:
		screen._on_shop_bought(item)
	check(screen.studio.furniture.size() == base_objects + 5, "les 5 achats sont dans la maison")
	var bed = screen.studio.get_object("potager")
	check(bed != null and is_equal_approx(screen.studio.clamp_to_room(Vector3(6.5, 0, -1.5)).x, 6.5), "avec la terrasse : on peut marcher dehors")

	print("Jardin : récolter et construire")
	check(screen.studio.get_object("bois_jardin") != null and screen.studio.get_object("rochers") != null and screen.studio.get_object("chantier") != null, "le tas de bois, les rochers et le panneau « À construire » sont dans le jardin")
	check(screen.studio.get_object("banc") == null and not Data.is_available("repos", profile), "au départ : rien de construit")
	var on_lawn: Vector3 = screen.studio.clamp_to_room(Vector3(7.0, 0, 6.0))
	check(is_equal_approx(screen.studio.clamp_to_room(Vector3(7.0, 0, 2.0)).x, 7.0) and screen.studio._walkable(Vector2(on_lawn.x, on_lawn.z)) and on_lawn.z < 4.0, "on marche dans la cour, pas sur la pelouse")
	profile["jardin_vu"] = false
	check(screen.studio.view == "maison" and screen.hud.view_button.text.contains("Jardin"), "vue de la maison : le bouton propose le jardin")
	screen.hud.view_button.pressed.emit()
	check(screen.studio.view == "jardin" and profile["jardin_vu"] and screen.hud.view_button.text.contains("Maison"), "le bouton « Jardin » montre le jardin")
	screen.hud.view_button.pressed.emit()
	check(screen.studio.view == "maison", "le bouton « Maison » ramène à la maison")
	var wood_before := Build.stock(profile, "bois")
	screen._start_typing(_object(screen, "bois_jardin"), "couper")
	check(screen.studio.view == "jardin", "choisir le tas de bois montre le jardin")
	screen.typing._input.text = screen.typing.model_text
	screen.typing._submit()
	check(await _wait_state(screen, "series", 14.0), "le personnage va couper du bois : la série commence")
	check(screen.character.anim == "chop" and screen.studio.zone_of(screen.character.position) == "jardin", "il coupe du bois dans le jardin")
	check(not screen.studio.get_object("bois_jardin").get_meta("axe").visible, "il prend la hache du billot")
	for i in 2:
		screen.typing._input.text = screen.typing.model_text
		screen.typing._submit()
		await _wait(1.3)
	check(Build.stock(profile, "bois") == wood_before + 2 and game.session["recoltes"].get("bois", 0) == 2, "2 mots réussis : 2 bûches dans la réserve")
	check(screen.hud.build_button.find_children("*", "Label", true, false).any(func(l): return l.text == str(wood_before + 2)), "la réserve est affichée en bas de l'écran")
	screen.typing._close({"status": "cancel"})
	check(Build.stock(profile, "bois") == wood_before + 2 and screen.studio.get_object("bois_jardin").get_meta("axe").visible, "série arrêtée : les bûches sont gardées, la hache est rangée")
	var rocks = _object(screen, "rochers")
	screen._object = rocks
	screen._action_id = "pierres"
	screen._state = "walking"
	screen.character.position = rocks.use_point
	screen._on_arrived()
	check(screen._state == "series" and screen.character.anim == "pick", "ramasser des pierres : série de mots et animation")
	while screen._state == "series":
		screen.typing._input.text = screen.typing.model_text
		screen.typing._submit()
		await _wait(1.3)
	check(Build.stock(profile, "pierre") == Data.WORDS_PER_SERIES and game.session["series_finies"] >= 1, "série finie : %d pierres" % Data.WORDS_PER_SERIES)
	await _wait_state(screen, "idle", 6.0)
	# Construire
	screen._choose_object(_object(screen, "chantier"))
	check(screen._overlay is BuildPanel and screen.paused, "le panneau « À construire » ouvre l'écran Construire")
	check(screen._overlay.find_child("Construire_banc", true, false).disabled, "pas assez de bois : bouton « Pas encore »")
	screen._overlay.built.emit("banc")
	check(not Build.owns(profile, "banc") and screen._overlay != null, "construction refusée sans les ressources")
	screen._close_overlay()
	game.add_resource("bois", 6 - Build.stock(profile, "bois"))
	screen.hud.build_button.pressed.emit()
	check(screen._overlay is BuildPanel and not screen._overlay.find_child("Construire_banc", true, false).disabled and screen._overlay.find_child("Construire_fontaine", true, false).disabled, "6 bûches : le banc est possible, pas la fontaine")
	var before_build: int = screen.studio.furniture.size()
	screen._overlay.find_child("Construire_banc", true, false).pressed.emit()
	check(Build.owns(profile, "banc") and Build.stock(profile, "bois") == 0 and screen._overlay == null, "banc construit : 6 bûches dépensées")
	check(screen.studio.get_object("banc") != null and screen.studio.furniture.size() == before_build + 1 and screen.studio.view == "jardin", "le banc apparaît dans le jardin")
	check(game.session["constructions"] == ["banc"], "construction comptée pour l'ergo")
	var bench = _object(screen, "banc")
	screen._object = bench
	screen._action_id = "repos"
	screen._state = "walking"
	screen.character.position = bench.use_point
	screen._on_arrived()
	check(screen._state == "acting" and screen.character.pose == "assis" and screen.character.anim == "sit_rest", "il se repose assis sur le banc")
	await _wait_state(screen, "idle", 12.0)
	profile["skills_xp"]["physique"] = 200.0
	profile["skills_xp"]["creativite"] = 200.0
	profile["ressources"] = {"bois": 6, "pierre": 18}
	screen._on_built("fontaine")
	screen._on_built("barbecue")
	check(screen.studio.furniture.size() == before_build + 3 and Build.next_item(profile) == "" and Build.stock(profile, "pierre") == 0, "fontaine et barbecue construits : le jardin est complet")
	screen._open_build()
	check(screen._overlay.find_child("Construire_barbecue", true, false) == null, "écran Construire : tout est « déjà construit »")
	screen._overlay.find_child("AllerAuJardin", true, false).pressed.emit()
	check(screen._overlay == null and screen.studio.view == "jardin", "« Aller au jardin » ferme l'écran et montre le jardin")
	for pair in [["fontaine", "fontaine", "wash"], ["barbecue", "barbecue", "cook"]]:
		var built = _object(screen, pair[0])
		screen._object = built
		screen._action_id = pair[1]
		screen._state = "walking"
		screen.character.position = built.use_point
		screen._on_arrived()
		check(screen._state == "acting" and screen.character.anim == pair[2], "activité « %s » : animation" % Data.ACTIONS[pair[1]]["label"])
		await _wait_state(screen, "idle", 14.0)
	screen._set_view("maison")
	var reachable := true
	for f in screen.studio.furniture:
		for g in screen.studio.furniture:
			if f != g:
				var path: Array = screen.studio.compute_path(f.use_point, g.use_point, g)
				reachable = reachable and not path.is_empty() and path[-1] == g.use_point
	check(reachable, "un chemin existe entre tous les objets")
	var covered := true
	for id in Data.ACTIONS:
		var found := false
		for f in screen.studio.furniture:
			found = found or id in f.actions
		covered = covered and found
	check(covered, "chaque action a son objet dans la maison")
	for pair in [["jeux", "jeu", "sit_play"], ["guitare", "musique", "guitar"], ["potager", "jardiner", "garden"], ["chat", "animal", "pet"]]:
		var target = _object(screen, pair[0])
		screen._object = target
		screen._action_id = pair[1]
		screen._state = "walking"
		screen.character.position = target.use_point
		screen._on_arrived()
		check(screen._state == "series" and screen.character.anim == pair[2], "activité « %s » : série de mots et animation" % Data.ACTIONS[pair[1]]["label"])
		screen.typing._close({"status": "cancel"})
	check(screen.studio.get_object("guitare").get_meta("guitar").visible, "la guitare revient sur son pied après l'activité")
	game.session["series_interrompues"] = 1
	game.session["taches_abandonnees"] = 0
	screen._open_skills()
	check(screen._overlay != null, "le panneau des compétences s'ouvre avec les 10 compétences")
	screen._close_overlay()
	screen._open_shop()
	check(screen._overlay != null and screen._overlay.find_child("Acheter_chat", true, false) == null, "magasin : tout est « déjà à toi »")
	screen._close_overlay()

	print("Annulation et chronomètre")
	screen._start_typing(_object(screen, "lavabo"), "dents")
	screen.typing._close({"status": "cancel"})
	check(game.session["taches_abandonnees"] == 1, "abandon compté")
	profile["typing"]["baseline_cps"] = 50.0 # enfant très rapide : chrono très court
	profile["typing"]["ema_cps"] = 50.0
	profile["typing"]["since_timed"] = 10
	screen._start_typing(_object(screen, "lavabo"), "dents")
	check(screen.typing.timed, "le chronomètre apparaît après la mesure de vitesse")
	check(await _wait_state(screen, "idle", 10.0), "trop lent : l'action échoue")
	check(game.session["chronos_rates"] == 1, "chrono raté compté")

	print("Sommeil accéléré")
	profile["needs"]["sommeil"] = 10.0
	var start_minutes: float = profile["game_minutes"]
	screen._start_typing(_object(screen, "lit"), "dormir")
	screen.typing._input.text = screen.typing.model_text
	screen.typing._submit()
	check(await _wait_state(screen, "acting", 10.0), "le personnage se couche")
	check(screen.character.pose == "allonge", "pose allongée")
	check(await _wait_state(screen, "idle", 40.0), "le sommeil dure un peu puis se termine")
	check(profile["needs"]["sommeil"] > 95.0, "la jauge sommeil est pleine")
	check(profile["game_minutes"] - start_minutes >= 480.0, "8 heures de jeu sont passées")

	print("Jauges dans le rouge")
	check(game.session["rouge_sec"]["toilettes"] > 0.0, "temps dans le rouge mesuré")

	print("Carrière et mission")
	screen._open_career()
	check(screen._overlay != null and screen.paused, "le panneau travail s'ouvre (jeu en pause)")
	screen._on_career_chosen("artisan")
	check(profile["career"]["current"] == "artisan" and screen._overlay == null, "carrière artisan choisie")
	await _wait(4.5)
	check(not screen._mission_state.is_empty(), "une mission est proposée")
	screen._open_mission()
	var panel = screen._mission_panel
	check(panel != null, "le panneau de mission s'ouvre")
	var mission: Dictionary = screen._mission_state["data"]
	panel.state["step"] = "question"
	panel.refresh()
	for qi in mission["questions"].size():
		var q: Dictionary = mission["questions"][qi]
		var wrong: int = (q["good"] + 1) % q["choices"].size()
		panel._answer(q, wrong, Button.new(), [true])
		check(panel.state["q"] == qi, "mauvais choix : explication, on reste sur la question")
		await panel._answer(q, q["good"], Button.new(), [false])
	check(panel.state["step"] == "items", "après les choix : la liste à taper")
	var money_before: int = profile["money"]
	profile["typing"]["since_timed"] = 0
	profile["settings"]["chrono"] = "jamais"
	for i in mission["items"].size():
		var text := Progression.text_for(mission["items"][i], profile)
		screen._on_mission_typing_requested(text, "test")
		screen.typing._input.text = text
		screen.typing._submit()
		await _wait(1.0)
	await _wait(0.5)
	check(screen._mission_state.is_empty(), "mission terminée")
	check(profile["money"] == money_before + 20, "salaire versé (20 pièces au palier 1)")
	check(profile["career"]["missions"]["artisan"] == 1, "mission comptée pour la carrière")
	check(game.session["missions_reussies"] == 1, "mission réussie comptée pour l'ergo")
	check(game.session["choix_total"] == mission["questions"].size(), "choix comptés")
	screen._on_career_chosen("organisateur")
	check(profile["career"]["current"] == "artisan", "changement refusé au palier 1")

	print("Mon rêve : l'objectif de vie")
	check(profile["reve"]["id"] == "artisan", "le joueur de démonstration rêve de devenir maître artisan")
	screen.hud.dream_button.pressed.emit()
	check(screen._overlay is DreamPanel and screen.paused, "le bouton « Mon rêve » ouvre le panneau (jeu en pause)")
	check(screen._overlay.find_child("ChangerReve", true, false) != null, "le panneau montre les étapes du rêve")
	screen._overlay.find_child("ChangerReve", true, false).pressed.emit()
	await process_frame
	await process_frame
	check(screen._overlay.find_child("Reve_sportif", true, false) != null and screen._overlay.find_child("Reve_artisan", true, false).disabled, "les 8 rêves sont proposés, le rêve actuel est marqué")
	screen._overlay.find_child("Reve_sportif", true, false).pressed.emit()
	check(profile["reve"]["id"] == "sportif" and screen._overlay == null and game.session["reves_changes"] == 1, "nouveau rêve choisi, changement compté pour l'ergo")
	screen._open_objectives()
	check(screen._overlay.offers.any(func(o): return o["reve"]), "un objectif « pour ton rêve » est proposé")
	screen._close_overlay()
	screen._open_career()
	check(screen._overlay.find_child("Choisir_sportif", true, false) == null, "palier 1 : pas encore de changement de travail")
	screen._close_overlay()
	profile["career"]["tiers"]["artisan"] = 2
	screen._open_career()
	screen._overlay._show_choice(profile, true)
	await process_frame
	await process_frame
	check(screen._overlay.find_child("Choisir_sportif", true, false) != null and screen._overlay.find_child("Choisir_nature", true, false) != null, "palier 2 : les autres métiers sont proposés")
	screen._overlay.find_child("Choisir_sportif", true, false).pressed.emit()
	check(profile["career"]["current"] == "sportif" and Dreams.steps_done(profile) == 1, "métier du rêve choisi : première étape faite")
	await _wait(4.5)
	check(not screen._mission_state.is_empty() and screen._mission_state["data"]["career"] == "sportif", "les missions sont celles du nouveau métier")
	screen._open_mission()
	check(screen._mission_panel != null, "la mission de sportif s'ouvre")
	screen._close_mission_panel()
	var stars_before: int = profile["etoiles"]
	var coins_before: int = profile["money"]
	profile["career"]["tiers"]["sportif"] = 5
	await _wait(1.0)
	check(screen._overlay == null, "rêve réalisé : la fête attend un moment de calme")
	await _wait(3.5)
	check(screen._overlay is DreamPanel and not screen._overlay.reward.is_empty(), "rêve réalisé : le panneau de fête s'ouvre")
	check(profile["money"] == coins_before + 100 and profile["etoiles"] == stars_before + 3, "récompense du rêve : 100 pièces et 3 étoiles")
	check(profile["reve"]["realises"] == ["sportif"] and game.session["reves_realises"] == ["sportif"], "rêve réalisé noté dans le profil et la séance")
	screen._close_overlay()
	await _wait(4.0)
	check(screen._overlay == null, "le rêve n'est fêté qu'une fois")

	print("Graphismes de la famille (version 2.4, sans le code de jeu)")
	var studio = screen.studio
	var Character = load("res://scripts/world/character.gd")
	var objects_before: int = studio.furniture.size()
	check(not studio.has_nursery() and studio.get_object("berceau") == null and studio.family.is_empty(), "rien de la famille n'apparaît tant que le jeu ne le demande pas")
	studio.set_view("chambre")
	check(studio.view == "maison" and studio.zone_of(Vector3(-2.5, 0, 5.5)) == "maison", "sans chambre des enfants : pas de vue « chambre »")
	check(studio.clamp_to_room(Vector3(-2.5, 0, 5.5)).z < 4.0, "sans chambre des enfants : on reste dans la maison")
	# Personnages
	var kid = studio.add_family_member({"body": 1, "beard": 2, "height": 2}, "enfant", Vector3(1.0, 0, 1.0))
	var partner = studio.add_family_member({"body": 0, "height": 2}, "adulte", Vector3(1.6, 0, 1.0))
	check(kid.age == "enfant" and partner.age == "adulte" and studio.family.size() == 2, "un conjoint et un enfant rejoignent la maison")
	check(is_equal_approx(kid._scale, partner._scale * Character.CHILD_SCALE) and kid._joints["head"].scale.x > 1.1, "l'enfant est plus petit, avec une grosse tête")
	var all_new := true
	var rest: Dictionary = partner._pose_for("idle", 0.4)
	for anim in Character.FAMILY_ANIMS:
		var pose: Dictionary = partner._pose_for(anim, 0.4)
		all_new = all_new and not pose.is_empty() and pose != rest
	check(all_new and Character.FAMILY_ANIMS.size() == 12, "les 12 gestes de la famille ont leur animation")
	partner.play("give")
	check(partner._props["bouquet"].visible and not partner._props["bebe"].visible, "offrir des fleurs : le bouquet apparaît dans la main")
	partner.play("feed")
	check(partner._props["bebe"].visible and partner._props["biberon"].visible and not partner._props["bouquet"].visible, "biberon : le bébé est dans les bras")
	kid.play("cuddle_toy")
	check(kid._props["doudou"].visible, "l'enfant serre son doudou")
	studio.duo(screen.character, partner, Vector3(0.4, 0, 1.3), "hug")
	check(screen.character.anim == "hug" and partner.anim == "hug" and is_equal_approx(screen.character.position.distance_to(partner.position), 0.62), "câlin : les deux personnages sont face à face")
	studio.side_by_side(screen.character, partner, Vector3(0.4, 0, 1.3), Vector3(1.0, 0, 2.1))
	check(screen.character.anim == "hold_r" and partner.anim == "hold_l", "main dans la main, côte à côte")
	var love = studio.hearts(Vector3(0.4, 1.9, 1.3), 5, 0.5)
	check(love is CPUParticles3D and love.amount == 5 and love.mesh.get_faces().size() > 100, "des cœurs s'envolent")
	# Lit pour deux
	var big_bed = studio.get_object("lit")
	check(studio._bed_single_parts[0].visible and not studio._bed_double_parts[0].visible, "au départ : un seul oreiller")
	studio.set_double_bed(true)
	check(not studio._bed_single_parts[0].visible and studio._bed_double_parts[0].visible and big_bed.pose_point.x < -4.2 and big_bed.get_meta("partner_point").x > -3.8, "lit pour deux : deux oreillers et deux places")
	studio.set_double_bed(false)
	check(is_equal_approx(big_bed.pose_point.x, -4.0) and studio._bed_single_parts[0].visible, "retour au lit pour un")
	# Chambre des enfants
	studio.add_nursery()
	studio.add_nursery()
	check(studio.has_nursery() and studio.furniture.size() == objects_before + 3, "la chambre des enfants ajoute berceau, petit lit et jouets (une seule fois)")
	check(studio.get_object("berceau").actions.is_empty() and studio.get_object("lit_enfant").pose == "allonge" and studio.get_object("jouets").has_meta("kid_point"), "les trois objets attendent leurs actions")
	check(not studio._flowerbed.visible, "le massif de fleurs laisse la place à la chambre")
	check(studio.zone_of(Vector3(-2.5, 0, 5.5)) == "chambre" and is_equal_approx(studio.clamp_to_room(Vector3(-2.5, 0, 5.5)).z, 5.5) and studio.clamp_to_room(Vector3(-2.5, 0, 9.0)).z < 7.3, "on marche dans la chambre, pas au-delà")
	var to_room := true
	for id in ["berceau", "lit_enfant", "jouets"]:
		var target = studio.get_object(id)
		for from in [big_bed, studio.get_object("canape"), studio.get_object("cuisine")]:
			var path: Array = studio.compute_path(from.use_point, target.use_point, target)
			to_room = to_room and path[-1] == target.use_point
			for i in path.size():
				var a: Vector3 = from.use_point if i == 0 else path[i - 1]
				to_room = to_room and studio._segment_clear(Vector2(a.x, a.z), Vector2(path[i].x, path[i].z), target)
	check(to_room, "un chemin mène de la maison à chaque objet de la chambre")
	studio.set_view("chambre")
	check(studio.view == "chambre", "la caméra a une vue « chambre »")
	studio.set_view("maison")
	check(not studio.has_baby(), "le berceau est vide au départ")
	studio.set_baby(true)
	check(studio.has_baby() and studio.get_object("berceau").get_children().has(studio._crib_baby), "le bébé dort dans le berceau")
	studio.set_baby(false)
	check(not studio.has_baby(), "on peut retirer le bébé du berceau")
	studio.clear_family()
	check(studio.family.is_empty(), "la famille peut quitter la scène")
	screen._open_guide()
	check(screen._overlay != null and screen._overlay.objects.size() == studio.furniture.size(), "le guide s'ouvre encore avec les objets de la chambre")
	screen._close_overlay()

	print("")
	print("%d tests, %d échec(s)" % [_count, _fails])
	quit(1 if _fails > 0 else 0)
