extends SceneTree
## Parcours complet des écrans : joueurs → création → jeu → pause → changer de joueur
## → le nouveau joueur apparaît → espace ergo (réglage enregistré). Profil supprimé à la fin.
## Lancer : Godot --headless --path . --script res://tests/flow_test.gd

const MainScript = preload("res://scripts/main.gd")
const ProfileScreen = preload("res://scripts/screens/profile_screen.gd")
const CreateProfileScreen = preload("res://scripts/screens/create_profile_screen.gd")
const GameScreen = preload("res://scripts/screens/game_screen.gd")
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
	main._screen._toggle_pause()
	check(main._screen.paused, "pause")
	main._screen.quit_to_profiles.emit()
	await _frames()
	check(main._screen is ProfileScreen, "retour à la liste des joueurs")
	var names: Array = main._screen.profiles.map(func(p): return p["name"])
	check("Parcours Test" in names, "le nouveau joueur est dans la liste")
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
	game.delete_profile(id)
	print("")
	print("%d tests, %d échec(s)" % [_count, _fails])
	quit(1 if _fails > 0 else 0)
