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
const FamilyPanel = preload("res://scripts/ui/family_panel.gd")
const Family = preload("res://scripts/core/family.gd")
const Recap = preload("res://scripts/core/recap.gd")
const MissionPanel = preload("res://scripts/ui/mission_panel.gd")
const Portrait = preload("res://scripts/ui/portrait.gd")
const SessionEndPanel = preload("res://scripts/ui/session_end_panel.gd")

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


## Tape tous les mots de la série en cours, puis attend la fin.
func _type_series(screen) -> bool:
	for i in Data.WORDS_PER_SERIES:
		screen.typing._input.text = screen.typing.model_text
		screen.typing._submit()
		await _wait(1.3)
	return await _wait_state(screen, "idle", 5.0)


## Le personnage arrive à l'objet pour l'action (comme après la frappe).
func _arrive(screen, id: String, action_id: String) -> void:
	var target = _object(screen, id)
	screen._object = target
	screen._action_id = action_id
	screen._state = "walking"
	screen.character.position = target.use_point
	screen._on_arrived()


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
	screen.typing._input.text = "tolete" # 3 fautes sur un mot de 9 lettres
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
		if Data.ACTIONS[id].has("famille"):
			continue # les activités de la famille apparaissent avec elle (testées plus bas)
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
	check(screen._overlay.find_child("Reve_sportif", true, false) != null and screen._overlay.find_child("Reve_artisan", true, false).disabled and screen._overlay.find_child("Reve_famille", true, false) != null, "les 9 rêves sont proposés, le rêve actuel est marqué")
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

	print("Famille : rencontrer, vivre ensemble, les enfants")
	profile["famille"] = Family.new_state()
	profile["settings"]["chrono"] = "jamais"
	profile["skills_xp"]["charisme"] = 0.0
	profile["skills_xp"]["organisation"] = 0.0
	screen._sync_family()
	var sofa = studio.get_object("canape")
	check(sofa.actions == ["inviter"] and studio.family.is_empty(), "seul : le canapé sert à inviter des amis")
	check(screen.hud.family_button.visible and screen.hud._family_text.text == "Rencontrer quelqu'un", "le cadre « Ma famille » est à gauche")
	screen.hud.family_button.pressed.emit()
	check(screen._overlay is FamilyPanel and screen.paused and profile["famille"]["vu"], "« Ma famille » ouvre le panneau (jeu en pause)")
	var people: Array = screen._overlay.people
	check(people.size() == 4 and people.filter(func(p): return p["genre"] == 0).size() == 2, "deux femmes et deux hommes sont proposés")
	check(screen._overlay.find_child("Rencontrer_0", true, false).disabled, "il faut du charisme pour rencontrer quelqu'un")
	profile["skills_xp"]["charisme"] = float(Data.xp_for_level(1))
	screen._overlay.refresh()
	await process_frame
	var meet_button = screen._overlay.find_child("Rencontrer_3", true, false)
	check(not meet_button.disabled, "avec le charisme : on peut rencontrer quelqu'un")
	meet_button.pressed.emit()
	check(Family.partner_name(profile) == people[3]["nom"] and screen._overlay == null, "la personne choisie est rencontrée")
	check(studio.family.size() == 1 and game.session["famille"].size() == 1, "elle vient dire bonjour ; la rencontre est notée pour l'adulte")
	check(sofa.actions.has("fleurs") and sofa.actions.has("danser") and sofa.actions.has("calin"), "le canapé propose les moments à deux")
	screen._state = "walking" # l'enfant a cliqué ailleurs pendant les au revoir
	await _wait(4.0)
	check(studio.family.is_empty(), "avant de vivre ensemble, elle repart (même si l'enfant est déjà parti ailleurs)")
	screen._state = "idle"
	_arrive(screen, "canape", "fleurs")
	check(screen._state == "series" and screen.character.anim == "give" and studio.family.size() == 1 and studio.family[0].anim == "celebrate", "offrir des fleurs : la personne aimée est là, ravie")
	var complicity := Family.complicity(profile)
	check(await _type_series(screen), "la série des fleurs se termine")
	check(Family.complicity(profile) == complicity + Data.WORDS_PER_SERIES * Data.FAMILY_COMPLICITY_PER_WORD, "chaque mot réussi fait monter la complicité")
	check(studio.family.is_empty(), "après le moment à deux, elle repart")
	_arrive(screen, "canape", "danser")
	check(screen.character.anim == "dance" and studio.family[0].anim == "dance", "danser ensemble")
	screen.typing._close({"status": "cancel"})
	profile["famille"]["complicite"] = Data.FAMILY_MOVE_IN
	screen._open_family()
	var move_button = screen._overlay.find_child("VivreEnsemble", true, false)
	check(move_button != null and not move_button.disabled, "très complices : on peut vivre ensemble")
	move_button.pressed.emit()
	check(Family.is_together(profile) and not studio._bed_single_parts[0].visible, "ils vivent ensemble : le lit devient un grand lit")
	check(studio.family.size() == 1 and studio.family[0].anim == "sit_read", "le conjoint lit sur le canapé")
	_arrive(screen, "canape", "calin")
	check(screen.character.anim == "sit_cuddle" and studio.family[0].anim == "sit_cuddle_r", "câlin sur le canapé")
	screen.typing._close({"status": "cancel"})
	_arrive(screen, "lit", "dormir")
	check(screen._state == "acting" and studio.family[0].pose == "allonge", "le soir, ils dorment tous les deux")
	screen._leave_object()
	screen._open_family()
	check(screen._overlay.find_child("AvoirBebe", true, false).disabled, "il faut de l'organisation pour accueillir un bébé")
	screen._overlay.find_child("PasDEnfant", true, false).pressed.emit()
	await process_frame
	check(Family.declined(profile) and screen._overlay is FamilyPanel and screen._overlay.find_child("PasDEnfant", true, false) == null, "on peut choisir de ne pas avoir d'enfant")
	check(not Family.has_news(profile), "ce choix est respecté : « Ma famille » ne clignote plus")
	profile["skills_xp"]["organisation"] = float(Data.xp_for_level(2))
	screen._overlay.refresh()
	await process_frame
	var baby_button = screen._overlay.find_child("AvoirBebe", true, false)
	check(not baby_button.disabled, "on peut changer d'avis : un bébé est possible")
	baby_button.pressed.emit()
	await process_frame
	var name_button = screen._overlay.find_child("Prenom_1", true, false)
	check(name_button != null, "on choisit le prénom du bébé")
	name_button.pressed.emit()
	var baby: Dictionary = Family.baby(profile)
	check(not baby.is_empty() and screen._overlay == null and studio.has_nursery() and studio.has_baby(), "le bébé dort dans son berceau, dans la nouvelle chambre")
	check(studio.view == "chambre" and screen.hud.view_button.text == "Maison", "la caméra montre la chambre des enfants")
	check(studio.get_object("berceau").actions == ["bercer", "biberon"] and studio.get_object("jouets").actions.is_empty(), "le berceau propose bercer et biberon")
	_arrive(screen, "berceau", "bercer")
	check(screen.character.anim == "rock" and not studio.has_baby(), "bercer : le bébé est dans les bras")
	screen.typing._close({"status": "cancel"})
	check(studio.has_baby(), "le bébé retourne dans son berceau")
	baby["soins"] = Data.FAMILY_BABY_CARES - 1
	_arrive(screen, "berceau", "biberon")
	check(screen.character.anim == "feed", "donner le biberon")
	check(await _type_series(screen), "la série du biberon se termine")
	check(Family.has_child(profile) and not studio.has_baby(), "après les soins, le bébé a grandi")
	check(studio.family.size() == 2 and studio.family.any(func(m): return m.age == "enfant" and m.anim == "floor_play"), "l'enfant joue dans sa chambre")
	check(studio.get_object("jouets").actions == ["jouer_enfant"] and studio.get_object("lit_enfant").actions == ["histoire"], "les jouets et le petit lit ont leurs activités")
	_arrive(screen, "jouets", "jouer_enfant")
	check(screen.character.anim == "kneel_play", "jouer avec son enfant")
	screen.typing._close({"status": "cancel"})
	_arrive(screen, "lit_enfant", "histoire")
	check(screen.character.anim == "talk" and studio.family.any(func(m): return m.age == "enfant" and m.pose == "allonge"), "raconter une histoire : l'enfant est couché")
	screen.typing._close({"status": "cancel"})
	check(game.session["famille"].size() >= 4, "les grands moments sont notés pour l'adulte")
	screen._on_dream_chosen("famille")
	check(Dreams.steps_done(profile) == 5 and Dreams.is_done(profile), "le rêve « Fonder une famille » est réalisé")
	screen._close_overlay()

	print("Marche pendant une pause ou une frappe de mission")
	game.claim_dream() # le rêve est fêté : pas de panneau de fête pendant la suite
	screen._close_overlay()
	screen._interrupt_action()
	var tapis = _object(screen, "tapis")
	screen.character.position = _object(screen, "lit").use_point
	screen._start_typing(tapis, "sport")
	screen.typing._input.text = screen.typing.model_text
	screen.typing._submit()
	await _wait(1.0)
	var where: Vector3 = screen.character.position
	screen._open_shop()
	await _wait(1.5)
	check(screen._state == "walking" and screen.character.position.distance_to(where) < 0.05 and not screen.typing.is_open(), "magasin ouvert : le personnage attend, aucune série ne démarre derrière")
	screen._close_overlay()
	check(await _wait_state(screen, "series", 8.0), "magasin fermé : il repart et la série commence")
	screen.typing._close({"status": "cancel"})
	await process_frame
	# Mission : la frappe d'un élément ne doit pas être remplacée par une série.
	if profile["career"]["current"] == "":
		screen._on_career_chosen("organisateur")
	profile["mission_timer"] = 0.0
	await _wait(0.3)
	screen._open_mission()
	check(screen._mission_panel != null, "mission ouverte")
	if screen._mission_panel == null:
		quit(1)
		return
	screen._mission_panel.state["step"] = "items"
	screen._mission_panel.state["item"] = 0
	screen._mission_panel.refresh()
	screen.character.position = _object(screen, "lit").use_point # loin du tapis
	screen._start_typing(tapis, "sport")
	screen.typing._input.text = screen.typing.model_text
	screen.typing._submit()
	await _wait(0.9)
	screen._mission_panel.visible = false
	screen._on_mission_typing_requested("ballons", "Mission")
	screen.character.position = tapis.use_point
	screen._on_arrived()
	check(screen._typing_mode == "mission" and screen.typing.model_text == "ballons", "arrivé pendant la frappe de mission : la mission garde la frappe")
	screen.typing._input.text = "ballons"
	screen.typing._submit()
	await _wait(1.0)
	check(screen._mission_panel.visible and screen._mission_panel.state["item"] == 1, "l'élément de mission est compté et le panneau revient")
	check(screen._state == "series" and screen._typing_mode == "series", "puis la série de l'activité commence")
	var series_word: String = screen.typing.model_text
	screen._mission_panel.visible = false
	screen._on_mission_typing_requested("bougies", "Mission")
	check(screen._typing_mode == "series" and screen.typing.model_text == series_word and screen._mission_panel.visible, "pendant une série, « Taper » de la mission attend : la série garde le clavier")
	screen.typing._close({"status": "cancel"})

	print("Aide en couleur")
	screen.typing.open("maison", "test", false)
	screen.typing._input.text = "mison"
	screen.typing._refresh_model()
	check(screen.typing._model.text.count("[u]") == 1, "une lettre oubliée : une seule lettre en rouge")
	screen.typing._close({"status": "cancel"})

	print("Récapitulatif fiable")
	var errs_before := Recap.error_count(game.session)
	var tried_before := int(game.session.get("caracteres_tentes", 0))
	screen.typing.open("maison", "test", false)
	for attempt in 3:
		screen.typing._input.text = "mizon"
		screen.typing._submit()
	check(Recap.error_count(game.session) - errs_before == 2, "trois appuis sur Entrée : les fautes ne sont comptées qu'une fois")
	check(int(game.session["caracteres_tentes"]) - tried_before == 6, "caractères tentés comptés une seule fois")
	screen.typing._close({"status": "cancel"})
	game.session["vitesse_niveaux"] = {}
	game.record_typing({"ok": true, "details": {}}, 60, 30.0, false)
	var lvl := str(Progression.text_level(profile))
	check(is_equal_approx(Recap.level_cpm(game.session, lvl), 120.0), "vitesse notée pour le niveau de texte en cours")
	screen._interrupt_action()
	await process_frame
	game.session["taches_abandonnees"] = 0
	screen._start_typing(_object(screen, "lavabo"), "dents")
	screen.typing._cancel.pressed.emit()
	check(game.session["taches_abandonnees"] == 0, "annuler sans avoir tapé : pas d'abandon")
	screen._start_typing(_object(screen, "lavabo"), "dents")
	screen.typing._input.text = "d"
	screen.typing._on_text_changed("d")
	screen.typing._cancel.pressed.emit()
	check(game.session["taches_abandonnees"] == 1, "annuler après une lettre tapée : abandon compté")
	var mp := MissionPanel.new()
	var demo := {"title": "Test", "consigne": "Lis.", "questions": [{"q": "Quoi ?", "choices": ["a", "b", "c"], "good": 1}]}
	mp.state = {"data": demo, "step": "question", "q": 0, "item": 0}
	root.add_child(mp)
	var places := {}
	for n in 30:
		for c in mp._box.get_children():
			mp._box.remove_child(c)
			c.free()
		mp._show_question(demo)
		var idx := 0
		for c in mp._box.get_children():
			if c.name.begins_with("Choix_"):
				if c.name == "Choix_1":
					places[idx] = true
				idx += 1
	check(places.size() >= 2, "la bonne réponse ne reste pas toujours à la même place")
	mp.queue_free()
	await process_frame

	print("Mode « Léger »")
	screen.studio.apply_quality(0)
	var small_off := 0
	var small_total := 0
	for m in screen.studio.find_children("*", "MeshInstance3D", true, false):
		if m.has_meta("ombre") and int(m.get_meta("ombre")) > 0:
			small_total += 1
			small_off += 1 if m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0
	check(not screen.studio.inside_light.shadow_enabled and screen.studio.sun.shadow_enabled, "« Léger » : plus d'ombre intérieure, le soleil garde la sienne")
	check(small_total > 50 and small_off == small_total, "« Léger » : les petits objets n'ont plus d'ombre (%d)" % small_total)
	screen.studio.apply_quality(1)
	var restored := true
	for m in screen.studio.find_children("*", "MeshInstance3D", true, false):
		if m.has_meta("ombre") and int(m.get_meta("ombre")) > 0:
			restored = restored and m.cast_shadow == int(m.get_meta("ombre"))
	check(screen.studio.inside_light.shadow_enabled and restored, "« Normal » : ombres rendues")
	var quality_backup: int = game.local_settings["qualite"]
	game.local_settings["qualite"] = 0
	var portrait := Portrait.new()
	portrait.setup(profile["appearance"])
	check(portrait.get_child(0).msaa_3d == Viewport.MSAA_DISABLED, "« Léger » : portrait sans antialiasing")
	portrait.free()
	game.local_settings["qualite"] = quality_backup

	print("Minuterie de séance")
	screen._close_overlay()
	screen._interrupt_action()
	profile["settings"]["duree_seance"] = "5 min"
	game.session["duree_sec"] = 300.0 - 50.0
	await _wait(0.2)
	check(screen._session_warned and not screen._session_over, "une minute avant : l'enfant est prévenu")
	game.session["duree_sec"] = 301.0
	await _wait(0.2)
	check(screen._session_over and screen._overlay is SessionEndPanel and screen.paused, "l'heure est passée : fin douce de la séance (jeu en pause)")
	check(game.session.get("fin_minuterie", false), "la fin par la minuterie est notée pour l'ergo")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	screen._unhandled_input(esc)
	check(screen._overlay is SessionEndPanel, "Échap ne referme pas la fin de séance")
	var ended := [false]
	screen.quit_to_profiles.connect(func(): ended[0] = true)
	screen._overlay.find_child("Terminer", true, false).pressed.emit()
	check(ended[0], "« Terminer » ramène à la liste des joueurs")
	profile["settings"]["duree_seance"] = "sans limite"

	print("")
	print("%d tests, %d échec(s)" % [_count, _fails])
	quit(1 if _fails > 0 else 0)
