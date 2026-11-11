extends SceneTree
## Test de jeu automatique (sans affichage) : on simule un enfant qui tape,
## puis on vérifie que le personnage se déplace, agit, et que les jauges bougent.
## Lancer : Godot --headless --path . --script res://tests/gameplay_test.gd

const GameScreen = preload("res://scripts/screens/game_screen.gd")
const Progression = preload("res://scripts/core/progression.gd")

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

	print("Activité et compétence (miroir)")
	var xp_before: float = profile["skills_xp"]["charisme"]
	screen._start_typing(_object(screen, "miroir"), "miroir")
	screen.typing._input.text = "miroir"
	screen.typing._submit()
	check(await _wait_state(screen, "acting", 10.0), "le personnage va au miroir")
	check(await _wait_state(screen, "idle", 40.0), "l'activité se termine")
	check(profile["skills_xp"]["charisme"] > xp_before + 10.0, "le charisme progresse")

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

	print("")
	print("%d tests, %d échec(s)" % [_count, _fails])
	quit(1 if _fails > 0 else 0)
