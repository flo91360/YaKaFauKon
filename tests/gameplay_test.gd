extends SceneTree
## Test de jeu automatique (sans affichage) : on simule un enfant qui tape,
## puis on vérifie que le personnage se déplace, agit, et que les jauges bougent.
## Lancer : Godot --headless --path . --script res://tests/gameplay_test.gd

const GameScreen = preload("res://scripts/screens/game_screen.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Objectives = preload("res://scripts/core/objectives.gd")
const Data = preload("res://scripts/core/data.gd")

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

	print("")
	print("%d tests, %d échec(s)" % [_count, _fails])
	quit(1 if _fails > 0 else 0)
