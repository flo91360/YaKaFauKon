extends SceneTree
## Parcours complet des écrans : joueurs → création → jeu → pause → changer de joueur
## → le nouveau joueur apparaît → espace ergo (réglage enregistré). Profil supprimé à la fin.
## Lancer : Godot --headless --path . --script res://tests/flow_test.gd

const MainScript = preload("res://scripts/main.gd")
const ProfileScreen = preload("res://scripts/screens/profile_screen.gd")
const CreateProfileScreen = preload("res://scripts/screens/create_profile_screen.gd")
const GameScreen = preload("res://scripts/screens/game_screen.gd")
const DreamPanel = preload("res://scripts/ui/dream_panel.gd")
const ErgoScreen = preload("res://scripts/screens/ergo_screen.gd")

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


func _frames(n := 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	var game = root.get_node("Game")
	var main := Node.new()
	main.set_script(MainScript)
	root.add_child(main) # _ready affiche l'écran des joueurs
	await _frames()
	print("Parcours des écrans")
	check(main._screen is ProfileScreen, "écran « Qui joue ? » au démarrage")
	main._screen.new_profile_requested.emit()
	await _frames()
	check(main._screen is CreateProfileScreen, "écran de création")
	var create = main._screen
	create._validate()
	check(main._screen == create and create._message.text != "", "prénom obligatoire")
	create._name_edit.text = "Parcours Test"
	create.appearance["outfit"] = 2
	create._validate()
	await _frames()
	check(main._screen is GameScreen, "le jeu démarre avec le nouveau joueur")
	var id: String = game.profile["id"]
	var play = main._screen
	check(play._overlay is DreamPanel and play.paused and play.tutorial == null, "début de partie : choix du rêve avant le tutoriel")
	play._overlay.find_child("PlusTard", true, false).pressed.emit()
	await _frames()
	check(play._overlay == null and game.profile["reve"]["id"] == "" and play.tutorial != null, "« Plus tard » : pas de rêve, le tutoriel commence")
	play.hud.dream_button.pressed.emit()
	await _frames()
	check(play._overlay is DreamPanel, "le bouton « Mon rêve » rouvre le choix")
	play._overlay.find_child("Reve_chanteur", true, false).pressed.emit()
	await _frames()
	check(play._overlay == null and game.profile["reve"]["id"] == "chanteur", "rêve choisi et enregistré")
	play._open_dream()
	await _frames()
	check(play._overlay.find_child("ChangerReve", true, false) != null, "rêve choisi : le panneau montre les étapes")
	play._close_overlay()
	main._screen._toggle_pause()
	check(main._screen.paused, "pause")
	main._screen.quit_to_profiles.emit()
	await _frames()
	check(main._screen is ProfileScreen, "retour à la liste des joueurs")
	var names: Array = main._screen.profiles.map(func(p): return p["name"])
	check("Parcours Test" in names, "le nouveau joueur est dans la liste")

	print("Accès ergo et prénoms")
	var had_access := FileAccess.file_exists(game.ACCESS_PATH)
	var access_backup := FileAccess.get_file_as_string(game.ACCESS_PATH) if had_access else ""
	var hide_backup: bool = game.local_settings.get("prenoms_caches", false)
	DirAccess.remove_absolute(game.ACCESS_PATH)
	var ps = main._screen
	ps._ask_code()
	await _frames()
	var ask: Node = ps.find_child("AccesErgo", true, false)
	ask.find_child("Mot", true, false).text = "mauvais"
	ask.find_child("Entrer", true, false).pressed.emit()
	await _frames()
	check(main._screen == ps and ps.find_child("ChoixMot", true, false) == null, "mauvais mot : l'espace reste fermé")
	ask.find_child("Mot", true, false).text = " Ergo "
	ask.find_child("Entrer", true, false).pressed.emit()
	await _frames()
	var choose: Node = ps.find_child("ChoixMot", true, false)
	check(main._screen == ps and choose != null, "mot de départ « ergo » : il faut d'abord choisir son propre mot")
	if choose == null:
		quit(1)
		return
	choose.find_child("Nouveau", true, false).text = "abc"
	choose.find_child("Confirmation", true, false).text = "abc"
	choose.find_child("Enregistrer", true, false).pressed.emit()
	await _frames()
	check(main._screen == ps and choose.find_child("Message", true, false).text != "", "mot trop court refusé")
	choose.find_child("Nouveau", true, false).text = "Cabinet2026"
	choose.find_child("Confirmation", true, false).text = "cabinet2026"
	choose.find_child("Enregistrer", true, false).pressed.emit()
	await _frames()
	check(main._screen is ErgoScreen, "nouveau mot enregistré : l'espace s'ouvre")
	var stored := FileAccess.get_file_as_string(game.ACCESS_PATH)
	check(stored != "" and not stored.to_lower().contains("cabinet"), "le mot n'est pas écrit en clair")
	check(game.check_ergo_word("cabinet2026") and not game.check_ergo_word("ergo"), "« ergo » ne marche plus, le nouveau mot oui")
	main._screen._show_pc()
	await _frames()
	check(main._screen.find_child("CacherPrenoms", true, false) != null and main._screen.find_child("ChangerMot", true, false) != null, "page « Ce PC » : prénoms et mot d'accès")
	main._screen.find_child("CacherPrenoms", true, false).button_pressed = true
	main.show_profiles()
	await _frames()
	var labels: Array = main._screen.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(labels.any(func(t): return t.begins_with("P.")) and not labels.any(func(t): return t.contains("Parcours")), "prénoms cachés : seulement l'initiale")
	game.set_local_setting("prenoms_caches", hide_backup)
	main.show_profiles()
	await _frames()
	main._screen._ask_code()
	await _frames()
	ask = main._screen.find_child("AccesErgo", true, false)
	ask.find_child("Mot", true, false).text = "cabinet2026"
	ask.find_child("Entrer", true, false).pressed.emit()
	await _frames()
	check(main._screen is ErgoScreen, "le mot choisi ouvre l'espace directement")
	DirAccess.remove_absolute(game.ACCESS_PATH)
	if had_access:
		var f := FileAccess.open(game.ACCESS_PATH, FileAccess.WRITE)
		f.store_string(access_backup)
		f.close()
	main.show_profiles()
	await _frames()
	main._screen.new_profile_requested.emit()
	await _frames()
	create = main._screen
	create._name_edit.text = "parcours TEST"
	create._validate()
	await _frames()
	check(main._screen == create and create._message.text.contains("déjà"), "prénom déjà pris : signalé avant de créer")
	main.show_profiles()
	await _frames()
	main._screen.ergo_requested.emit()
	await _frames()
	check(main._screen is ErgoScreen, "espace ergothérapeute")
	var ergo = main._screen
	var index := -1
	for i in ergo.profiles.size():
		if ergo.profiles[i]["id"] == id:
			index = i
	ergo._select(index, "settings")
	ergo.profiles[index]["settings"]["tolerance"] = "large"
	ergo._save(ergo.profiles[index])
	var saved: Dictionary = {}
	for p in game.list_profiles():
		if p["id"] == id:
			saved = p
	check(saved.get("settings", {}).get("tolerance", "") == "large", "réglage de l'ergo enregistré sur le disque")
	ergo._select(index, "recap")
	check(ergo._content.get_child_count() > 3, "récapitulatif affiché")
	var dream_shown := false
	var garden_shown := false
	for l in ergo._content.find_children("*", "Label", true, false):
		dream_shown = dream_shown or l.text.begins_with("Rêve : devenir une star de la chanson")
		garden_shown = garden_shown or l.text.begins_with("Jardin : 0 bûche et 0 pierre en réserve")
	check(dream_shown, "le rêve de l'enfant est dans le récapitulatif")
	check(garden_shown, "le jardin (réserve et constructions) est dans le récapitulatif")
	game.delete_profile(id)
	print("")
	print("%d tests, %d échec(s)" % [_count, _fails])
	quit(1 if _fails > 0 else 0)
